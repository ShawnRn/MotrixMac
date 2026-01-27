import SwiftUI

struct TaskItemFramePreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

/// Individual download task item with Liquid Glass card styling
struct TaskItemView: View {
    @Environment(DownloadManager.self) private var downloadManager
    let task: DownloadTask
    let isSelected: Bool
    var onThumbnailFrameChanged: (CGRect) -> Void = { _ in }
    var onThumbnailImageChanged: (NSImage) -> Void = { _ in }
    var onShowInfo: () -> Void = {}

    @State private var isHovering = false
    @State private var showDeleteConfirmation = false
    @State private var deleteFiles = false
    @State private var rememberChoice = false

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            // Left Accent Bar (Selection Indicator)
            Capsule()
                .fill(Color.accentColor)
                .frame(width: 4)
                .opacity(isSelected ? 1 : 0)
                .animation(.none, value: isSelected) // IMMEDIATE FEEDBACK
                .frame(height: 44)
                .padding(.leading, -8) // Pull it slightly left

            // File type icon/thumbnail
            ZStack {
                if task.fileType == .image {
                    TaskThumbnailView(task: task, size: 44, onImageLoaded: { image in
                        onThumbnailImageChanged(image)
                    })
                } else {
                    FileIconView(fileType: task.fileType)
                        .frame(width: 44, height: 44)
                        .onAppear {
                            // 使用 ImageRenderer 获取包含背景颜色的完整图标快照
                            let iconView = FileIconView(fileType: task.fileType)
                                .frame(width: 44, height: 44)
                            let renderer = ImageRenderer(content: iconView)
                            renderer.scale = 2.0 // 适配 Retina 屏幕
                            if let image = renderer.nsImage {
                                onThumbnailImageChanged(image)
                            }
                        }
                }
            }
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .onChange(of: proxy.frame(in: .global)) { _, newFrame in
                            onThumbnailFrameChanged(newFrame)
                        }
                        .onAppear {
                            onThumbnailFrameChanged(proxy.frame(in: .global))
                        }
                }
            )

            // Task info (Top & Bottom)
            VStack(alignment: .leading, spacing: 6) {
                // Row 1: File name (Headline)
                Text(task.name)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(.primary)

                // Row 2: Status Metadata (Subheadline)
                HStack(spacing: 8) {
                    if task.isActive {
                        // Progress bar for active tasks
                        if task.totalLength == 0 || (task.progress == 0 && task.status != "paused") {
                             IndeterminateProgressView()
                                 .frame(width: 100, height: 4)
                                 .clipShape(Capsule())
                        } else {
                            ProgressView(value: task.progress)
                                .progressViewStyle(.linear)
                                .tint(progressColor)
                                .frame(width: 100)
                        }
                    }

                    // Row 2: Pre-calculated Status line (Scheme A)
                    if !task.formattedStatusLine.isEmpty {
                        Text(task.formattedStatusLine)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            // Row 3 (Right): Action Buttons
            // Only visible on hover or selection, but layout preserved to avoid jumps
            Group {
                if isHovering || isSelected {
                    TaskActionButtons(
                        task: task,
                        showDeleteConfirmation: $showDeleteConfirmation,
                        deleteFiles: $deleteFiles,
                        onShowInfo: onShowInfo
                    )
                    .transition(.opacity)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? Color.blue.opacity(0.1) : Color.clear)
                .animation(.none, value: isSelected) // IMMEDIATE FEEDBACK
        }
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .contextMenu {
            TaskContextMenu(task: task)
        }
        .sheet(isPresented: $showDeleteConfirmation) {
            DeleteConfirmationSheet(
                taskName: task.name,
                deleteFiles: $deleteFiles,
                rememberChoice: $rememberChoice,
                onConfirm: {
                    if rememberChoice {
                        downloadManager.skipDeleteConfirmation = true
                        downloadManager.deleteWithFilesDefault = deleteFiles
                    }
                    Task { await downloadManager.deleteTask(task, withFiles: deleteFiles) }
                    showDeleteConfirmation = false
                },
                onCancel: {
                    showDeleteConfirmation = false
                }
            )
        }
    }


    private var progressColor: Color {
        switch task.status {
        case "error": return .red
        case "paused": return .orange
        default: return .accentColor
        }
    }
}

// MARK: - File Icon

struct FileIconView: View {
    let fileType: FileType

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(fileType.color.gradient)

            Image(systemName: fileType.icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let status: String
    var displayStatus: String? = nil

    var body: some View {
        Text(displayText)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background {
                Capsule()
                    .fill(badgeColor.opacity(0.15))
            }
            .foregroundStyle(badgeColor)
    }

    private var displayText: String {
        if let display = displayStatus, display == "Connecting..." {
            return "连接中..."
        }

        switch status {
        case "waiting": return "等待中"
        case "paused": return "已暂停"
        case "complete": return "已完成"
        case "error": return "出现错误"
        case "removed": return "已取消"
        case "active": return "下载中"
        default: return status.capitalized
        }
    }

    private var badgeColor: Color {
        if let display = displayStatus, display == "Connecting..." {
            return .blue
        }

        switch status {
        case "waiting": return .orange
        case "paused": return .yellow
        case "complete": return .green
        case "error": return .red
        case "removed": return .secondary
        case "active": return .blue
        default: return .secondary
        }
    }
}

// MARK: - Action Buttons

struct TaskActionButtons: View {
    @Environment(DownloadManager.self) private var downloadManager
    let task: DownloadTask
    @Binding var showDeleteConfirmation: Bool
    @Binding var deleteFiles: Bool
    let onShowInfo: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            if task.canPause {
                ActionButton(icon: "pause.fill", color: .orange) {
                    Task { await downloadManager.pauseTask(task) }
                }
                .help("暂停")
            }

            if task.canResume {
                ActionButton(icon: "play.fill", color: .green) {
                    Task { await downloadManager.resumeTask(task) }
                }
                .help("恢复")
            }

            if task.status == "error" || task.status == "removed" {
                ActionButton(icon: "arrow.clockwise", color: .green) {
                    Task { await downloadManager.retryTask(task) }
                }
                .help(task.status == "removed" ? "重新下载" : "重试")
            }

            ActionButton(icon: "folder", color: .blue) {
                downloadManager.revealInFinder(task)
            }
            .help("在 Finder 中显示")

            ActionButton(icon: "trash", color: .red) {
                if downloadManager.skipDeleteConfirmation {
                    Task {
                        await downloadManager.deleteTask(
                            task, withFiles: downloadManager.deleteWithFilesDefault)
                    }
                } else {
                    deleteFiles = downloadManager.deleteWithFilesDefault
                    showDeleteConfirmation = true
                }
            }
            .help("在任务列表中移除")
            
            ActionButton(icon: "info.circle", color: .secondary) {
                onShowInfo()
            }
            .help("显示详情")
            
        }
    }
}

