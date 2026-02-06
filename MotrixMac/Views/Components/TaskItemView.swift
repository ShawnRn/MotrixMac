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
                if task.fileType == .image && !task.isFileMissing {
                    TaskThumbnailView(task: task, size: 44, onImageLoaded: { image in
                        onThumbnailImageChanged(image)
                    })
                } else {
                    FileIconView(fileType: task.fileType, size: 44)
                        .frame(width: 44, height: 44)
                        .onAppear {
                            // 使用 ImageRenderer 获取包含背景颜色的完整图标快照
                            let iconView = FileIconView(fileType: task.fileType, size: 44)
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
            // Removed opacity hack: .opacity(QuickLookManager.shared.previewingTaskId == task.id ? 0 : 1)
            
            // Task info (Top & Bottom)
            VStack(alignment: .leading, spacing: 6) {
                // Row 1: File name (Headline)
                Text(task.effectiveName)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(task.isFileMissing ? .secondary : .primary)
                    .opacity(task.isFileMissing ? 0.8 : 1.0)
                
                // Row 2: Status Metadata (Subheadline)
                HStack(spacing: 8) {
                    if task.status != "complete" && task.status != "removed" {
                        if task.isIndeterminate {
                             IndeterminateBar(tint: task.statusColor, height: 6)
                                 .frame(width: 100)
                                 .clipShape(Capsule())
                        } else {
                            ProgressView(value: task.progress)
                                .progressViewStyle(.linear)
                                .tint(task.statusColor)
                                .frame(width: 100, height: 6)
                                .clipShape(Capsule())
                        }
                    }
                    
                    
                    
                    // Row 2: Pre-calculated Status line (Scheme A)
                    // Status text
                    if !task.formattedStatusLine.isEmpty {
                         Text(task.formattedStatusLine + (task.isFileMissing ? " · 已移除" : ""))
                            .font(.subheadline)
                            .foregroundStyle(task.isFileMissing ? .tertiary : .secondary)
                    }
                }
            }
            
            Spacer()
            
            // Row 3 (Right): Action Buttons
            // Only visible on hover , but layout preserved to avoid jumps
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
        // Removed local check: .onAppear { checkFileExistence() }
        .contextMenu {
            TaskContextMenu(task: task)
        }
        .sheet(isPresented: $showDeleteConfirmation) {
            DeleteConfirmationSheet(
                taskName: task.effectiveName,
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
    
    // statusColor logic moved to DownloadTask extension in AppModels.swift
    
    // Removed private func checkFileExistence()
}

// MARK: - File Icon

struct FileIconView: View {
    let fileType: FileType
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(fileType.color.gradient)

            Image(systemName: fileType.icon)
                .font(.system(size: size * 0.45, weight: .medium))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let status: String
    var displayStatus: String? = nil
    var isFileMissing: Bool = false

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
        if let display = displayStatus {
            if display == "Connecting..." { return "连接中..." }
            if display == "做种中" { return "做种中" }
            if display == "下载中" { return "下载中" }
        }

        switch status {
        case "waiting": return "等待中"
        case "paused": return "已暂停"
        case "complete": return isFileMissing ? "已完成 · 已移除" : "已完成"
        case "error": return "出现错误"
        case "removed": return "已取消"
        case "active": return "下载中"
        default: return status.capitalized
        }
    }

    private var badgeColor: Color {
        if let display = displayStatus {
            if display == "Connecting..." { return .blue }
            if display == "做种中" { return .indigo }
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
            if task.isSeeding {
                ActionButton(icon: "stop.fill", color: .red) {
                    Task { await downloadManager.stopSeeding(task) }
                }
                .help("停止做种")
            } else if task.canPause {
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
            if task.isSeeding {
                Button("停止做种") {
                    Task { await downloadManager.stopSeeding(task) }
                }
            } else if task.canPause {
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
        VStack(spacing: 24) {
            HStack(alignment: .top, spacing: 20) {
                // Icon block
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.12))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: "trash.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.red)
                }

                VStack(alignment: .leading, spacing: 16) {
                    // Question text
                    VStack(alignment: .leading, spacing: 4) {
                        Text("确认移除任务？")
                            .font(.system(size: 16, weight: .bold))
                        Text(taskName)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    // Options
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("同时删除本地文件", isOn: $deleteFiles)
                            .toggleStyle(.checkbox)
                        Toggle("以后不再询问", isOn: $rememberChoice)
                            .toggleStyle(.checkbox)
                    }
                    .font(.system(size: 13))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Footer buttons
            HStack(spacing: 12) {
                Button {
                    onCancel()
                } label: {
                    Text("取消")
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
                    onConfirm()
                } label: {
                    Text("确定")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 80, height: 28)
                        .background(Color.red, in: Capsule())
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .buttonStyle(SidebarButtonStyle())
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(24)
        .frame(width: 380)
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

// Moved to MotrixMac/Views/Components/IndeterminateBar.swift
