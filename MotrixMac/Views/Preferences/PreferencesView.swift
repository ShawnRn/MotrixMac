import Observation
import ServiceManagement
import SwiftUI

enum EmbeddedSettingsTab: String, Identifiable, CaseIterable {
    case general, downloads, network, advanced
    var id: String { self.rawValue }
    
    func title(for language: String) -> String {
        switch self {
        case .general: return "通用".localized(for: language)
        case .downloads: return "下载".localized(for: language)
        case .network: return "网络".localized(for: language)
        case .advanced: return "高级".localized(for: language)
        }
    }
}

struct LiquidSettingsPicker: View {
    @Binding var selection: EmbeddedSettingsTab
    let namespace: Namespace.ID
    @AppStorage("language") private var language = "zh-CN"
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(EmbeddedSettingsTab.allCases) { tab in
                Text(tab.title(for: language))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                    .opacity(selection == tab ? 1.0 : 0.6)
                    .padding(.horizontal, 18)
                    .frame(height: 28) // Fixed height for selection box
                    .background {
                        if selection == tab {
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .fill(.secondary.opacity(0.18))
                                .matchedGeometryEffect(id: "selector", in: namespace)
                        }
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 13))
                    .onTapGesture {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
                            selection = tab
                        }
                    }
                
                if tab != .advanced {
                    Divider()
                        .frame(height: 12)
                        .opacity(0.12)
                }
            }
        }
        .textSelection(.disabled)
        .padding(4) // Absolute uniform gap
        .background {
            // Concentric: Inner (13) + Padding (4) = 17
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(.quaternary.opacity(0.05))
        }
        .fixedSize() // Prevent toolbar from stretching it
        .transition(.identity) // 阻止入场/退场过渡动画，但不影响内部 withAnimation 的滑块动画
    }
}

/// Standalone Preferences view for macOS Settings scene
struct PreferencesView: View {
    @AppStorage("theme") private var theme = "auto"
    @AppStorage("language") private var language = "zh-CN"
    @State private var selectedTab: EmbeddedSettingsTab = .general
    
    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralPreferencesTab()
                .tabItem { Label("通用".localized(for: language), systemImage: "gear") }
                .tag(EmbeddedSettingsTab.general)

            DownloadsPreferencesTab()
                .tabItem { Label("下载".localized(for: language), systemImage: "arrow.down.circle") }
                .tag(EmbeddedSettingsTab.downloads)

            NetworkPreferencesTab()
                .tabItem { Label("网络".localized(for: language), systemImage: "network") }
                .tag(EmbeddedSettingsTab.network)

            AdvancedPreferencesTab()
                .tabItem { Label("高级".localized(for: language), systemImage: "gearshape.2") }
                .tag(EmbeddedSettingsTab.advanced)
        }
        .tabViewStyle(.automatic)
        .frame(width: 500, height: 400)
        .onTapGesture {
            NSApp.keyWindow?.makeFirstResponder(nil)
        }
    }
}

struct EmbeddedPreferencesView: View {
    @Binding var activeTab: EmbeddedSettingsTab
    
    var body: some View {
        ZStack {
            GeneralPreferencesTab()
                .opacity(activeTab == .general ? 1 : 0)
                .allowsHitTesting(activeTab == .general)
            
            DownloadsPreferencesTab()
                .opacity(activeTab == .downloads ? 1 : 0)
                .allowsHitTesting(activeTab == .downloads)
            
            NetworkPreferencesTab()
                .opacity(activeTab == .network ? 1 : 0)
                .allowsHitTesting(activeTab == .network)
            
            AdvancedPreferencesTab()
                .opacity(activeTab == .advanced ? 1 : 0)
                .allowsHitTesting(activeTab == .advanced)
        }
        // 不对 ZStack 施加广播式动画——4个重型 Form 同时做透明度渐变会带来渲染压力
        // 透明度瞬时切换更干脆，滑块动画由 LiquidSettingsPicker 内部的 withAnimation 单独控制
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onTapGesture {
            NSApp.keyWindow?.makeFirstResponder(nil)
        }
    }
}

// MARK: - General Tab

