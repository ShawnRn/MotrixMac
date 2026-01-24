import Observation
import ServiceManagement
import SwiftUI

/// Preferences view integrated with macOS Settings scene
struct PreferencesView: View {
    @AppStorage("theme") private var theme = "auto"
    
    var body: some View {
        TabView {
            GeneralPreferencesTab()
                .tabItem {
                    Label("通用", systemImage: "gear")
                }

            DownloadsPreferencesTab()
                .tabItem {
                    Label("下载", systemImage: "arrow.down.circle")
                }

            NetworkPreferencesTab()
                .tabItem {
                    Label("网络", systemImage: "network")
                }

            AdvancedPreferencesTab()
                .tabItem {
                    Label("高级", systemImage: "gearshape.2")
                }
        }
        .tabViewStyle(.automatic)
        .frame(width: 500, height: 400)
    }
}

/// Embedded preferences view for display in main content area
struct EmbeddedPreferencesView: View {
    @AppStorage("theme") private var theme = "auto"
    
    var body: some View {
        TabView {
            GeneralPreferencesTab()
                .tabItem {
                    Label("通用", systemImage: "gear")
                }

            DownloadsPreferencesTab()
                .tabItem {
                    Label("下载", systemImage: "arrow.down.circle")
                }

            NetworkPreferencesTab()
                .tabItem {
                    Label("网络", systemImage: "network")
                }

            AdvancedPreferencesTab()
                .tabItem {
                    Label("高级", systemImage: "gearshape.2")
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - General Tab

struct GeneralPreferencesTab: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("silentStart") private var silentStart = false
    @AppStorage("theme") private var theme = "auto"
    @AppStorage("language") private var language = "zh-CN"
    @AppStorage("showInDock") private var showInDock = true
    @AppStorage("showSpeedInMenuBar") private var showSpeedInMenuBar = false

    var body: some View {
        Form {
            Section {
                Toggle("开机启动", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        updateLaunchAtLogin(enabled: newValue)
                    }

                Toggle("静默启动", isOn: $silentStart)
                    .disabled(!launchAtLogin)
                    .foregroundColor(launchAtLogin ? .primary : .secondary)
                    .help("启用后，开机启动时不会自动显示主窗口")

                Toggle("在 Dock 中显示", isOn: $showInDock)

                Toggle("在菜单栏显示速度", isOn: $showSpeedInMenuBar)
            }

            Section {
                Picker("外观", selection: $theme) {
                    Text("跟随系统").tag("auto")
                    Text("浅色").tag("light")
                    Text("深色").tag("dark")
                }

                Picker("语言", selection: $language) {
                    Text("English").tag("en")
                    Text("简体中文").tag("zh-CN")
                    Text("繁體中文").tag("zh-TW")
                    Text("日本語").tag("ja")
                    Text("한국어").tag("ko")
                }
            }
        }
        .formStyle(.grouped)
        .padding()
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
    @AppStorage("defaultConnections") private var defaultConnections = 16
    @AppStorage("autoRenameFiles") private var autoRename = true
    @AppStorage("notifyOnComplete") private var notifyOnComplete = true

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
            } header: {
                Text("保存位置")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Section {
                Stepper("最大同时下载数：\(maxConcurrent)", value: $maxConcurrent, in: 1...10)

                // Slider without step parameter to avoid tick marks
                Slider(
                    value: .init(
                        get: { Double(defaultConnections) },
                        set: { defaultConnections = Int($0) }
                    ), in: 1...128,
                    onEditingChanged: { editing in
                        if !editing {
                            // Fix: Explicitly force sync to UserDefaults to ensure EngineProcess sees the update immediately
                            print("PreferencesView: Persistence fix - Writing defaultConnections = \(defaultConnections)")
                            UserDefaults.standard.set(defaultConnections, forKey: "defaultConnections")
                            UserDefaults.standard.synchronize()
                            
                            // Dynamic update: Apply settings immediately without restart
                            Task { 
                                await DownloadManager.shared.applyGlobalOptions()
                                // Force restart to update configuration file for future raw RPC calls
                                await DownloadManager.shared.restartEngine()
                            }
                        }
                    }
                ) {
                    Text("线程数：\(defaultConnections)")
                }
            } header: {
                Text("性能")
            }

            Section {
                Toggle("自动重命名已存在文件", isOn: $autoRename)
                Toggle("下载完成时通知", isOn: $notifyOnComplete)
            } header: {
                Text("行为")
            }
        }
        .formStyle(.grouped)
        .padding()
        .onChange(of: maxConcurrent) { _, _ in
            Task { await DownloadManager.shared.applyGlobalOptions() }
        }
    }

    private func selectDirectory() {
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

    var body: some View {
        Form {
            Section {
                Toggle("启用代理", isOn: $proxyEnabled)

                if proxyEnabled {
                    TextField("主机", text: $proxyHost)
                        .textFieldStyle(.roundedBorder)

                    TextField("端口", text: $proxyPort)
                        .textFieldStyle(.roundedBorder)

                    TextField("用户名 （可选）", text: $proxyUsername)
                        .textFieldStyle(.roundedBorder)

                    SecureField("密码 （可选）", text: $proxyPassword)
                        .textFieldStyle(.roundedBorder)
                }
            } header: {
                Text("代理")
            }

            Section {
                HStack {
                    Text("最大下载速度")
                    Spacer()
                    TextField("", value: $maxDownloadSpeed, format: .number)
                        .frame(width: 80)
                        .textFieldStyle(.roundedBorder)
                    Text("KB/s")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("最大上传速度")
                    Spacer()
                    TextField("", value: $maxUploadSpeed, format: .number)
                        .frame(width: 80)
                        .textFieldStyle(.roundedBorder)
                    Text("KB/s")
                        .foregroundStyle(.secondary)
                }

                Text("设为 0 表示无限制")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } header: {
                Text("速度限制")
            }
        }
        .formStyle(.grouped)
        .padding()
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
    @State private var btPort: Int = 6881
    @State private var autoSyncTracker: Bool = true
    @State private var trackerSource: String = "trackers_best.txt"
    @State private var userAgent: String = "MotrixMac/2.0"
    @State private var updateInterval: String = "daily"
    
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
    @State private var originalBtPort: Int = 6881
    @State private var originalAutoSyncTracker: Bool = true
    @State private var originalTrackerSource: String = "trackers_best.txt"
    @State private var originalUserAgent: String = "MotrixMac/2.0"
    @State private var originalTrackerListText: String = ""
    @State private var originalUpdateInterval: String = "daily"

    // Fetching state
    @State private var isFetchingTrackers = false

    init() {
        let defaults = UserDefaults.standard
        
        let secret = defaults.string(forKey: "rpcSecret") ?? ""
        let port = defaults.integer(forKey: "rpcPort") == 0 ? 12800 : defaults.integer(forKey: "rpcPort")
        
        _rpcPort = State(initialValue: port)
        _rpcSecret = State(initialValue: secret)
        _enableUpnp = State(initialValue: defaults.object(forKey: "enableUpnp") == nil ? true : defaults.bool(forKey: "enableUpnp"))
        _enableDht = State(initialValue: defaults.object(forKey: "enableDht") == nil ? true : defaults.bool(forKey: "enableDht"))
        _btPort = State(initialValue: defaults.integer(forKey: "btListenPort") == 0 ? 6881 : defaults.integer(forKey: "btListenPort"))
        _autoSyncTracker = State(initialValue: defaults.object(forKey: "autoSyncTracker") == nil ? true : defaults.bool(forKey: "autoSyncTracker"))
        _trackerSource = State(initialValue: defaults.string(forKey: "trackerSource") ?? "trackers_best.txt")
        _userAgent = State(initialValue: defaults.string(forKey: "userAgent") ?? "MotrixMac/2.0")
        _trackerListText = State(initialValue: defaults.string(forKey: "btTrackers") ?? "")
        _updateInterval = State(initialValue: defaults.string(forKey: "trackerUpdateInterval") ?? "daily")
    }

    var body: some View {
        Form {
            // Tracker Settings
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        // Custom Multi-select Dropdown
                        Menu {
                            ForEach(availableTrackers, id: \.self) { source in
                                Button {
                                    toggleTrackerSource(source)
                                } label: {
                                    HStack {
                                        Text(source)
                                        if isTrackerSelected(source) {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                if trackerSource.isEmpty {
                                    Text("选择 Tracker 源...")
                                        .foregroundStyle(.secondary)
                                } else {
                                    let selected = trackerSource.components(separatedBy: ",").filter { !$0.isEmpty }
                                    ForEach(selected, id: \.self) { item in
                                        Text(item)
                                            .font(.caption)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(.quaternary)
                                            .clipShape(RoundedRectangle(cornerRadius: 4))
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(5)
                            .frame(minHeight: 28) // Match standard input height
                            .background {
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                    .background(Color.clear) // Transparent center
                            }
                        }
                        .menuStyle(.borderlessButton)
                        .frame(maxWidth: .infinity) // Allow it to expand if needed, or keep fixed width
                        
                        Button {
                            Task {
                                await fetchTrackers()
                            }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .rotationEffect(.degrees(isFetchingTrackers ? 360 : 0))
                                .animation(isFetchingTrackers ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isFetchingTrackers)
                        }
                        .disabled(isFetchingTrackers)
                        .help("立即更新 Tracker 列表")
                    }
                    
                    TextEditor(text: $trackerListText)
                        .font(.system(.caption, design: .monospaced))
                        .frame(height: 80)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                    
                    Picker("更新频率", selection: $updateInterval) {
                        Text("每 12 小时").tag("12h")
                        Text("每天").tag("daily")
                        Text("每周").tag("weekly")
                        Text("每月").tag("monthly")
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Tracker 服务器")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // RPC Settings
            Section {
                HStack {
                    Text("RPC 监听端口")
                        .frame(width: 100, alignment: .leading)
                    
                    TextField("", value: $rpcPort, format: .number.grouping(.never))
                        .textFieldStyle(.plain)
                        .padding(6)
                        .background {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(nsColor: .controlBackgroundColor))
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        }
                }
                
                HStack {
                    Text("RPC 授权密钥")
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
                        .help(showSecret ? "隐藏" : "显示")
                        
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
                        .help("复制")
                        
                        Button {
                            rpcSecret = generateRandomSecret()
                        } label: {
                            Image(systemName: "dice")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("随机生成")
                    }
                    .padding(6)
                    .background {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(nsColor: .controlBackgroundColor))
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    }
                }

                Text("修改 RPC 设置后将自动热重启引擎生效")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                if let rpcError = downloadManager.lastRpcError {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("RPC 错误：\(rpcError == "Unauthorized" ? "授权失败 （密钥不匹配）" : rpcError)")
                                .fontWeight(.medium)
                            Text("当前系统可能存在一个旧的 aria2 进程正在使用此端口，且其密钥与当前设置不符。")
                                .font(.caption2)
                        }
                        
                        Spacer()
                        
                        Button("强制重置引擎") {
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
                            Text("引擎启动失败")
                                .fontWeight(.medium)
                            Text(engineError)
                                .font(.caption2)
                        }
                        
                        Spacer()
                        
                        Button("重试") {
                            resetEngine()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(10)
                    .background(Color.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            } header: {
                Text("RPC")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // BitTorrent Settings
            Section {
                Toggle("启用 UPnP/NAT-PMP", isOn: $enableUpnp)
                Toggle("启用 DHT", isOn: $enableDht)

                HStack {
                    Text("BT 监听端口")
                        .frame(width: 100, alignment: .leading)
                    
                    TextField("", value: $btPort, format: .number.grouping(.never))
                        .textFieldStyle(.plain)
                        .padding(6)
                        .background {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(nsColor: .controlBackgroundColor))
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        }
                }
            } header: {
                Text("BitTorrent")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // HTTP Settings
            Section {
                TextField("User-Agent", text: $userAgent)
                    .textFieldStyle(.roundedBorder)
            } header: {
                Text("HTTP")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Log Settings
            Section {
                 Picker("日志级别", selection: Binding(
                    get: { LogLevel(rawValue: UserDefaults.standard.integer(forKey: "LogLevel")) ?? .info },
                    set: { Logger.shared.level = $0 }
                )) {
                    ForEach(LogLevel.allCases) { level in
                        Text(level.description).tag(level)
                    }
                }
                .pickerStyle(.menu)
                .help("设置应用程序日志的详细程度")
                
                Button("打开日志目录") {
                    openLogDirectory()
                }
            } header: {
                Text("日志")
            }

            // Reset
            Section {
                HStack {
                    Button("重置所有设置") {
                        // TODO: Reset logic
                    }
                    .foregroundStyle(.red)
                    
                    Spacer()
                    
                    Button("清除下载历史") {
                        Task { await downloadManager.clearAllStopped() }
                    }
                }
            } header: {
                Text("重置")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            loadActualRuntimeValues()
            loadOriginals()
        }
        .onChange(of: isDirty) { _, newValue in
            settingsAreDirty = newValue
        }
        .onReceive(NotificationCenter.default.publisher(for: .saveSettings)) { _ in
            saveAndRestart()
        }
    }
    
    private func loadActualRuntimeValues() {
        let defaults = UserDefaults.standard
        // Always load the PREFERRED port for the UI field
        rpcPort = defaults.integer(forKey: "rpcPort")
        if rpcPort == 0 { rpcPort = 12800 }
        
        // Secret usually stays stable
        rpcSecret = defaults.string(forKey: "rpcSecret") ?? ""
    }
    
    private var isDirty: Bool {
        rpcPort != originalRpcPort ||
        rpcSecret != originalRpcSecret ||
        enableUpnp != originalEnableUpnp ||
        enableDht != originalEnableDht ||
        btPort != originalBtPort ||
        autoSyncTracker != originalAutoSyncTracker ||
        trackerSource != originalTrackerSource ||
        userAgent != originalUserAgent ||
        trackerListText != originalTrackerListText ||
        updateInterval != originalUpdateInterval
    }
    
    private func loadOriginals() {
        originalRpcPort = rpcPort
        originalRpcSecret = rpcSecret
        originalEnableUpnp = enableUpnp
        originalEnableDht = enableDht
        originalBtPort = btPort
        originalAutoSyncTracker = autoSyncTracker
        originalTrackerSource = trackerSource
        originalUserAgent = userAgent
        originalTrackerListText = trackerListText
        originalUpdateInterval = updateInterval
    }
    
    private func resetEngine() {
        if let appDelegate = NSApplication.shared.delegate as? AppDelegate,
           let aria2 = appDelegate.aria2Process {
            aria2.stop()
            // Wait slightly more to ensure socket is freed
            Thread.sleep(forTimeInterval: 0.8)
            aria2.start()
            
            Task {
                await downloadManager.disconnect()
                try? await Task.sleep(for: .milliseconds(2000))
                await downloadManager.connect()
            }
        }
    }
    
    private func saveAndRestart() {
        print("PreferencesView: Saving settings - Port: \(rpcPort), Secret: \(rpcSecret)")
        let defaults = UserDefaults.standard
        defaults.set(rpcPort, forKey: "rpcPort")
        defaults.set(rpcSecret, forKey: "rpcSecret")
        // ... rest of the code ...
        defaults.set(enableUpnp, forKey: "enableUpnp")
        defaults.set(enableDht, forKey: "enableDht")
        defaults.set(btPort, forKey: "btListenPort")
        defaults.set(autoSyncTracker, forKey: "autoSyncTracker")
        defaults.set(trackerSource, forKey: "trackerSource")
        defaults.set(userAgent, forKey: "userAgent")
        defaults.set(trackerListText, forKey: "btTrackers")
        defaults.set(updateInterval, forKey: "trackerUpdateInterval")
        defaults.synchronize()
        
        // Hot restart aria2 process WITHOUT restarting the app
        if let appDelegate = NSApplication.shared.delegate as? AppDelegate,
           let aria2 = appDelegate.aria2Process {
            // Restart with new settings
            print("PreferencesView: Requesting aria2 engine restart...")
            aria2.restart(port: rpcPort, secret: rpcSecret)
        }
        
        // Reload originals
        loadOriginals()
        
        // Reconnect to aria2 with new settings
        Task {
            await downloadManager.disconnect()
            try? await Task.sleep(for: .milliseconds(1000)) // Wait for aria2 to restart
            await downloadManager.connect()
        }
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
        
        let sources = trackerSource.components(separatedBy: ",").filter { !$0.isEmpty }
        guard !sources.isEmpty else { return }
        
        var allTrackers: Set<String> = []
        
        for source in sources {
            let urlString = "https://raw.githubusercontent.com/ngosang/trackerslist/master/\(source)"
            guard let url = URL(string: urlString) else { continue }
            
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let content = String(data: data, encoding: .utf8) {
                    let lines = content.components(separatedBy: .newlines)
                    for line in lines {
                        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty && !trimmed.hasPrefix("#") {
                            allTrackers.insert(trimmed)
                        }
                    }
                }
            } catch {
                print("Failed to fetch trackers from \(source): \(error)")
            }
        }
        
        // Sort and update text
        let sorted = allTrackers.sorted()
        // Format: one per line? or comma separated for aria2? UI usually shows one per line or similar.
        // aria2 config expects comma-separated. But user might want readability in text box.
        // Let's assume text box is line-separated for editing, and we join them when saving if needed (or keep as is if creating conf handles formatting)
        // Motrix usually formats them with empty lines.
        // Let's format them line by line.
        trackerListText = sorted.joined(separator: "\n\n")
    }
    private func openLogDirectory() {
        if let libraryUrl = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first {
            let logUrl = libraryUrl.appendingPathComponent("Logs/MotrixMac")
            try? FileManager.default.createDirectory(at: logUrl, withIntermediateDirectories: true)
            NSWorkspace.shared.open(logUrl)
        }
    }
}

#Preview {
    PreferencesView()
}