struct ActionButton: View {
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background {
                    Circle()
                        .fill(color.opacity(0.1))
                }
        }
        .buttonStyle(.borderless)
    }
}

// MARK: - Context Menu

struct TaskContextMenu: View {
    @Environment(DownloadManager.self) private var downloadManager
    let task: DownloadTask

    var body: some View {
        Group {
            if task.canPause {
                Button("暂停") {
                    Task { await downloadManager.pauseTask(task) }
                }
            }

            if task.canResume {
                Button("恢复") {
                    Task { await downloadManager.resumeTask(task) }
                }
            }

            if task.status == "error" || task.status == "removed" {
                Button(task.status == "removed" ? "重新下载" : "重试") {
                    Task { await downloadManager.retryTask(task) }
                }
            }

            if task.canCancel && task.status != "removed" {
                Button("取消下载") {
                    Task { await downloadManager.cancelTask(task) }
                }
            }

            Divider()

            Button("在 Finder 中显示") {
                downloadManager.revealInFinder(task)
            }

            Button("复制下载链接") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(task.uri, forType: .string)
            }

            Divider()

            Button("移除记录", role: .destructive) {
                Task { await downloadManager.deleteTask(task) }
            }

            Button("移除记录并删除本地文件", role: .destructive) {
                Task { await downloadManager.deleteTask(task, withFiles: true) }
            }
        }
    }
}

// MARK: - Delete Confirmation Sheet

struct DeleteConfirmationSheet: View {
    let taskName: String
    @Binding var deleteFiles: Bool
    @Binding var rememberChoice: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 16) {
                Image(systemName: "trash.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.red)

                VStack(alignment: .leading, spacing: 4) {
                    Text("确认移除此任务记录？")
                        .font(.headline)
                    Text(taskName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 12) {
                Toggle("同时删除本地文件", isOn: $deleteFiles)
                    .toggleStyle(.checkbox)

                Toggle("以后不再询问", isOn: $rememberChoice)
                    .toggleStyle(.checkbox)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Button("取消") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("确认移除", role: .destructive) {
                    onConfirm()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 360)
    }
}

#Preview {
    TaskItemView(
        task: DownloadTask.preview,
        isSelected: false
    )
    .environment(DownloadManager.shared)
    .frame(width: 500)
    .padding()
    .frame(width: 500)
    .padding()
}

struct IndeterminateProgressView: View {
    @State private var offset: CGFloat = -1.0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                Capsule()
                    .fill(Color.secondary.opacity(0.2))
                
                // Moving pill
                Capsule()
                    .fill(LinearGradient(
                        colors: [.clear, .accentColor.opacity(0.5), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .frame(width: geometry.size.width * 0.5)
                    .offset(x: offset * geometry.size.width)
            }
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    offset = 2.0
                }
            }
        }
    }
}