struct GeneralPreferencesTab: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("silentStart") private var silentStart = false
    @AppStorage("theme") private var theme = "auto"
    @AppStorage("language") private var language = "zh-CN"
    @AppStorage("showSpeedInMenuBar") private var showSpeedInMenuBar = false
    @AppStorage("autoJumpOnTaskCreated") private var autoJumpOnTaskCreated = true
    @AppStorage("skipDeleteConfirmation") private var skipDeleteConfirmation = false
    @AppStorage("showInDock") private var showInDock = true
    @AppStorage("singleListMode") private var singleListMode = false
    @AppStorage("autoDeleteInterval") private var autoDeleteInterval = 0

    var body: some View {
        Form {
            Section {
                Toggle("开机启动".localized(for: language), isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        updateLaunchAtLogin(enabled: newValue)
                    }
                    .textSelection(.disabled)

                InfoToggle(
                    title: "静默启动".localized(for: language),
                    info: "启用后，开机启动时不会自动显示主窗口".localized(for: language),
                    isOn: $silentStart
                )
                    .disabled(!launchAtLogin)
                    .foregroundColor(launchAtLogin ? .primary : .secondary)

                InfoToggle(
                    title: "在 Dock 中显示".localized(for: language),
                    info: "是否在 macOS Dock 栏显示应用图标".localized(for: language),
                    isOn: $showInDock
                )

                InfoToggle(
                    title: "在菜单栏显示速度".localized(for: language),
                    info: "在系统菜单栏实时显示当前下载和上传速度".localized(for: language),
                    isOn: $showSpeedInMenuBar
                )
                
                InfoToggle(
                    title: "自动跳转到下载页面".localized(for: language),
                    info: "新建任务后自动跳转到下载页面".localized(for: language),
                    isOn: $autoJumpOnTaskCreated
                )
                
                InfoToggle(
                    title: "快速删除任务".localized(for: language),
                    info: "删除任务前无需确认".localized(for: language),
                    isOn: $skipDeleteConfirmation
                )



                InfoToggle(
                    title: "单列表模式".localized(for: language),
                    info: "融合下载中和已完成列表，将所有任务显示在同一个主页视图中。".localized(for: language),
                    isOn: $singleListMode
                )
            }

            Section {

                Picker("外观".localized(for: language), selection: $theme) {
                    Text("跟随系统".localized(for: language)).tag("auto")
                    Text("浅色".localized(for: language)).tag("light")
                    Text("深色".localized(for: language)).tag("dark")
                }
                .textSelection(.disabled)

                Picker("语言".localized(for: language), selection: $language) {
                    Text(verbatim: "English").tag("en")
                    Text(verbatim: "简体中文").tag("zh-CN")
                    Text(verbatim: "繁體中文").tag("zh-TW")
                    Text(verbatim: "日本語").tag("ja")
                    Text(verbatim: "한국어").tag("ko")
                }
                .textSelection(.disabled)
                
                Picker("自动清除任务".localized(for: language), selection: $autoDeleteInterval) {
                    Text("1 天".localized(for: language)).tag(1)
                    Text("3 天".localized(for: language)).tag(3)
                    Text("7 天".localized(for: language)).tag(7)
                    Text("10 天".localized(for: language)).tag(10)
                    Text("1 个月".localized(for: language)).tag(30)
                    Text("3 个月".localized(for: language)).tag(90)
                    Text("关闭".localized(for: language)).tag(0)
                }
                .textSelection(.disabled)
            }

        }
        .formStyle(.grouped)
        .padding()
        .textSelection(.disabled) // Fix cursor turning to text selection I-beam
    }

    private func updateLaunchAtLogin(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to update launch at login: \(error)")
        }
    }
}

// MARK: - Downloads Tab

struct DownloadsPreferencesTab: View {
    @AppStorage("defaultDownloadDirectory") private var downloadDirectory = FileManager.default
        .urls(for: .downloadsDirectory, in: .userDomainMask).first!.path
    @AppStorage("maxConcurrentDownloads") private var maxConcurrent = 5
    @AppStorage("defaultConnections") private var defaultConnections = 64
    @AppStorage("autoRenameFiles") private var autoRename = true
    @AppStorage("notifyOnComplete") private var notifyOnComplete = true
    @AppStorage("autoJumpOnTaskCreated") private var autoJumpOnTaskCreated = true
    
    // Speed limit units
    @AppStorage("downloadSpeedUnit") private var downloadSpeedUnit = "KB/s"
    @AppStorage("uploadSpeedUnit") private var uploadSpeedUnit = "KB/s"
    @AppStorage("maxDownloadSpeed") private var maxDownloadSpeed = 0
    @AppStorage("maxUploadSpeed") private var maxUploadSpeed = 0

    // BT Settings
    @AppStorage("btSaveMetadata") private var btSaveMetadata = true
    @AppStorage("btAutoStart") private var btAutoStart = true
    @AppStorage("btContinuousSeeding") private var btContinuousSeeding = false
    @AppStorage("seedRatio") private var seedRatio = 1.0
    @AppStorage("seedTime") private var seedTime = 60 // minutes
    @AppStorage("continueDownload") private var continueDownload = true

    @AppStorage("language") private var language = "zh-CN"


    var body: some View {
        Form {
            Section {
                HStack {
                    TextField("", text: $downloadDirectory)
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.leading)
                        .padding(6)
                        .background {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(.quaternary)
                        }

                    Button("选择...") {
                        selectDirectory()
                    }
                }
                .textSelection(.disabled)
            } header: {
                Text("保存位置".localized(for: language))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Section {
                Stepper("最大同时下载数：".localized(for: language) + "\(maxConcurrent)", value: $maxConcurrent, in: 1...10)
                
                HStack {
                    Text("单任务最大线程数：".localized(for: language) + "\(defaultConnections)")
                        .fixedSize()
                    Spacer()
                    Slider(value: Binding(
                        get: { Double(defaultConnections) },
                        set: { defaultConnections = Int($0) }
                    ), in: 1...128) {
                        EmptyView()
                    }
                    .frame(width: 280)
                    .onChange(of: defaultConnections) { _, _ in
                        saveConnections()
                    }
                }

                Toggle("断点续传".localized(for: language), isOn: $continueDownload)
            } header: {
                Text("任务管理".localized(for: language))
            }

            Section {
                HStack {
                    Text("上传限速".localized(for: language))
                    Spacer()
                    TextField("", value: $maxUploadSpeed, format: .number)
                        .textFieldStyle(.plain)
                        .padding(6)
                        .frame(width: 80)
                        .background {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(nsColor: .controlBackgroundColor))
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                        }
                    
                    Picker("", selection: $uploadSpeedUnit) {
                        Text("KB/s".localized(for: language)).tag("KB/s")
                        Text("MB/s".localized(for: language)).tag("MB/s")
                    }
                    .pickerStyle(.menu)
                    .frame(width: 100)
                }

                HStack {
                    Text("下载限速".localized(for: language))
                    Spacer()
                    TextField("", value: $maxDownloadSpeed, format: .number)
                        .textFieldStyle(.plain)
                        .padding(6)
                        .frame(width: 80)
                        .background {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(nsColor: .controlBackgroundColor))
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                        }
                    
                    Picker("", selection: $downloadSpeedUnit) {
                        Text("KB/s".localized(for: language)).tag("KB/s")
                        Text("MB/s".localized(for: language)).tag("MB/s")
                    }
                    .pickerStyle(.menu)
                    .frame(width: 100)
                }

                Text("设为 0 表示无限制".localized(for: language))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } header: {
                Text("传输设置".localized(for: language))
            }

