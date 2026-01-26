import SwiftUI
import UserNotifications

// Notification for opening main window
extension Notification.Name {
    static let openSettings = Notification.Name("openSettings")
    static let saveSettings = Notification.Name("saveSettings")
}

@main
struct MotrixMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var downloadManager = DownloadManager.shared
    @AppStorage("language") private var language = "zh-CN"
    @Environment(\.openWindow) private var openWindow

    init() {
        // 1. Check for Native Messaging argument from browser
        // We use a high-priority synchronous check. If this is a Nutive Messaging call, 
        // the app performs its task and exits before ANY GUI code is executed.
        if CommandLine.arguments.contains("--native-messaging") {
            NativeMessagingManager.shared.runHeadlessLoop()
        }
    }

    var body: some Scene {
        Window("MotrixMac", id: "main") {
            MainContentView()
                .environment(downloadManager)
                .environment(\.locale, .init(identifier: language))
                .frame(minWidth: 1000, minHeight: 600)
                .onReceive(NotificationCenter.default.publisher(for: .openMainWindow)) { _ in
                    openWindow(id: "main")
                }
                .onOpenURL { url in
                    URLSchemeHandler.shared.handle(url)
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1024, height: 700)
        .onChange(of: downloadManager.shouldOpenMainWindow) { _, newValue in
            if newValue {
                openWindow(id: "main")
                downloadManager.shouldOpenMainWindow = false
            }
        }
        .commands {
            MotrixCommands(downloadManager: downloadManager)
        }

        MotrixSecondaryScenes(downloadManager: downloadManager)
    }
}

/// Dedicated scene for Menu Bar Extra and other background elements
struct MotrixSecondaryScenes: Scene {
    let downloadManager: DownloadManager
    @AppStorage("showSpeedInMenuBar") private var showSpeedInMenuBar = false

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environment(downloadManager)
        } label: {
            MenuBarLabel(
                speed: downloadManager.totalDownloadSpeed,
                showSpeed: showSpeedInMenuBar
            )
        }
        .menuBarExtraStyle(.window)
    }
}

/// Dedicated commands for the main menu
struct MotrixCommands: Commands {
    let downloadManager: DownloadManager

    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button("Settings...") {
                NotificationCenter.default.post(name: .openSettings, object: nil)
            }
            .keyboardShortcut(",", modifiers: .command)
        }

        CommandGroup(replacing: .newItem) {
            Button("New Download") {
                downloadManager.showAddTaskSheet = true
            }
            .keyboardShortcut("n", modifiers: .command)

            Button("New Torrent Download") {
                downloadManager.showAddTorrentSheet = true
            }
            .keyboardShortcut("t", modifiers: [.command, .shift])
        }

        CommandGroup(after: .toolbar) {
            Button("Pause All") {
                Task { await downloadManager.pauseAll() }
            }
            .keyboardShortcut("p", modifiers: [.command, .option])

            Button("Resume All") {
                Task { await downloadManager.resumeAll() }
            }
            .keyboardShortcut("r", modifiers: [.command, .option])
        }
    }
}

/// Helper view for menu bar icon and speed
struct MenuBarLabel: View {
    let speed: Int64
    let showSpeed: Bool

    var body: some View {
        if showSpeed {
            // Capsule style: Icon + Text
            HStack(spacing: 4) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 12))
                Text(speed.formatted(.byteCount(style: .file)) + "/s")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(.primary.opacity(0.1))
                    .strokeBorder(.primary.opacity(0.2), lineWidth: 0.5)
            )
        } else {
            // Default icon
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 16))
        }
    }
}

/// Application delegate for handling system-level events
class AppDelegate: NSObject, NSApplicationDelegate {
    // Make aria2Process accessible for preferences
    var aria2Process: EngineProcess?
    private var dockObserver: NSKeyValueObservation?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Start app logging
        Logger.info("MotrixMacApp: App launched")
        
        // 0. Register Native Messaging manifests for browsers
        NativeMessagingManager.shared.installManifests()
        
        // Start aria2 engine
        let engine = EngineProcess()
        self.aria2Process = engine
        
        // Handle port conflicts with a user alert
        engine.onPortConflict = { port, procName, pid in
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "端口被占用"
                alert.informativeText = "MotrixMac 无法使用端口 \(port)，因为该端口被其他进程占用了。这通常是由于旧的 aria2c 进程未正常退出导致的。\n\n请尝试退出 App 并重新打开，系统可能会自动修复。如果问题持续，请在「活动监视器」中强制退出所有 aria2c 进程。"
                alert.alertStyle = .critical
                alert.addButton(withTitle: "退出 App")
                
                let response = alert.runModal()
                if response == .alertFirstButtonReturn {
                    NSApp.terminate(nil)
                }
            }
        }
        
        // Start aria2 engine in background to avoid blocking main thread at launch
        DispatchQueue.global(qos: .userInitiated).async {
            engine.start()
        }

        // Setup Notifications
        UNUserNotificationCenter.current().delegate = self

        // NSAppleEventManager logic removed in favor of .onOpenURL

        // Apply initial Dock visibility
        if UserDefaults.standard.object(forKey: "showInDock") == nil {
            UserDefaults.standard.set(true, forKey: "showInDock")
        }
        updateDockPolicy()

        // Observe changes to showInDock preference
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(dockPreferenceChanged),
            name: UserDefaults.didChangeNotification,
            object: nil
        )

        // Silent start: hide main window if enabled
        let silentStart = UserDefaults.standard.bool(forKey: "silentStart")

        if silentStart {
            // Close all windows on silent start
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NSApp.windows.forEach { window in
                    let className = String(describing: type(of: window))
                    // Only close the main window, not menu bar or system windows
                    if window.canBecomeMain && !className.contains("StatusBar")
                        && !className.contains("MenuBar")
                    {
                        window.close()
                    }
                }
            }
        }
    }

    @objc private func dockPreferenceChanged() {
        DispatchQueue.main.async {
            self.updateDockPolicy()
        }
    }
    
    private func updateDockPolicy() {
        let showInDock = UserDefaults.standard.bool(forKey: "showInDock")
        let currentPolicy = NSApp.activationPolicy()
        
        if showInDock {
            if currentPolicy != .regular {
                NSApp.setActivationPolicy(.regular)
                // When switching to regular, we might need to specifically activate to show in dock properly immediately
                DispatchQueue.main.async {
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
        } else {
            if currentPolicy != .accessory {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Gracefully stop aria2
        aria2Process?.stop()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false  // Keep running in menu bar
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            // No windows visible, trigger opening and navigation reset
            DispatchQueue.main.async {
                DownloadManager.shared.shouldResetNavigation = true
                DownloadManager.shared.shouldOpenMainWindow = true
            }
            // Return false to prevent the system from opening an additional default window
            return false
        }
        
        // If windows exist, return true to let system focus them, 
        // but still trigger a navigation reset for better UX
        DispatchQueue.main.async {
            DownloadManager.shared.shouldResetNavigation = true
        }
        return true
    }

    // URL handling moved to .onOpenURL in MotrixMacApp
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler:
            @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show banner and play sound even when app is in foreground
        completionHandler([.banner, .sound])
    }
}
