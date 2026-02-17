import SwiftUI
import UniformTypeIdentifiers

/// Sheet for adding new downloads with glass effect background
struct AddTaskSheet: View {
    @Environment(DownloadManager.self) private var downloadManager
    @Environment(\.dismiss) private var dismiss

    // Default directory stored in user preferences
    @AppStorage("defaultDownloadDirectory") private var defaultDirectory =
        FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!.path
    @AppStorage("language") private var language = "zh-CN"

    @State private var urlText = ""
    @State private var saveDirectory: URL = FileManager.default.urls(
        for: .downloadsDirectory, in: .userDomainMask
    ).first!
    @State private var setAsDefault = false
    @State private var showAdvancedOptions = false
    // Initialize with a safe default, will be updated in onAppear or via AppStorage
    @State private var connections = 16
    @AppStorage("defaultConnections") private var storedDefaultConnections = 16
    @State private var customFilename = ""
    @State private var customHeaders = ""
    @State private var isValidURL = true
    @State private var isProcessing = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("新建下载任务".localized(for: language))
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(24)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // URL Input
                    VStack(alignment: .leading, spacing: 8) {
                        Label("下载链接".localized(for: language), systemImage: "link")
                            .font(.headline)

                        TextField("输入 URL 或磁力链接...".localized(for: language), text: $urlText, axis: .vertical)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(.quaternary)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 10)
                                            .strokeBorder(isValidURL ? .clear : .red, lineWidth: 1)
                                    }
                            }
                            .lineLimit(3...6)
                            .onChange(of: urlText) { _, newValue in
                                validateURL(newValue)
                            }

                        if !isValidURL {
                            Text("请输入有效的 URL 或磁力链接".localized(for: language))
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }

                    // Save Location
                    VStack(alignment: .leading, spacing: 8) {
                        Label("保存到".localized(for: language), systemImage: "folder")
                            .font(.headline)

                        HStack {
                            Text(saveDirectory.path(percentEncoded: false))
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)

                            Spacer()

                            Button("选择...".localized(for: language)) {
                                selectDirectory()
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(12)
                        .background {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(.quaternary)
                        }

                        // Show "Set as default" only when directory differs from default
                        if saveDirectory.path != defaultDirectory {
                            Toggle("设为默认下载目录".localized(for: language), isOn: $setAsDefault)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Advanced Options Toggle
                    DisclosureGroup("高级选项".localized(for: language), isExpanded: $showAdvancedOptions) {
                        VStack(alignment: .leading, spacing: 16) {
                            // Connections
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("线程数".localized(for: language))
                                    Spacer()
                                    Text("\(connections)")
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                }
                                .font(.subheadline)

                                Slider(
                                    value: .init(
                                        get: { Double(connections) },
                                        set: { connections = Int($0) }
                                    ), in: 1...128)
                            }

                            // Custom Filename
                            VStack(alignment: .leading, spacing: 8) {
                                Text("自定义文件名".localized(for: language))
                                    .font(.subheadline)

                                TextField("留空使用原始文件名".localized(for: language), text: $customFilename)
                                    .textFieldStyle(.plain)
                                    .padding(10)
                                    .background {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(.quaternary)
                                    }
                            }

                            // Custom Headers
                            VStack(alignment: .leading, spacing: 8) {
                                Text("自定义请求头".localized(for: language))
                                    .font(.subheadline)

                                TextEditor(text: $customHeaders)
                                    .font(.body.monospaced())
                                    .scrollContentBackground(.hidden)
                                    .padding(8)
                                    .frame(height: 80)
                                    .background {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(.quaternary)
                                    }

                                Text("格式：Header-Name: Value （每行一个）".localized(for: language))
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.top, 16)
                    }
                    .font(.headline)
                }
                .padding(24)
            }

            Divider()

            // Footer buttons
            HStack(spacing: 12) {
                Button {
                    dismiss()
                } label: {
                    Text("取消".localized(for: language))
                        .font(.system(size: 13, weight: .medium))
                        .frame(width: 80, height: 28)
                        .background(Color.gray.opacity(0.15), in: Capsule())
                        .foregroundStyle(.primary.opacity(0.8))
                }
                .buttonStyle(.plain)
                .buttonStyle(SidebarButtonStyle())
                .keyboardShortcut(.escape, modifiers: [])

                Spacer()

                Button {
                    addDownload()
                } label: {
                    HStack(spacing: 8) {
                        if isProcessing {
                            ProgressView()
                                .controlSize(.small)
                                .colorInvert()
                        } else {
                            Text("确定".localized(for: language))
                        }
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 80, height: 28)
                    .background(Color.accentColor, in: Capsule())
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .buttonStyle(SidebarButtonStyle())
                .disabled(urlText.isEmpty || !isValidURL || isProcessing)
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(24)
        }
        .frame(width: 500, height: 550)
        // Note: .glassEffect() will be available in macOS 26 SDK
        .background(.regularMaterial)
        .onAppear {
            // Check clipboard for URLs
            if let clipboardString = NSPasteboard.general.string(forType: .string),
                isValidDownloadURL(clipboardString)
            {
                urlText = clipboardString
            }

            // Sync current saveDirectory with user preference
            if !defaultDirectory.isEmpty {
                saveDirectory = URL(fileURLWithPath: defaultDirectory)
            }

            // Sync default connections from storage
            if storedDefaultConnections > 0 {
                connections = storedDefaultConnections
            }
        }
    }

    private func validateURL(_ url: String) {
        if url.isEmpty {
            isValidURL = true
            return
        }
        isValidURL = isValidDownloadURL(url)
    }

    private func isValidDownloadURL(_ url: String) -> Bool {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Reject empty strings
        if trimmed.isEmpty { return false }
        
        // Reject multi-line content (likely tracker list pasted from settings)
        if trimmed.contains("\n") { return false }
        
        // Reject tracker URLs (they end with /announce or /scrape)
        if trimmed.hasSuffix("/announce") || trimmed.hasSuffix("/scrape") { return false }
        
        let patterns = [
            "^https?://",
            "^ftp://",
            "^magnet:\\?",
            "^thunder://",
        ]

        for pattern in patterns {
            if trimmed.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }
        return false
    }

    private func selectDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true

        if panel.runModal() == .OK, let url = panel.url {
            saveDirectory = url
        }
    }

    private func addDownload() {
        isProcessing = true

        // Save as default if checkbox is checked
        if setAsDefault {
            defaultDirectory = saveDirectory.path
        }

        var options: [String: Any] = [
            "dir": saveDirectory.path(percentEncoded: false),
            "split": connections,
            "max-connection-per-server": connections,
        ]

        if !customFilename.isEmpty {
            options["out"] = customFilename
        }

        if !customHeaders.isEmpty {
            let headers = customHeaders.split(separator: "\n").map(String.init)
            options["header"] = headers
        }

        Task {
            do {
                try await downloadManager.addDownload(uri: urlText, options: options)
                await MainActor.run {
                    if UserDefaults.standard.bool(forKey: "autoJumpOnTaskCreated") {
                        downloadManager.currentCategory = .downloading
                    }
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    // Show error alert
                }
            }
        }
    }
}