            Section {
                InfoToggle(
                    title: "保存磁力链接元数据为种子文件".localized(for: language),
                    info: "下载磁力链接时，自动保存 .torrent 种子文件到下载目录".localized(for: language),
                    isOn: $btSaveMetadata
                )
                
                InfoToggle(
                    title: "自动开始下载磁力链接、种子文件".localized(for: language),
                    info: "添加任务后自动开始下载，无需手动确认".localized(for: language),
                    isOn: $btAutoStart
                )
                
                InfoToggle(
                    title: "持续做种，直到手动停止".localized(for: language),
                    info: "任务完成后继续做种，直到手动移除或暂停".localized(for: language),
                    isOn: $btContinuousSeeding
                )
                
                if !btContinuousSeeding {
                    Group {
                        HStack {
                            Text("做种分享率".localized(for: language))
                            Spacer()
                            TextField("", value: $seedRatio, format: .number)
                                .textFieldStyle(.plain)
                                .padding(6)
                                .frame(width: 80)
                                .background {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color(nsColor: .controlBackgroundColor))
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                                }
                        }
                        
                        HStack {
                            Text("做种时间 (分钟)".localized(for: language))
                            Spacer()
                            TextField("", value: $seedTime, format: .number)
                                .textFieldStyle(.plain)
                                .padding(6)
                                .frame(width: 80)
                                .background {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color(nsColor: .controlBackgroundColor))
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                                }
                        }
                    }
                    .textSelection(.disabled)
                }
            } header: {
                Text("BT 设置".localized(for: language))
            }

            Section {
                Toggle("自动重命名已存在文件".localized(for: language), isOn: $autoRename)
                Toggle("下载完成时通知".localized(for: language), isOn: $notifyOnComplete)
            } header: {
                Text("常规行为".localized(for: language))
            }
        }
        .formStyle(.grouped)
        .padding()
        .onChange(of: maxConcurrent) { _, _ in
            Task { await DownloadManager.shared.applyGlobalOptions() }
        }
    }


    private func saveConnections() {
        print("PreferencesView: Saving defaultConnections = \(defaultConnections)")
        UserDefaults.standard.set(defaultConnections, forKey: "defaultConnections")
        UserDefaults.standard.synchronize()
        Task {
            await DownloadManager.shared.applyGlobalOptions()
            await DownloadManager.shared.restartEngine()
        }
    }

    func selectDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true

        if panel.runModal() == .OK, let url = panel.url {
            downloadDirectory = url.path
        }
    }
}

// MARK: - Network Tab

struct NetworkPreferencesTab: View {
    @AppStorage("proxyEnabled") private var proxyEnabled = false
    @AppStorage("proxyHost") private var proxyHost = ""
    @AppStorage("proxyPort") private var proxyPort = ""
    @AppStorage("proxyUsername") private var proxyUsername = ""
    @AppStorage("proxyPassword") private var proxyPassword = ""
    @AppStorage("maxDownloadSpeed") private var maxDownloadSpeed = 0
    @AppStorage("maxUploadSpeed") private var maxUploadSpeed = 0
    // Network Enhanced Defaults: IPv6 Disabled, Async DNS Disabled
    @AppStorage("enableIPv6") private var enableIPv6 = false
    @AppStorage("enableAsyncDNS") private var enableAsyncDNS = false
    
    // Protocol Association
    @AppStorage("handleMagnetLinks") private var handleMagnetLinks = true
    @AppStorage("handleThunderLinks") private var handleThunderLinks = false

    @AppStorage("language") private var language = "zh-CN" // Added for localization

    var body: some View {
        Form {
            Section {
                Toggle("磁力链接 [ magnet:// ]".localized(for: language), isOn: $handleMagnetLinks)
                    .onChange(of: handleMagnetLinks) { _, newValue in
                        updateProtocolHandler(scheme: "magnet", enabled: newValue)
                    }
                Toggle("迅雷链接 [ thunder:// ]".localized(for: language), isOn: $handleThunderLinks)
                    .onChange(of: handleThunderLinks) { _, newValue in
                        updateProtocolHandler(scheme: "thunder", enabled: newValue)
                    }
                .textSelection(.disabled)
            } header: {
                Text("下载协议: 设置为以下协议的默认客户端".localized(for: language))
            }

            Section {
                Toggle("启用代理".localized(for: language), isOn: $proxyEnabled)

                if proxyEnabled {
                    Group {
                        TextField("主机".localized(for: language), text: $proxyHost)
                        TextField("端口".localized(for: language), text: $proxyPort)
                        TextField("用户名 （可选）".localized(for: language), text: $proxyUsername)
                        SecureField("密码 （可选）".localized(for: language), text: $proxyPassword)
                    }
                    .textFieldStyle(.plain)
                    .padding(6)
                    .background {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(nsColor: .controlBackgroundColor))
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    }
                    .textSelection(.disabled)
                }
            } header: {
                Text("代理".localized(for: language))
            }

            Section {
                InfoToggle(
                    title: "启用 IPv6".localized(for: language),
                    info: "如果您的网络环境不支持 IPv6，启用此选项可能导致连接超时。".localized(for: language),
                    isOn: $enableIPv6
                )
                
                InfoToggle(
                    title: "启用异步 DNS".localized(for: language),
                    info: "启用 aria2 内置的异步 DNS 解析。如果您使用了代理软件，建议关闭此选项以防止 DNS 污染。".localized(for: language),
                    isOn: $enableAsyncDNS
                )
            } header: {
                Text("高级网络".localized(for: language))
            }
        }
        .formStyle(.grouped)
        .padding()
        .onChange(of: enableIPv6) { _, _ in restartEngine() }
        .onChange(of: enableAsyncDNS) { _, _ in restartEngine() }
    }
    
    private func updateProtocolHandler(scheme: String, enabled: Bool) {
        // Note: URL Scheme registration is primarily handled via Info.plist and system association.
        // This toggle allows users to express preference.
        print("PreferencesView: Protocol handler for \(scheme) set to \(enabled)")
    }

    private func restartEngine() {
        Task {
            await DownloadManager.shared.restartEngine()
        }
    }
}

