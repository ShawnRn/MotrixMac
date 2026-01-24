import SwiftUI
import UniformTypeIdentifiers

/// Sheet for adding new downloads with glass effect background
struct AddTaskSheet: View {
    @Environment(DownloadManager.self) private var downloadManager
    @Environment(\.dismiss) private var dismiss

    // Default directory stored in user preferences
    @AppStorage("defaultDownloadDirectory") private var defaultDirectory =
        FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!.path

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
                Text("新建下载")
                    .font(.title2)
                    .fontWeight(.semibold)

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
                        Label("下载链接", systemImage: "link")
                            .font(.headline)

                        TextField("输入 URL 或磁力链接...", text: $urlText, axis: .vertical)
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
                            Text("请输入有效的 URL 或磁力链接")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }

                    // Save Location
                    VStack(alignment: .leading, spacing: 8) {
                        Label("保存到", systemImage: "folder")
                            .font(.headline)

                        HStack {
                            Text(saveDirectory.path(percentEncoded: false))
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)

                            Spacer()

                            Button("选择...") {
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
                            Toggle("设为默认下载目录", isOn: $setAsDefault)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Advanced Options Toggle
                    DisclosureGroup("高级选项", isExpanded: $showAdvancedOptions) {
                        VStack(alignment: .leading, spacing: 16) {
                            // Connections
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("线程数")
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
                                    ), in: 1...128, step: 1)
                            }

                            // Custom Filename
                            VStack(alignment: .leading, spacing: 8) {
                                Text("自定义文件名")
                                    .font(.subheadline)

                                TextField("留空使用原始文件名", text: $customFilename)
                                    .textFieldStyle(.roundedBorder)
                            }

                            // Custom Headers
                            VStack(alignment: .leading, spacing: 8) {
                                Text("自定义请求头")
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

                                Text("格式：Header-Name: Value （每行一个）")
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
            HStack {
                Button("取消") {
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])

                Spacer()

                Button {
                    addDownload()
                } label: {
                    Text("开始下载")
                        .fontWeight(.semibold)
                        .opacity(isProcessing ? 0 : 1)
                        .overlay {
                            if isProcessing {
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }
                        .frame(width: 120, height: 22) // Rock-solid fixed size
                }
                .buttonStyle(.borderedProminent)
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
        let patterns = [
            "^https?://",
            "^ftp://",
            "^magnet:\\?",
            "^thunder://",
        ]

        for pattern in patterns {
            if url.range(of: pattern, options: .regularExpression) != nil {
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

/// Sheet for adding torrent downloads
struct AddTorrentSheet: View {
    @Environment(DownloadManager.self) private var downloadManager
    @Environment(\.dismiss) private var dismiss

    @State private var torrentURL: URL?
    @AppStorage("defaultConnections") private var defaultConnections = 16
    @State private var saveDirectory = FileManager.default.urls(
        for: .downloadsDirectory, in: .userDomainMask
    ).first!
    @State private var isDragging = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("添加种子")
                    .font(.title2)
                    .fontWeight(.semibold)

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

            // Drop zone
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

                        Button("选择其他文件") {
                            selectTorrentFile()
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Image(systemName: "arrow.down.doc")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)

                        Text("拖放种子文件到此处")
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        Text("或")
                            .foregroundStyle(.tertiary)

                        Button("选择文件...") {
                            selectTorrentFile()
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .frame(height: 200)
            .padding(24)
            .onDrop(of: [.fileURL], isTargeted: $isDragging) { providers in
                handleDrop(providers: providers)
            }

            // Save location
            VStack(alignment: .leading, spacing: 8) {
                Label("保存到", systemImage: "folder")
                    .font(.headline)

                HStack {
                    Text(saveDirectory.path(percentEncoded: false))
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer()

                    Button("选择...") {
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
            .padding(.horizontal, 24)

            Spacer()

            Divider()

            // Footer
            HStack {
                Button("取消") {
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])

                Spacer()

                Button("添加种子") {
                    addTorrent()
                }
                .buttonStyle(.borderedProminent)
                .disabled(torrentURL == nil)
            }
            .padding(24)
        }
        .frame(width: 450, height: 450)
        // Note: .glassEffect() will be available in macOS 26 SDK
        .background(.regularMaterial)
    }

    private func selectTorrentFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.init(filenameExtension: "torrent")!]

        if panel.runModal() == .OK {
            torrentURL = panel.url
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
            }
        }
        return true
    }

    private func addTorrent() {
        guard let url = torrentURL else { return }

        Task {
            do {
                let data = try Data(contentsOf: url)
                let base64 = data.base64EncodedString()
                
                var options: [String: Any] = [
                    "dir": saveDirectory.path(percentEncoded: false)
                ]
                
                // Explicitly pass global connection settings
                // This ensures we respect the user's preference without needing an engine restart
                if defaultConnections > 0 {
                    options["split"] = defaultConnections
                    options["max-connection-per-server"] = defaultConnections
                }
                
                try await downloadManager.addTorrent(
                    base64: base64,
                    options: options
                )
                await MainActor.run {
                    dismiss()
                }
            } catch {
                // Handle error
            }
        }
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