/// Sheet for adding torrent downloads with file selection
struct AddTorrentSheet: View {
    @Environment(DownloadManager.self) private var downloadManager
    @Environment(\.dismiss) private var dismiss
    @AppStorage("language") private var language = "zh-CN"

    @State private var torrentURL: URL?
    @AppStorage("defaultConnections") private var defaultConnections = 16
    @State private var saveDirectory = FileManager.default.urls(
        for: .downloadsDirectory, in: .userDomainMask
    ).first!
    @State private var isDragging = false
    
    // File selection state
    @State private var parsedFiles: [TorrentFile] = []
    @State private var selectedFileIndices: Set<Int> = []
    @State private var torrentName: String = ""
    @State private var showFileSelection = false
    @State private var showAdvancedOptions = false
    
    // Advanced options state
    @State private var customUserAgent = ""
    @State private var customReferer = ""
    @State private var customCookie = ""
    @State private var customProxy = ""
    @AppStorage("autoJumpOnTaskCreated") private var autoJumpOnTaskCreated = true
    
    // Quick filter categories
    enum FileFilter: String, CaseIterable {
        case all = "全部"
        case video = "视频"
        case audio = "音频"
        case image = "图片"
    }
    @State private var currentFilter: FileFilter = .all
    @State private var showNoFileSelectedAlert = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .center) { // Fix: specific alignment
                Text("添加 Torrent 任务".localized(for: language))
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(24)

            Divider()

            // Content Container - ScrollView ensures header/footer stay visible
            ScrollView {
                VStack(spacing: 24) {
                    if showFileSelection {
                        // File selection mode
                        VStack(alignment: .leading, spacing: 12) {
                            // Torrent name header
                            HStack {
                                Image(systemName: "doc.fill")
                                    .foregroundStyle(Color.accentColor)
                                Text(torrentName)
                                    .font(.headline)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                                Button {
                                    showFileSelection = false
                                    torrentURL = nil
                                    parsedFiles = []
                                    selectedFileIndices = []
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            
                            HStack(spacing: 8) {
                                ForEach(FileFilter.allCases, id: \.self) { filter in
                                    Button {
                                        currentFilter = filter
                                        if filter == .all {
                                            if selectedFileIndices.count == parsedFiles.count {
                                                selectedFileIndices = []
                                            } else {
                                                selectedFileIndices = Set(parsedFiles.map { $0.index })
                                            }
                                        }
                                    } label: {
                                        // For "全部" button, show blue only when all files are selected
                                        let isActive = filter == .all 
                                            ? (currentFilter == filter && selectedFileIndices.count == parsedFiles.count)
                                            : (currentFilter == filter)
                                        Text(filter.rawValue.localized(for: language))
                                            .font(.caption)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 4)
                                            .background(isActive ? Color.accentColor : Color.secondary.opacity(0.2), in: Capsule())
                                            .foregroundStyle(isActive ? .white : .primary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                Spacer()
                                
                                HStack(spacing: 12) {
                                    // Removed redundant Select All button

                                    
                                    Text(String(format: "已选 %d 个文件，共 %@".localized(for: language), selectedFilesCount, ByteCountFormatter.string(fromByteCount: selectedFilesSize, countStyle: .file)))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            // File list
                            LazyVStack(spacing: 0) {
                                ForEach(filteredFiles) { file in
                                    HStack(spacing: 12) {
                                        Image(systemName: selectedFileIndices.contains(file.index) ? "checkmark.square.fill" : "square")
                                            .foregroundStyle(selectedFileIndices.contains(file.index) ? Color.accentColor : .secondary)
                                            .onTapGesture {
                                                if selectedFileIndices.contains(file.index) {
                                                    selectedFileIndices.remove(file.index)
                                                } else {
                                                    selectedFileIndices.insert(file.index)
                                                }
                                            }
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(file.name)
                                                .font(.subheadline)
                                                .lineLimit(1)
                                                .truncationMode(.middle)
                                            Text(file.formattedSize)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                    }
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 8)
                                    .background(Color.primary.opacity(0.001))
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        if selectedFileIndices.contains(file.index) {
                                            selectedFileIndices.remove(file.index)
                                        } else {
                                            selectedFileIndices.insert(file.index)
                                        }
                                    }
                                    
                                    if file.id != filteredFiles.last?.id {
                                        Divider().padding(.leading, 32)
                                    }
                                }
                            }
                            .padding(8)
                            .background(Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
                        }
                    } else {
                        // Drop zone (original)
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(
                                    isDragging ? Color.accentColor : Color.secondary.opacity(0.3),
                                    style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                                )
                                .background {
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(isDragging ? Color.accentColor.opacity(0.1) : Color.clear)
                                }

                            VStack(spacing: 16) {
                                if let url = torrentURL {
                                    Image(systemName: "doc.fill")
                                        .font(.system(size: 48))
                                        .foregroundStyle(Color.accentColor)

                                    Text(url.lastPathComponent)
                                        .font(.headline)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(3)
                                        .padding(.horizontal, 16)
                                        .fixedSize(horizontal: false, vertical: true)

                                    Button("选择其他文件".localized(for: language)) {
                                        selectTorrentFile()
                                    }
                                    .buttonStyle(.bordered)
                                } else {
                                    Image(systemName: "arrow.down.doc")
                                        .font(.system(size: 48))
                                        .foregroundStyle(.secondary)

                                    Text("拖放种子文件到此处".localized(for: language))
                                        .font(.headline)
                                        .foregroundStyle(.secondary)

                                    Text("或".localized(for: language))
                                        .foregroundStyle(.tertiary)

                                    Button("选择文件...".localized(for: language)) {
                                        selectTorrentFile()
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                            }

                        .frame(minHeight: 220)
                        .onDrop(of: [.fileURL], isTargeted: $isDragging) { providers in
                            handleDrop(providers: providers)
                        }
                    }

                    // Save location
                    VStack(alignment: .leading, spacing: 8) {
                        Label("保存到".localized(for: language), systemImage: "folder")
                            .font(.headline)

                        HStack {
                            Text(saveDirectory.path(percentEncoded: false))
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)

                            Spacer()

                            Button("选择...".localized(for: language)) {
                                selectDirectory()
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(12)
                        .background {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(.quaternary)
                        }
                    }
                    
                    // Advanced Options
                    DisclosureGroup("高级选项".localized(for: language), isExpanded: $showAdvancedOptions) {
                        VStack(alignment: .leading, spacing: 16) {
                            // Thread count
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("线程数".localized(for: language))
                                    Spacer()
                                    Text("\(defaultConnections)")
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                }
                                .font(.subheadline)
                                
                                Slider(
                                    value: .init(
                                        get: { Double(defaultConnections) },
                                        set: { defaultConnections = Int($0) }
                                    ), in: 1...128)
                            }
                            
                            // User-Agent
                            VStack(alignment: .leading, spacing: 4) {
                                Text("用户代理".localized(for: language))
                                    .font(.subheadline)
                                TextField("留空使用默认值".localized(for: language), text: $customUserAgent)
                                    .textFieldStyle(.plain)
                                    .padding(10)
                                    .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary))
                            }
                            
                            // Referer
                            VStack(alignment: .leading, spacing: 4) {
                                Text("来源".localized(for: language))
                                    .font(.subheadline)
                                TextField("留空使用默认值".localized(for: language), text: $customReferer)
                                    .textFieldStyle(.plain)
                                    .padding(10)
                                    .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary))
                            }
                            
                            // Cookie
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Cookie".localized(for: language))
                                    .font(.subheadline)
                                TextField("留空使用默认值".localized(for: language), text: $customCookie)
                                    .textFieldStyle(.plain)
                                    .padding(10)
                                    .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary))
                            }
                            
                            // Proxy
                            VStack(alignment: .leading, spacing: 4) {
                                Text("代理".localized(for: language))
                                    .font(.subheadline)
                                TextField("[http://][USER:PASSWORD@]HOST[:PORT]", text: $customProxy)
                                    .textFieldStyle(.plain)
                                    .padding(10)
                                    .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary))
                            }
                            
                            // Auto jump toggle
                            Toggle("添加后跳转到下载页面".localized(for: language), isOn: $autoJumpOnTaskCreated)
                                .font(.subheadline)
                        }
                        .padding(.top, 12)
                    }
                    .font(.headline)
                }
                .padding(24)
            }

            Divider()

            // Footer
            HStack(spacing: 12) {
                Button {
                    dismiss()
                } label: {
                    Text("取消".localized(for: language))
                        .font(.system(size: 13, weight: .medium))
                        .frame(width: 80, height: 28)
                        .background(Color.gray.opacity(0.15), in: Capsule())
                        .foregroundStyle(.primary.opacity(0.8))
                }
                .buttonStyle(.plain)
                .buttonStyle(SidebarButtonStyle())
                .keyboardShortcut(.escape, modifiers: [])

                Spacer()

                Button {
                    addTorrent()
                } label: {
                    Text("确定".localized(for: language))
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 80, height: 28)
                        .background(Color.accentColor, in: Capsule())
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .buttonStyle(SidebarButtonStyle())
                .disabled(torrentURL == nil)
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(24)
        }
        .frame(width: 500, height: showFileSelection ? (showAdvancedOptions ? 560 : 500) : 440)
        .background(.regularMaterial)
        .onAppear {
            // Check if opened from Finder double-click
            if let pendingURL = downloadManager.pendingTorrentURL {
                torrentURL = pendingURL
                downloadManager.pendingTorrentURL = nil
                parseTorrent(url: pendingURL)
            }

            // Sync default save directory
            let defaultDir = UserDefaults.standard.string(forKey: "defaultDownloadDirectory") ?? ""
            if !defaultDir.isEmpty {
                saveDirectory = URL(fileURLWithPath: defaultDir)
            }
        }
        .onDisappear {
            // Clear pending URL if user dismisses without adding (only if still set)
            if downloadManager.pendingTorrentURL != nil {
                downloadManager.pendingTorrentURL = nil
            }
        }

        .alert("未选择文件".localized(for: language), isPresented: $showNoFileSelectedAlert) {
            Button("确定".localized(for: language), role: .cancel) { }
        } message: {
            Text("请至少选择一个文件以开始下载。".localized(for: language))
        }
    }

    private func selectTorrentFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.init(filenameExtension: "torrent")!]

        if panel.runModal() == .OK, let url = panel.url {
            torrentURL = url
            parseTorrent(url: url)
        }
    }

    private func selectDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true

        if panel.runModal() == .OK, let url = panel.url {
            saveDirectory = url
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, error in
            guard let data = item as? Data,
                let url = URL(dataRepresentation: data, relativeTo: nil),
                url.pathExtension.lowercased() == "torrent"
            else { return }

            DispatchQueue.main.async {
                torrentURL = url
                parseTorrent(url: url)
            }
        }
        return true
    }

    private func addTorrent() {
        guard let url = torrentURL else { return }

                if !parsedFiles.isEmpty && selectedFileIndices.isEmpty {
                    showNoFileSelectedAlert = true
                    return
                }
                
                Task {
                    do {
                        let data = try Data(contentsOf: url)
                        let base64 = data.base64EncodedString()
                        
                        var options: [String: Any] = [
                            "dir": saveDirectory.path(percentEncoded: false)
                        ]
                        
                        // File selection: if not all files selected, pass select-file option
                        if !selectedFileIndices.isEmpty && selectedFileIndices.count < parsedFiles.count {
                            // aria2 uses 1-indexed file indices
                            let selectedIndices = selectedFileIndices.sorted().map { $0 + 1 }.map(String.init).joined(separator: ",")
                            options["select-file"] = selectedIndices
                        }
                        
                        // Explicitly pass global connection settings
                        if defaultConnections > 0 {
                            options["split"] = defaultConnections
                            options["max-connection-per-server"] = defaultConnections
                        }
                        
                        // Advanced options
                        if !customUserAgent.isEmpty {
                            options["user-agent"] = customUserAgent
                        }
                        if !customReferer.isEmpty {
                            options["referer"] = customReferer
                        }
                        if !customCookie.isEmpty {
                            options["header"] = "Cookie: \(customCookie)"
                        }
                        if !customProxy.isEmpty {
                            options["all-proxy"] = customProxy
                        }
                        
                        try await downloadManager.addTorrent(
                            base64: base64,
                            options: options
                        )
                        await MainActor.run {
                            if autoJumpOnTaskCreated {
                                downloadManager.currentCategory = .downloading
                            }
                            dismiss()
                        }
                    } catch {
                        // Handle error
                    }
                }
            }

    
    private func parseTorrent(url: URL) {
        print("Parsing torrent from: \(url.path)")
        
        // Handle security scope for dropped files
        let gotAccess = url.startAccessingSecurityScopedResource()
        defer { if gotAccess { url.stopAccessingSecurityScopedResource() } }
        
        do {
            let data = try Data(contentsOf: url)
            print("Read \(data.count) bytes")
            
            // Parse bencode to extract file info
            guard let decoded = try BencodeDecoder.decode(data) else {
                print("Bencode decoding returned nil")
                return
            }
            
            guard let dict = decoded as? [String: Any] else {
                print("Root is not a dictionary")
                return
            }
            
            guard let info = dict["info"] as? [String: Any] else {
                print("Missing 'info' dictionary")
                return
            }
            
            torrentName = (info["name"] as? String) ?? url.deletingPathExtension().lastPathComponent
            
            var files: [TorrentFile] = []
            
            if let fileList = info["files"] as? [[String: Any]] {
                // Multi-file torrent
                print("Multi-file torrent found")
                for (index, file) in fileList.enumerated() {
                    let pathComponents = (file["path"] as? [String]) ?? []
                    let name = pathComponents.joined(separator: "/")
                    let length = (file["length"] as? Int64) ?? 0
                    files.append(TorrentFile(index: index, name: name, length: length))
                }
            } else if let length = info["length"] as? Int64 {
                // Single-file torrent
                print("Single-file torrent found")
                files.append(TorrentFile(index: 0, name: torrentName, length: length))
            } else {
                print("No files or single length found in info")
            }
            
            parsedFiles = files
            selectedFileIndices = Set(files.map { $0.index })
            showFileSelection = !files.isEmpty // Show for all torrents including single-file
            print("Parsing successful. Files: \(files.count)")
            
        } catch {
            print("Parse torrent failed: \(error)")
        }
    }
    
    private var filteredFiles: [TorrentFile] {
        switch currentFilter {
        case .all: return parsedFiles
        case .video: return parsedFiles.filter { $0.isVideo }
        case .audio: return parsedFiles.filter { $0.isAudio }
        case .image: return parsedFiles.filter { $0.isImage }
        }
    }
    
    private var selectedFilesSize: Int64 {
        parsedFiles.filter { selectedFileIndices.contains($0.index) }.reduce(0) { $0 + $1.length }
    }
    
    private var selectedFilesCount: Int {
        selectedFileIndices.count
    }
}