// MARK: - Advanced Tab

struct AdvancedPreferencesTab: View {
    @Environment(DownloadManager.self) private var downloadManager
    
    // Use State for pending changes instead of AppStorage
    @State private var rpcPort: Int = 12800
    @State private var rpcSecret: String = ""
    @State private var enableUpnp: Bool = true
    @State private var enableDht: Bool = true
    @State private var enablePex: Bool = true
    @State private var enableLpd: Bool = true
    @State private var btEncryptionMode: Int = 0 // 0: Allow, 1: Force, 2: Disable
    @State private var btPort: Int = 6881
    @State private var autoSyncTracker: Bool = true
    @State private var trackerSource: String = "trackers_best.txt"
    @State private var userAgent: String = "MotrixMac/2.0"
    @State private var updateInterval: String = "daily"
    @State private var customTrackerURLs: String = "" // [NEW] User defined subscription URLs
    
    // For manual tracker input
    @State private var trackerListText: String = ""
    @State private var showSecret = false
    
    // Sync dirty state to AppStorage for toolbar visibility
    @AppStorage("settingsAreDirty") private var settingsAreDirty = false
    
    // Track original values for dirty checking
    @State private var originalRpcPort: Int = 12800
    @State private var originalRpcSecret: String = ""
    @State private var originalEnableUpnp: Bool = true
    @State private var originalEnableDht: Bool = true
    @State private var originalEnablePex: Bool = true
    @State private var originalEnableLpd: Bool = true
    @State private var originalBtEncryptionMode: Int = 0
    @State private var originalBtPort: Int = 6881
    @State private var originalAutoSyncTracker: Bool = true
    @State private var originalTrackerSource: String = "trackers_best.txt"
    @State private var originalUserAgent: String = "MotrixMac/2.0"
    @State private var originalTrackerListText: String = ""
    @State private var originalUpdateInterval: String = "daily"
    @State private var originalCustomTrackerURLs: String = ""

    // Log Level Persistence
    @AppStorage("LogLevel") private var logLevelRaw: Int = 1

    @AppStorage("language") private var language = "zh-CN" // Added for localization

    // Fetching state
    @State private var isFetchingTrackers = false

