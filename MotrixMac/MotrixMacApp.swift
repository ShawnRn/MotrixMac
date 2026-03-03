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
    static let mainInterfaceDidAppear = Notification.Name("mainInterfaceDidAppear")
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
            Button("设置".localized(for: language) + "...") {
                NotificationCenter.default.post(name: .openSettings, object: nil)
            }
            .keyboardShortcut(",", modifiers: .command)
            
            Button("检查更新".localized(for: language) + "...") {
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
    private var dockTileView: DockSpeedTileView?
    private let dockBadgeCountKey = "dockCompletedBadgeCount"
    private var pendingDockBadgeCount = 0
    
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
        
        configureDockTileIfNeeded()
        pendingDockBadgeCount = max(0, UserDefaults.standard.integer(forKey: dockBadgeCountKey))
        applyDockBadge()
        
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
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(mainInterfaceDidAppear),
            name: .mainInterfaceDidAppear,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
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
        
        // Initial clear if launched into foreground
        if NSApp.isActive {
            clearDockCompletedBadge()
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        clearDockCompletedBadge()
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
    
    @objc private func mainInterfaceDidAppear() {
        clearDockCompletedBadge()
    }
    
    @objc private func screenParametersDidChange() {
        configureDockTileIfNeeded()
        dockTileView?.displayScale = effectiveDockDisplayScale()
        NSApp.dockTile.display()
    }

    func updateDockDownloadIndicator(totalSpeed: Int64, hasDownloadingTasks: Bool, progress: CGFloat) {
        configureDockTileIfNeeded()
        let speedText = hasDownloadingTasks ? compactSpeedText(for: totalSpeed) : nil
        let clampedProgress = hasDownloadingTasks ? min(max(progress, 0), 1) : 0
        var needsDisplay = false
        
        if dockTileView?.speedText != speedText {
            dockTileView?.speedText = speedText
            needsDisplay = true
        }
        
        if let view = dockTileView, abs(view.progress - clampedProgress) > 0.005 {
            view.progress = clampedProgress
            needsDisplay = true
        }
        
        if needsDisplay {
            NSApp.dockTile.display()
        }
    }
    
    func incrementDockCompletedBadge(by count: Int = 1) {
        guard count > 0 else { return }
        
        // mainstream behavior: don't badge if app is already active
        if NSApp.isActive {
            return
        }
        
        pendingDockBadgeCount += count
        UserDefaults.standard.set(pendingDockBadgeCount, forKey: dockBadgeCountKey)
        applyDockBadge()
    }
    
    func clearDockCompletedBadge() {
        guard pendingDockBadgeCount > 0 else { return }
        pendingDockBadgeCount = 0
        UserDefaults.standard.set(0, forKey: dockBadgeCountKey)
        UserDefaults.standard.synchronize()
        applyDockBadge()
    }
    
    private func applyDockBadge() {
        NSApp.dockTile.badgeLabel = pendingDockBadgeCount > 0 ? "\(pendingDockBadgeCount)" : nil
        NSApp.dockTile.display()
    }
    
    private func configureDockTileIfNeeded() {
        let size = NSApp.dockTile.size
        let width = max(size.width, 32)
        let height = max(size.height, 32)
        let targetFrame = NSRect(x: 0, y: 0, width: width, height: height)
        
        if let existingView = dockTileView {
            if existingView.frame.size != targetFrame.size {
                existingView.frame = targetFrame
                existingView.needsDisplay = true
            }
            existingView.displayScale = effectiveDockDisplayScale()
            return
        }
        
        let newView = DockSpeedTileView(
            frame: targetFrame,
            iconImage: NSApp.applicationIconImage
        )
        newView.displayScale = effectiveDockDisplayScale()
        dockTileView = newView
        NSApp.dockTile.contentView = newView
        NSApp.dockTile.display()
    }
    
    private func effectiveDockDisplayScale() -> CGFloat {
        // Dock 在外接屏切换时会变化；优先取主屏，其次任意可用屏。
        let scale = NSScreen.main?.backingScaleFactor ?? NSScreen.screens.first?.backingScaleFactor ?? 2.0
        return max(1.0, min(scale, 3.0))
    }
    
    private func compactSpeedText(for speed: Int64) -> String {
        let value = Double(max(speed, 0))
        
        if value < 1024 {
            let k = value / 1024
            return k > 0 ? String(format: "%.1fK", k) : "0K"
        } else if value < 1024 * 1024 {
            let k = value / 1024
            return k >= 10 ? String(format: "%.0fK", k) : String(format: "%.1fK", k)
        } else if value < 1024 * 1024 * 1024 {
            let m = value / (1024 * 1024)
            return m >= 10 ? String(format: "%.0fM", m) : String(format: "%.1fM", m)
        } else {
            let g = value / (1024 * 1024 * 1024)
            return g >= 10 ? String(format: "%.0fG", g) : String(format: "%.1fG", g)
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
        // mainstream behavior: clear badge when dock icon is clicked
        clearDockCompletedBadge()
        
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

private final class DockSpeedTileView: NSView {
    private let iconImage: NSImage
    var displayScale: CGFloat = 2.0 {
        didSet {
            if abs(oldValue - displayScale) > 0.001 {
                needsDisplay = true
            }
        }
    }
    var speedText: String? {
        didSet {
            needsDisplay = true
        }
    }
    var progress: CGFloat = 0 {
        didSet {
            if abs(oldValue - progress) > 0.001 {
                needsDisplay = true
            }
        }
    }

    init(frame frameRect: NSRect, iconImage: NSImage) {
        self.iconImage = iconImage
        super.init(frame: frameRect)
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        return nil
    }
    
    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        iconImage.draw(in: bounds)
        
        guard let speedText, !speedText.isEmpty else { return }

        let minSide = min(bounds.width, bounds.height)
        let lowDPISizeBoost: CGFloat = displayScale < 1.5 ? 1.20 : 1.0
        let indicatorHeight = max(16.0 * lowDPISizeBoost, minSide * 0.32 * lowDPISizeBoost)
        let horizontalPadding = max(4.0, minSide * 0.08)
        let availableWidth = bounds.width - (horizontalPadding * 2)
        let widthSafety = max(2.0, 2.0 / max(displayScale, 1.0))
        
        let ringWidth = max(4.2 / max(displayScale, 1.0), 3.3)
        let ringGap = max(1.0, 1.2 / max(displayScale, 1.0))
        let ringInset = ringGap + ringWidth * 0.5
        let minimumBottomPadding = ringInset + 1.0
        let verticalPadding = max(minimumBottomPadding, minSide * 0.08)
        
        var fontSize = max(11.0 * lowDPISizeBoost, indicatorHeight * 0.56)
        let minFontSize = max(9.0, 9.5 * lowDPISizeBoost)
        var attributes: [NSAttributedString.Key: Any] = [:]
        var textSize = CGSize.zero
        repeat {
            attributes = [
                .font: NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .semibold),
                .foregroundColor: NSColor.white
            ]
            textSize = speedText.size(withAttributes: attributes)
            if textSize.width + horizontalPadding * 2.2 + widthSafety <= availableWidth || fontSize <= minFontSize {
                break
            }
            fontSize -= 0.5
        } while true
        
        let widthAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .semibold)
        ]
        let stableTemplateWidth = ("999K" as NSString).size(withAttributes: widthAttributes).width
        let minIndicatorWidth = stableTemplateWidth + horizontalPadding * 2.2 + widthSafety
        let indicatorWidth = min(
            availableWidth,
            max(minIndicatorWidth, textSize.width + horizontalPadding * 2.2 + widthSafety)
        )

        var indicatorRect = NSRect(
            x: (bounds.width - indicatorWidth) * 0.5,
            y: verticalPadding,
            width: indicatorWidth,
            height: indicatorHeight
        )
        indicatorRect = pixelAligned(indicatorRect, scale: displayScale)

        let indicatorPath = NSBezierPath(roundedRect: indicatorRect, xRadius: indicatorHeight / 2, yRadius: indicatorHeight / 2)
        NSColor.controlAccentColor.withAlphaComponent(0.95).setFill()
        indicatorPath.fill()
        
        NSColor.white.withAlphaComponent(0.30).setStroke()
        indicatorPath.lineWidth = max(1.0 / displayScale, 0.75)
        indicatorPath.stroke()

        var textOrigin = NSPoint(
            x: indicatorRect.midX - textSize.width * 0.5,
            y: indicatorRect.midY - textSize.height * 0.5
        )
        textOrigin = pixelAligned(textOrigin, scale: displayScale)
        (speedText as NSString).draw(at: textOrigin, withAttributes: attributes)
        
        // Capsule ring around pill; only progressed segment is rendered.
        let clampedProgress = min(max(progress, 0), 1)
        if clampedProgress > 0 {
            var ringRect = indicatorRect.insetBy(dx: -ringInset, dy: -ringInset)
            ringRect = pixelAligned(ringRect, scale: displayScale)
            let ringPath = capsuleProgressPath(in: ringRect, progress: clampedProgress)
            ringPath.lineWidth = ringWidth
            ringPath.lineCapStyle = .round
            ringPath.lineJoinStyle = .round
            NSColor.white.withAlphaComponent(0.98).setStroke()
            ringPath.stroke()
        }
    }

    private func capsuleProgressPath(in rect: NSRect, progress: CGFloat) -> NSBezierPath {
        let path = NSBezierPath()
        let clamped = min(max(progress, 0), 1)
        guard clamped > 0 else { return path }

        let radius = rect.height * 0.5
        let straight = max(0, rect.width - radius * 2)
        let arcLength = CGFloat.pi * radius
        let topHalf = straight * 0.5
        let totalLength = topHalf + arcLength + straight + arcLength + topHalf
        var remaining = totalLength * clamped

        let xMid = rect.midX
        let yTop = rect.maxY
        let yBottom = rect.minY
        let rightX = rect.maxX - radius
        let leftX = rect.minX + radius
        let rightCenter = NSPoint(x: rightX, y: rect.midY)
        let leftCenter = NSPoint(x: leftX, y: rect.midY)

        path.move(to: NSPoint(x: xMid, y: yTop))

        if topHalf > 0 {
            if remaining <= topHalf {
                path.line(to: NSPoint(x: xMid + remaining, y: yTop))
                return path
            }
            path.line(to: NSPoint(x: rightX, y: yTop))
            remaining -= topHalf
        }

        if radius > 0 {
            if remaining <= arcLength {
                let delta = (remaining / radius) * 180 / CGFloat.pi
                path.appendArc(withCenter: rightCenter, radius: radius, startAngle: 90, endAngle: 90 - delta, clockwise: true)
                return path
            }
            path.appendArc(withCenter: rightCenter, radius: radius, startAngle: 90, endAngle: -90, clockwise: true)
            remaining -= arcLength
        }

        if straight > 0 {
            if remaining <= straight {
                path.line(to: NSPoint(x: rightX - remaining, y: yBottom))
                return path
            }
            path.line(to: NSPoint(x: leftX, y: yBottom))
            remaining -= straight
        }

        if radius > 0 {
            if remaining <= arcLength {
                let delta = (remaining / radius) * 180 / CGFloat.pi
                path.appendArc(withCenter: leftCenter, radius: radius, startAngle: -90, endAngle: -90 - delta, clockwise: true)
                return path
            }
            path.appendArc(withCenter: leftCenter, radius: radius, startAngle: -90, endAngle: -270, clockwise: true)
            remaining -= arcLength
        }

        if topHalf > 0 {
            let consumed = min(remaining, topHalf)
            path.line(to: NSPoint(x: leftX + consumed, y: yTop))
        }

        return path
    }

    private func pixelAligned(_ rect: NSRect, scale: CGFloat) -> NSRect {
        guard scale > 0 else { return rect }
        let x = (rect.origin.x * scale).rounded() / scale
        let y = (rect.origin.y * scale).rounded() / scale
        let w = (rect.size.width * scale).rounded() / scale
        let h = (rect.size.height * scale).rounded() / scale
        return NSRect(x: x, y: y, width: w, height: h)
    }

    private func pixelAligned(_ point: NSPoint, scale: CGFloat) -> NSPoint {
        guard scale > 0 else { return point }
        let x = (point.x * scale).rounded() / scale
        let y = (point.y * scale).rounded() / scale
        return NSPoint(x: x, y: y)
    }
}
