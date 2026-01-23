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

    var body: some Scene {
        WindowGroup(id: "main") {
            MainContentView()
                .environment(downloadManager)
                .environment(\.locale, .init(identifier: language))
                .frame(minWidth: 1000, minHeight: 600)
                .onReceive(NotificationCenter.default.publisher(for: .openMainWindow)) { _ in
                    // This triggers window to open via the menu or URL scheme
                }
        }
        .handlesExternalEvents(matching: ["*"])
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1024, height: 700)
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
        HStack(alignment: .center, spacing: 2) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 14))
            if showSpeed {
                Text(speed.formatted(.byteCount(style: .file)) + "/s")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
            }
        }
    }
}

/// Application delegate for handling system-level events
class AppDelegate: NSObject, NSApplicationDelegate {
    // Make aria2Process accessible for preferences
    var aria2Process: EngineProcess?
    private var dockObserver: NSKeyValueObservation?

    func applicationDidFinishLaunching(_ notification: Notification) {
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
                // alert.addButton(withTitle: "忽略") // User requested to try restart, so just one option or maybe ignore? User said "try to normal exit app and reopen".
                
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

        // Register URL schemes
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )

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

    @objc func handleURLEvent(
        _ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor
    ) {
        guard let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
            let url = URL(string: urlString)
        else { return }

        URLSchemeHandler.shared.handle(url)
    }
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