// MARK: - TorrentFile Model

struct TorrentFile: Identifiable {
    let index: Int
    let name: String
    let length: Int64
    
    var id: Int { index }
    
    var fileExtension: String {
        (name as NSString).pathExtension.lowercased()
    }
    
    var isVideo: Bool {
        ["mp4", "mkv", "avi", "mov", "wmv", "flv", "webm", "m4v", "ts", "rmvb"].contains(fileExtension)
    }
    
    var isAudio: Bool {
        ["mp3", "flac", "wav", "aac", "ogg", "m4a", "wma", "ape"].contains(fileExtension)
    }
    
    var isImage: Bool {
        ["jpg", "jpeg", "png", "gif", "bmp", "webp", "tiff", "heic"].contains(fileExtension)
    }
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: length, countStyle: .file)
    }
}

// MARK: - Bencode Decoder

enum BencodeDecoder {
    static func decode(_ data: Data) throws -> Any? {
        var index = data.startIndex
        return try decodeValue(data, index: &index)
    }
    
    private static func decodeValue(_ data: Data, index: inout Data.Index) throws -> Any? {
        guard index < data.endIndex else { return nil }
        
        let byte = data[index]
        
        switch byte {
        case UInt8(ascii: "i"):
            return try decodeInteger(data, index: &index)
        case UInt8(ascii: "l"):
            return try decodeList(data, index: &index)
        case UInt8(ascii: "d"):
            return try decodeDictionary(data, index: &index)
        case UInt8(ascii: "0")...UInt8(ascii: "9"):
            return try decodeString(data, index: &index)
        default:
            return nil
        }
    }
    
