import SwiftUI
import UserNotifications
import Sparkle
import Network

// Notification for opening main window
extension Notification.Name {
    static let openSettings = Notification.Name("openSettings")
    static let saveSettings = Notification.Name("saveSettings")
    static let discardSettings = Notification.Name("discardSettings")
    static let openMainWindow = Notification.Name("openMainWindow")
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
                    // Handle file URLs (double-clicked .torrent files)
                    if url.isFileURL && url.pathExtension.lowercased() == "torrent" {
                        DownloadManager.shared.pendingTorrentURL = url
                        DownloadManager.shared.showAddTorrentSheet = true
                    } else {
                        // Handle URL schemes (magnet, thunder, etc)
                        URLSchemeHandler.shared.handle(url)
                    }
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
            MotrixCommands(downloadManager: downloadManager, language: language)
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
    let language: String

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("关于 MotrixMac".localized(for: language)) {
                DownloadManager.shared.currentCategory = .about
                DownloadManager.shared.shouldOpenMainWindow = true
                NSApp.activate(ignoringOtherApps: true)
            }
        }

        CommandGroup(replacing: .appSettings) {
            Button("设置...".localized(for: language)) {
                NotificationCenter.default.post(name: .openSettings, object: nil)
            }
            .keyboardShortcut(",", modifiers: .command)
            
            Button("检查更新...".localized(for: language)) {
                AppDelegate.shared?.updaterController.checkForUpdates(nil)
            }
        }

        CommandGroup(replacing: .newItem) {
            Button("新建下载".localized(for: language)) {
                downloadManager.showAddTaskSheet = true
            }
            .keyboardShortcut("n", modifiers: .command)

            Button("新建种子下载".localized(for: language)) {
                downloadManager.showAddTorrentSheet = true
            }
            .keyboardShortcut("t", modifiers: [.command, .shift])
        }

        CommandGroup(after: .toolbar) {
            Button("全部暂停".localized(for: language)) {
                Task { await downloadManager.pauseAll() }
            }
            .keyboardShortcut("p", modifiers: [.command, .option])

            Button("全部恢复".localized(for: language)) {
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
    static private(set) var shared: AppDelegate?
    
    // Make aria2Process accessible for preferences
    var aria2Process: EngineProcess?
    private var dockObserver: NSKeyValueObservation?
    
    // Sparkle updater controller
    let updaterController: SPUStandardUpdaterController
    
    // Network listener to trigger firewall prompt
    private var dummyListener: NWListener?
    
    override init() {
        // Initialize Sparkle
        self.updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        super.init()
        Self.shared = self
    }

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
        
        // Prompt to set as default torrent app on first launch
        promptSetAsDefaultTorrentApp()
        
        // Trigger firewall/network permission check
        triggerNetworkPermissionCheck()
    }

    /// Triggers a dummy network listener to force macOS to display the Firewall/Local Network permission prompt
    private func triggerNetworkPermissionCheck() {
        let hasChecked = UserDefaults.standard.bool(forKey: "hasCheckedNetworkPermission")
        if hasChecked { return }
        
        // Mark as checked to avoid nagging every time
        UserDefaults.standard.set(true, forKey: "hasCheckedNetworkPermission")
        
        // Create a dummy listener on a random port
        do {
            // "using: .tcp" defaults to random port
            let listener = try NWListener(using: .tcp)
            
            // Critical: valid listeners must handle new connections
            listener.newConnectionHandler = { _ in }
            
            listener.stateUpdateHandler = { newState in
                switch newState {
                case .ready:
                    print("NetworkCheck: Successfully bound to port \(listener.port?.rawValue ?? 0). Firewall prompt should appear if not already allowed.")
                    // Stop it immediately once it's ready, the prompt trigger happened at bind attempt
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        listener.cancel()
                        self.dummyListener = nil
                    }
                case .failed(let error):
                    print("NetworkCheck: Failed to bind dummy listener: \(error)")
                    listener.cancel()
                    self.dummyListener = nil
                default:
                    break
                }
            }
            
            listener.start(queue: .global())
            self.dummyListener = listener
            
            // Optional: Inform the user why we are doing this
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let alert = NSAlert()
                alert.messageText = "网络连接权限请求"
                alert.informativeText = "为了确保 BT 下载速度和 UPnP 端口映射正常工作，MotrixMac 需要使用网络端口。\n\n如果 macOS 弹出「是否允许传入连接」或「本地网络权限」的提示，请务必选择【允许】。"
                alert.alertStyle = .informational
                alert.addButton(withTitle: "明白了")
                alert.runModal()
            }
            
        } catch {
            print("NetworkCheck: Error creating listener: \(error)")
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
            // No windows visible, trigger opening and navigation reset to Home
            DispatchQueue.main.async {
                DownloadManager.shared.shouldResetNavigation = true
                DownloadManager.shared.shouldOpenMainWindow = true
            }
            return false
        }
        
        // If windows exist (even if covered/minimized), DO NOT reset navigation.
        // Just return true to let system focus the window, keeping user context.
        return true
    }

    // URL handling moved to .onOpenURL in MotrixMacApp
    
    // MARK: - File Opening (Torrent files)
    
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            if url.pathExtension.lowercased() == "torrent" {
                handleTorrentFile(url)
            }
        }
    }
    
    private func handleTorrentFile(_ url: URL) {
        // Bring app to front
        NSApp.activate(ignoringOtherApps: true)
        DownloadManager.shared.shouldOpenMainWindow = true
        
        // Set pending torrent URL and show sheet
        DownloadManager.shared.pendingTorrentURL = url
        DownloadManager.shared.showAddTorrentSheet = true
    }
    
    /// Check and prompt user to set as default torrent handler on first launch
    func promptSetAsDefaultTorrentApp() {
        let hasPrompted = UserDefaults.standard.bool(forKey: "hasPromptedDefaultTorrentApp")
        guard !hasPrompted else { return }
        
        // Mark as prompted regardless of user choice
        UserDefaults.standard.set(true, forKey: "hasPromptedDefaultTorrentApp")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            let alert = NSAlert()
            alert.messageText = "使用 MotrixMac 打开种子文件？"
            alert.informativeText = "将 MotrixMac 设为默认的 .torrent 文件处理程序，双击种子文件即可快速开始下载。"
            alert.alertStyle = .informational
            alert.addButton(withTitle: "设为默认")
            alert.addButton(withTitle: "暂不设置")
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                self.setAsDefaultTorrentApp()
            }
        }
    }
    
    private func setAsDefaultTorrentApp() {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else { return }
        
        // Set as default handler for .torrent files using CoreServices
        LSSetDefaultRoleHandlerForContentType(
            "org.bittorrent.torrent" as CFString,
            .all,
            bundleIdentifier as CFString
        )
        
        // Also try with public.bittorrent
        LSSetDefaultRoleHandlerForContentType(
            "public.bittorrent-torrent" as CFString,
            .all,
            bundleIdentifier as CFString
        )
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