    var body: some View {
        Form {
            // Tracker Settings
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        TrackerSourceSelector(
                            sources: availableTrackers,
                            selection: Binding(
                                get: { trackerSource.components(separatedBy: ",").filter { !$0.isEmpty } },
                                set: { trackerSource = $0.joined(separator: ",") }
                            ),
                            customURLs: $customTrackerURLs,
                            isFetching: isFetchingTrackers,
                            fetchAction: { Task { await fetchTrackers() } },
                            language: language // Pass language
                        )
                    }
                    
                    Toggle("自动同步 Tracker 服务器列表".localized(for: language), isOn: $autoSyncTracker)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .onChange(of: autoSyncTracker) { _, newValue in
                            Task {
                                if newValue {
                                    await TrackerService.shared.startAutoUpdate()
                                } else {
                                    await TrackerService.shared.stopAutoUpdate()
                                }
                            }
                        }
                    
                    Picker("更新频率".localized(for: language), selection: $updateInterval) {
                        Text("每 12 小时".localized(for: language)).tag("12h")
                        Text("每天".localized(for: language)).tag("daily")
                        Text("每周".localized(for: language)).tag("weekly")
                        Text("每月".localized(for: language)).tag("monthly")
                    }
                    .disabled(!autoSyncTracker)
                    .foregroundStyle(autoSyncTracker ? .primary : .secondary)
                }
                .padding(.vertical, 4)
            } header: {
                Text("Tracker 服务器 (订阅)".localized(for: language))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            Section {
                TextEditor(text: $trackerListText)
                    .font(.system(.caption, design: .monospaced))
                    .frame(height: 120)
                    .padding(1)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.1), lineWidth: 1))
            } header: {
                Text("当前 Tracker 列表 (手动编辑)".localized(for: language))
            }

            // RPC Settings
            Section {
                HStack {
                    Text("RPC 监听端口".localized(for: language))
                        .frame(width: 100, alignment: .leading)
                    
                    TextField("", value: $rpcPort, format: .number.grouping(.never))
                        .textFieldStyle(.plain)
                        .padding(6)
                        .background {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(nsColor: .controlBackgroundColor))
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                        }
                }
                
                HStack {
                    Text("RPC 授权密钥".localized(for: language))
                        .frame(width: 100, alignment: .leading)
                    
                    HStack(spacing: 8) {
                        Group {
                            if showSecret {
                                TextField("", text: $rpcSecret)
                                    .textFieldStyle(.plain)
                            } else {
                                SecureField("", text: $rpcSecret)
                                    .textFieldStyle(.plain)
                            }
                        }
                        
                        Button {
                            showSecret.toggle()
                        } label: {
                            Image(systemName: showSecret ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help(showSecret ? "隐藏".localized(for: language) : "显示".localized(for: language))
                        
                        Button {
                            // Copy to clipboard
                            let pasteboard = NSPasteboard.general
                            pasteboard.clearContents()
                            pasteboard.setString(rpcSecret, forType: .string)
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("复制".localized(for: language))
                        
                        Button {
                            rpcSecret = generateRandomSecret()
                        } label: {
                            Image(systemName: "dice")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("随机生成".localized(for: language))
                    }
                    .padding(6)
                    .background {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(nsColor: .controlBackgroundColor))
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    }
                }

                Text("修改 RPC 设置后将自动热重启引擎生效".localized(for: language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                if let rpcError = downloadManager.lastRpcError {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("RPC 错误：\(rpcError == "Unauthorized" ? "授权失败 （密钥不匹配）".localized(for: language) : rpcError)")
                                .fontWeight(.medium)
                            Text("当前系统可能存在一个旧的 aria2 进程正在使用此端口，且其密钥与当前设置不符。".localized(for: language))
                                .font(.caption2)
                        }
                        
                        Spacer()
                        
                        Button("强制重置引擎".localized(for: language)) {
                            resetEngine()
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                    .padding(10)
                    .background(Color.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                
                // New: Engine Startup Error check
                if let appDelegate = NSApplication.shared.delegate as? AppDelegate,
                   let engine = appDelegate.aria2Process,
                   let engineError = engine.lastErrorMessage {
                    HStack(spacing: 12) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("引擎启动失败".localized(for: language))
                                .fontWeight(.medium)
                            Text(engineError)
                                .font(.caption2)
                        }
                        
                        Spacer()
                        
                        Button("重试".localized(for: language)) {
                            resetEngine()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(10)
                    .background(Color.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .textSelection(.disabled)
                }
            } header: {
                Text("RPC".localized(for: language))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Privacy & BitTorrent Settings
            Section {
                InfoToggle(
                    title: "启用 DHT (去中心化网络)".localized(for: language),
                    info: "启用 Distributed Hash Table 以找到更多用户 (Peers)".localized(for: language),
                    isOn: $enableDht
                )
                
                InfoToggle(
                    title: "启用用户交换 (PeX)".localized(for: language),
                    info: "启用 Peer Exchange 以找到更多用户 (Peers)".localized(for: language),
                    isOn: $enablePex
                )
                
                InfoToggle(
                    title: "启用本地用户发现 (LPD)".localized(for: language),
                    info: "启用 Local Peer Discovery 以找到更多用户 (Peers)".localized(for: language),
                    isOn: $enableLpd
                )
                
                Picker("加密模式".localized(for: language), selection: $btEncryptionMode) {
                    Text("允许加密".localized(for: language)).tag(0)
                    Text("强制加密".localized(for: language)).tag(1)
                    Text("禁用加密".localized(for: language)).tag(2)
                }
                .pickerStyle(.menu)

                HStack {
                    Text("启用 UPnP/NAT-PMP".localized(for: language))
                    Spacer()
                    Toggle("", isOn: $enableUpnp)
                        .labelsHidden()
                }

                HStack {
                    Text("BT 监听端口".localized(for: language))
                        .frame(width: 100, alignment: .leading)
                    
                    TextField("", value: $btPort, format: .number.grouping(.never))
                        .textFieldStyle(.plain)
                        .padding(6)
                        .background {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(nsColor: .controlBackgroundColor))
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                        }
                }
                .textSelection(.disabled)
            } header: {
                Text("隐私 & BitTorrent".localized(for: language))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // HTTP Settings
            Section {
                TextField("User-Agent".localized(for: language), text: $userAgent)
                    .textFieldStyle(.roundedBorder)
            } header: {
                Text("HTTP".localized(for: language))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Log Settings
            Section {
                 Picker("日志级别".localized(for: language), selection: Binding(
                    get: { LogLevel(rawValue: logLevelRaw) ?? .info },
                    set: { logLevelRaw = $0.rawValue }
                )) {
                    ForEach(LogLevel.allCases) { level in
                        Text(level.description).tag(level)
                    }
                }
                .pickerStyle(.menu)
                .help("设置应用程序日志的详细程度".localized(for: language))
                .onChange(of: logLevelRaw) { _, newValue in
                    Logger.shared.level = LogLevel(rawValue: newValue) ?? .info
                }
                
                Button("打开日志目录".localized(for: language)) {
                    openLogDirectory()
                }
                .textSelection(.disabled)
            } header: {
                Text("日志".localized(for: language))
            }

            // Reset
            Section {
                HStack {
                    Button("重置所有设置".localized(for: language)) {
                        restoreInitialSettings()
                    }
                    .foregroundStyle(.red)
                    
                    Spacer()
                    
                    Button("清除下载历史".localized(for: language)) {
                        Task { await downloadManager.clearAllStopped() }
                    }
                }
                .textSelection(.disabled)
            } header: {
                Text("常规重置".localized(for: language))
            }

            // Developer Section
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    PathRow(label: "内置的 aria2.conf 路径".localized(for: language), path: aria2ConfPath, language: language)
                    PathRow(label: "下载会话路径".localized(for: language), path: sessionPath, language: language)
                    PathRow(label: "应用日志路径".localized(for: language), path: logFilePath, language: language)
                }
                .padding(.vertical, 4)
                
                HStack(spacing: 12) {
                    Button {
                        resetSession()
                    } label: {
                        Text("重置下载会话记录".localized(for: language))
                            .font(.system(size: 13, weight: .medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                            .foregroundStyle(.orange)
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        restoreInitialSettings()
                    } label: {
                        Text("恢复初始设置".localized(for: language))
                            .font(.system(size: 13, weight: .medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)
            } header: {
                Text("开发者".localized(for: language))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            loadActualRuntimeValues()
            loadOriginals()
            // Ensure visual state is synced on appear
            settingsAreDirty = isDirty
        }
        .onChange(of: isDirty) { _, newValue in
            settingsAreDirty = newValue
        }
        .onReceive(NotificationCenter.default.publisher(for: .saveSettings)) { _ in
            saveSettings()
        }
        .onReceive(NotificationCenter.default.publisher(for: .discardSettings)) { _ in
            loadActualRuntimeValues()
            loadOriginals()
        }
    }
    
    private func loadActualRuntimeValues() {
        let defaults = UserDefaults.standard
        // Always load the PREFERRED port for the UI field
        rpcPort = defaults.integer(forKey: "rpcPort")
        if rpcPort == 0 { rpcPort = 12800 }
        
        rpcSecret = defaults.string(forKey: "rpcSecret") ?? ""
        enableUpnp = defaults.object(forKey: "enableUpnp") == nil ? true : defaults.bool(forKey: "enableUpnp")
        enableDht = defaults.object(forKey: "enableDht") == nil ? true : defaults.bool(forKey: "enableDht")
        enablePex = defaults.object(forKey: "enablePex") == nil ? true : defaults.bool(forKey: "enablePex")
        enableLpd = defaults.object(forKey: "enableLpd") == nil ? true : defaults.bool(forKey: "enableLpd")
        btEncryptionMode = defaults.integer(forKey: "btEncryptionMode")
        btPort = defaults.integer(forKey: "btListenPort") == 0 ? 6881 : defaults.integer(forKey: "btListenPort")
        autoSyncTracker = defaults.object(forKey: "autoSyncTracker") == nil ? true : defaults.bool(forKey: "autoSyncTracker")
        trackerSource = defaults.string(forKey: "trackerSource") ?? "trackers_best.txt"
        userAgent = defaults.string(forKey: "userAgent") ?? "MotrixMac/2.0"
        trackerListText = defaults.string(forKey: "btTrackers") ?? ""
        updateInterval = defaults.string(forKey: "trackerUpdateInterval") ?? "daily"
        customTrackerURLs = defaults.string(forKey: "customTrackerURLs") ?? ""
    }
    
    private var isDirty: Bool {
        rpcPort != originalRpcPort ||
        rpcSecret != originalRpcSecret ||
        enableUpnp != originalEnableUpnp ||
        enableDht != originalEnableDht ||
        enablePex != originalEnablePex ||
        enableLpd != originalEnableLpd ||
        btEncryptionMode != originalBtEncryptionMode ||
        btPort != originalBtPort ||
        autoSyncTracker != originalAutoSyncTracker ||
        trackerSource != originalTrackerSource ||
        userAgent != originalUserAgent ||
        trackerListText != originalTrackerListText ||
        updateInterval != originalUpdateInterval ||
        customTrackerURLs != originalCustomTrackerURLs
    }
    
    private func loadOriginals() {
        originalRpcPort = rpcPort
        originalRpcSecret = rpcSecret
        originalEnableUpnp = enableUpnp
        originalEnableDht = enableDht
        originalEnablePex = enablePex
        originalEnableLpd = enableLpd
        originalBtEncryptionMode = btEncryptionMode
        originalBtPort = btPort
        originalAutoSyncTracker = autoSyncTracker
        originalTrackerSource = trackerSource
        originalUserAgent = userAgent
        originalTrackerListText = trackerListText
        originalUpdateInterval = updateInterval
        originalCustomTrackerURLs = customTrackerURLs
    }
    
    private func resetEngine() {
        // Use the robust forceRepair flow from DownloadManager
        Task {
            await downloadManager.forceRepair()
        }
    }
    
    private func saveSettings() {
        let needsRestart = rpcPort != originalRpcPort || rpcSecret != originalRpcSecret
        
        print("PreferencesView: Saving settings - Needs restart: \(needsRestart)")
        let defaults = UserDefaults.standard
        defaults.set(rpcPort, forKey: "rpcPort")
        defaults.set(rpcSecret, forKey: "rpcSecret")
        defaults.set(enableUpnp, forKey: "enableUpnp")
        defaults.set(enableDht, forKey: "enableDht")
        defaults.set(enablePex, forKey: "enablePex")
        defaults.set(enableLpd, forKey: "enableLpd")
        defaults.set(btEncryptionMode, forKey: "btEncryptionMode")
        defaults.set(btPort, forKey: "btListenPort")
        defaults.set(autoSyncTracker, forKey: "autoSyncTracker")
        defaults.set(trackerSource, forKey: "trackerSource")
        defaults.set(userAgent, forKey: "userAgent")
        defaults.set(trackerListText, forKey: "btTrackers")
        defaults.set(updateInterval, forKey: "trackerUpdateInterval")
        defaults.set(customTrackerURLs, forKey: "customTrackerURLs")
        defaults.synchronize()
        
        if needsRestart {
            // Hot restart aria2 process WITHOUT restarting the app
            if let appDelegate = NSApplication.shared.delegate as? AppDelegate,
               let aria2 = appDelegate.aria2Process {
                print("PreferencesView: Requesting aria2 engine restart due to RPC configuration change...")
                aria2.restart(port: rpcPort, secret: rpcSecret)
            }
            
            // Reconnect to aria2 with new settings
            Task {
                await downloadManager.disconnect()
                try? await Task.sleep(for: .milliseconds(1000)) // Wait for aria2 to restart
                await downloadManager.connect()
            }
        } else {
            // Live update via RPC for all other settings
            print("PreferencesView: Applying settings live via RPC...")
            Task {
                await downloadManager.applyGlobalOptions()
            }
        }
        
        // Reload originals to clear dirty state
        loadOriginals()
    }
    
    private func generateRandomSecret() -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<16).map { _ in letters.randomElement()! })
    }
    
    // MARK: - Tracker Helpers
    
    private let availableTrackers = [
        "trackers_best.txt",
        "trackers_best_ip.txt",
        "trackers_all.txt",
        "trackers_all_ip.txt"
    ]
    
    private func isTrackerSelected(_ source: String) -> Bool {
        let selected = trackerSource.components(separatedBy: ",")
        return selected.contains(source)
    }
    
    private func toggleTrackerSource(_ source: String) {
        var selected = trackerSource.components(separatedBy: ",").filter { !$0.isEmpty }
        
        if selected.contains(source) {
            selected.removeAll { $0 == source }
        } else {
            selected.append(source)
        }
        
        trackerSource = selected.joined(separator: ",")
    }
    
    private func fetchTrackers() async {
        isFetchingTrackers = true
        defer { isFetchingTrackers = false }
        
        let sorted = await TrackerService.shared.fetchTrackers()
        
        // Format for readability in the text editor
        trackerListText = sorted.joined(separator: "\n\n")
    }
    private func openLogDirectory() {
        if let libraryUrl = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first {
            let logUrl = libraryUrl.appendingPathComponent("Logs/MotrixMac")
            try? FileManager.default.createDirectory(at: logUrl, withIntermediateDirectories: true)
            NSWorkspace.shared.open(logUrl)
        }
    }

    // MARK: - Developer Paths
    
    private var aria2ConfPath: String {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("MotrixMac/aria2.conf").path
    }
    
    private var sessionPath: String {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("MotrixMac/aria2.session").path
    }
    
    private var logFilePath: String {
        let libraryUrl = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
        return libraryUrl.appendingPathComponent("Logs/MotrixMac/app.log").path
    }
    
    private func resetSession() {
        Task {
            await downloadManager.disconnect()
            let path = sessionPath
            try? FileManager.default.removeItem(atPath: path)
            print("PreferencesView: Session cleared at \(path)")
            await downloadManager.connect()
        }
    }
    
    private func restoreInitialSettings() {
        let alert = NSAlert()
        alert.messageText = "恢复初始设置".localized(for: language)
        alert.informativeText = "此操作将重置所有偏好设置，但不会删除您的下载文件。确定要继续吗？".localized(for: language)
        alert.addButton(withTitle: "恢复".localized(for: language))
        alert.addButton(withTitle: "取消".localized(for: language))
        alert.alertStyle = .warning
        
        if alert.runModal() == .alertFirstButtonReturn {
            // Clear UserDefaults
            let domain = Bundle.main.bundleIdentifier!
            UserDefaults.standard.removePersistentDomain(forName: domain)
            UserDefaults.standard.synchronize()
            
            // Reload UI
            loadActualRuntimeValues()
            loadOriginals()
            
            // Restart engine
            resetEngine()
        }
    }
}

// MARK: - Components

struct TrackerSourceSelector: View {
    let sources: [String]
    @Binding var selection: [String]
    @Binding var customURLs: String
    let isFetching: Bool
    let fetchAction: () -> Void
    let language: String // Added for localization
    
    @State private var isPopoverPresented = false
    @State private var isHovering = false
    @State private var showingAddURLAlert = false
    @State private var newURLString = ""
    
    var body: some View {
        HStack(spacing: 8) {
            Button {
                isPopoverPresented.toggle()
            } label: {
                HStack {
                    if selection.isEmpty {
                        Text("选择内置 Tracker 源...".localized(for: language))
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 4) {
                                ForEach(selection, id: \.self) { item in
                                    let isCustom = isURL(item)
                                    Text(displayName(for: item))
                                        .font(.system(size: 11, weight: .medium))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(isCustom ? Color.orange.opacity(0.12) : Color.accentColor.opacity(0.12))
                                        .foregroundStyle(isCustom ? .orange : .accentColor)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                            }
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isPopoverPresented ? 90 : 0))
                }
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity)
                .frame(height: 34) // Perfect match
                .background {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isHovering ? Color.primary.opacity(0.05) : Color(nsColor: .controlBackgroundColor))
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                }
                .textSelection(.disabled)
            }
            .buttonStyle(.plain)
            .onHover { isHovering = $0 }
            .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("选择来源".localized(for: language))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.primary.opacity(0.8))
                        
                        Spacer()
                        
                        Button {
                            showingAddURLAlert = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.secondary)
                                .padding(8)
                                .background(Color.primary.opacity(0.06), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .help("添加自定义订阅 URL".localized(for: language))
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                    
                    Divider()
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 2) {
                            // Built-in Sources
                            ForEach(sources, id: \.self) { source in
                                sourceRow(name: source, isCustom: false)
                            }
                            
                            // Custom Sources
                            let customList = customURLs.components(separatedBy: .newlines).filter { !$0.isEmpty }
                            if !customList.isEmpty {
                                Divider().padding(.vertical, 4)
                                Text("自定义订阅".localized(for: language))
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.tertiary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                                
                                ForEach(customList, id: \.self) { url in
                                    sourceRow(name: url, isCustom: true)
                                }
                            }
                        }
                        .padding(6)
                    }
                    .frame(height: 220)
                    
                    Divider()
                    
                    HStack {
                        // Logic to determine "Select All" or "Clear All" state
                        let customList = customURLs.components(separatedBy: .newlines).filter { !$0.isEmpty }
                        let allSources = sources + customList
                        let isAllSelected = Set(selection).isSuperset(of: Set(allSources)) && !allSources.isEmpty
                        
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                if isAllSelected {
                                    selection.removeAll()
                                } else {
                                    // Select all unique sources
                                    selection = Array(Set(allSources)).sorted { s1, s2 in
                                        // Maintain relative order: built-in first, then custom
                                        let idx1 = allSources.firstIndex(of: s1) ?? Int.max
                                        let idx2 = allSources.firstIndex(of: s2) ?? Int.max
                                        return idx1 < idx2
                                    }
                                }
                            }
                        } label: {
                            Text(isAllSelected ? "清空已选".localized(for: language) : "全选".localized(for: language))
                                .font(.system(size: 13, weight: .medium))
                                .frame(width: 80, height: 28)
                                .background(Color.gray.opacity(0.15), in: Capsule())
                                .foregroundStyle(.primary.opacity(0.8))
                        }
                        .buttonStyle(SidebarButtonStyle())
                        
                        Spacer()
                        
                        Button {
                            isPopoverPresented = false
                        } label: {
                            Text("确定".localized(for: language))
                                .font(.system(size: 13, weight: .semibold))
                                .frame(width: 80, height: 28)
                                .background(Color.accentColor, in: Capsule())
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(SidebarButtonStyle())
                    }
                    .padding(12)
                    .background(Color.primary.opacity(0.02))
                }
                .frame(width: 280)
                .background(.ultraThinMaterial)
            }
            .sheet(isPresented: $showingAddURLAlert) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("添加自定义订阅 URL".localized(for: language))
                        .font(.headline)
                    
                    Text("请输入一个包含 Tracker 列表的完整 URL 地址。".localized(for: language))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    TextField("https://example.com/trackers.txt", text: $newURLString)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(nsColor: .controlBackgroundColor))
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                        }
                        .frame(maxWidth: .infinity)
                    
                    HStack {
                        Spacer()
                        Button("取消".localized(for: language)) {
                            showingAddURLAlert = false
                            newURLString = ""
                        }
                        .buttonStyle(.bordered)
                        
                        Button("添加".localized(for: language)) {
                            if !newURLString.isEmpty {
                                var current = customURLs.components(separatedBy: .newlines).filter { !$0.isEmpty }
                                if !current.contains(newURLString) {
                                    current.append(newURLString)
                                    customURLs = current.joined(separator: "\n")
                                    // [NEW] Auto-fetch immediately
                                    fetchAction()
                                }
                                newURLString = ""
                                showingAddURLAlert = false
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(newURLString.isEmpty)
                    }
                }
                .padding(20)
                .frame(width: 360)
            }
            
            Button {
                fetchAction()
            } label: {
                Image(systemName: "arrow.clockwise.circle.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.accentColor)
                    .font(.system(size: 24))
                    .rotationEffect(.degrees(isFetching ? 360 : 0))
                    .animation(isFetching ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isFetching)
            }
            .buttonStyle(.plain)
            .disabled(isFetching)
            .help("立即同步 Tracker 列表".localized(for: language))
        }
    }
    
    @ViewBuilder
    private func sourceRow(name: String, isCustom: Bool) -> some View {
        HStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                    if selection.contains(name) {
                        selection.removeAll { $0 == name }
                    } else {
                        selection.append(name)
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: selection.contains(name) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selection.contains(name) ? .blue : .secondary)
                        .font(.system(size: 16))
                    
                    Text(displayName(for: name))
                        .font(.system(size: 13, weight: selection.contains(name) ? .medium : .regular))
                        .foregroundStyle(selection.contains(name) ? .primary : .secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            if isCustom {
                Button {
                    withAnimation {
                        var current = customURLs.components(separatedBy: .newlines).filter { !$0.isEmpty }
                        current.removeAll { $0 == name }
                        customURLs = current.joined(separator: "\n")
                        selection.removeAll { $0 == name }
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundStyle(.red.opacity(0.7))
                        .padding(8)
                        .background(.red.opacity(0.1), in: Circle())
                }
                .buttonStyle(.plain)
                .padding(.trailing, 10)
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(selection.contains(name) ? Color.accentColor.opacity(0.08) : Color.primary.opacity(0.03))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
    }
    
    private func isURL(_ string: String) -> Bool {
        string.lowercased().hasPrefix("http")
    }
    
    private func displayName(for string: String) -> String {
        if isURL(string) {
            if let url = URL(string: string) {
                return url.lastPathComponent.isEmpty ? (url.host ?? string) : url.lastPathComponent
            }
            return string
        }
        
        switch string {
        case "trackers_best.txt": return "精选列表 (Best)".localized(for: language)
        case "trackers_best_ip.txt": return "精选列表 (Best IP)".localized(for: language)
        case "trackers_all.txt": return "全量列表 (All)".localized(for: language)
        case "trackers_all_ip.txt": return "全量列表 (All IP)".localized(for: language)
        default: return string
        }
    }
    
    private let availableTrackers = [
        "trackers_best.txt",
        "trackers_best_ip.txt",
        "trackers_all.txt",
        "trackers_all_ip.txt"
    ]
}

struct PathRow: View {
    let label: String
    let path: String
    let language: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            
            HStack(spacing: 8) {
                Text(path)
                    .font(.system(size: 11, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.primary.opacity(0.05))
                    }
                
                Button {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(path, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
                .help("复制路径".localized(for: language))
                
                Button {
                    let url = URL(fileURLWithPath: path).deletingLastPathComponent()
                    NSWorkspace.shared.open(url)
                } label: {
                    Image(systemName: "folder")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
                .help("在 Finder 中显示".localized(for: language))
            }
        }
    }
}

#Preview {
    PreferencesView()
}
// MARK: - Info Toggle Component

struct InfoToggle: View {
    let title: String
    let info: String
    @Binding var isOn: Bool
    @State private var showPopover = false

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 5) {
                Text(title)
                
                Button {
                    showPopover.toggle()
                } label: {
                    Image(systemName: "exclamationmark.circle")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showPopover) {
                    Text(info)
                        .padding(8)
                        .frame(width: 200)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                .textSelection(.disabled)
            }
        }
    }
}