    private static func decodeInteger(_ data: Data, index: inout Data.Index) throws -> Int64 {
        index = data.index(after: index) // skip 'i'
        let start = index
        while index < data.endIndex && data[index] != UInt8(ascii: "e") {
            index = data.index(after: index)
        }
        let numberString = String(data: data[start..<index], encoding: .utf8) ?? "0"
        index = data.index(after: index) // skip 'e'
        return Int64(numberString) ?? 0
    }
    
    private static func decodeString(_ data: Data, index: inout Data.Index) throws -> Any {
        let start = index
        while index < data.endIndex && data[index] != UInt8(ascii: ":") {
            index = data.index(after: index)
        }
        let lengthString = String(data: data[start..<index], encoding: .utf8) ?? "0"
        let length = Int(lengthString) ?? 0
        index = data.index(after: index) // skip ':'
        let endIndex = data.index(index, offsetBy: length, limitedBy: data.endIndex) ?? data.endIndex
        let stringData = data[index..<endIndex]
        index = endIndex
        
        // Try to decode as UTF-8 string, otherwise return raw data
        if let str = String(data: stringData, encoding: .utf8) {
            return str
        }
        return stringData
    }
    
    private static func decodeList(_ data: Data, index: inout Data.Index) throws -> [Any] {
        index = data.index(after: index) // skip 'l'
        var list: [Any] = []
        while index < data.endIndex && data[index] != UInt8(ascii: "e") {
            if let value = try decodeValue(data, index: &index) {
                list.append(value)
            }
        }
        index = data.index(after: index) // skip 'e'
        return list
    }
    
    private static func decodeDictionary(_ data: Data, index: inout Data.Index) throws -> [String: Any] {
        index = data.index(after: index) // skip 'd'
        var dict: [String: Any] = [:]
        while index < data.endIndex && data[index] != UInt8(ascii: "e") {
            if let key = try decodeValue(data, index: &index) as? String,
               let value = try decodeValue(data, index: &index) {
                dict[key] = value
            }
        }
        index = data.index(after: index) // skip 'e'
        return dict
    }
}

#Preview("添加下载") {
    AddTaskSheet()
        .environment(DownloadManager.shared)
}

#Preview("添加种子") {
    AddTorrentSheet()
        .environment(DownloadManager.shared)
}
