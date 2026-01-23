import Observation
import SwiftUI

/// Menu bar popover view with download overview
struct MenuBarView: View {
    @Environment(DownloadManager.self) private var downloadManager

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            // Header with speed
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("MotrixMac")
                        .font(.headline)

                    HStack(spacing: 12) {
                        Label(
                            downloadManager.totalDownloadSpeed.formatted(.byteCount(style: .file))
                                + "/s",
                            systemImage: "arrow.down"
                        )
                        .foregroundStyle(.green)

                        Label(
                            downloadManager.totalUploadSpeed.formatted(.byteCount(style: .file))
                                + "/s",
                            systemImage: "arrow.up"
                        )
                        .foregroundStyle(.blue)
                    }
                    .font(.caption)
                }

                Spacer()

                Button {
                    downloadManager.showAddTaskSheet = true
                    NSApp.activate(ignoringOtherApps: true)
                    showMainWindow()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }
            .padding(16)

            Divider()

            // Active downloads list
            if downloadManager.activeDownloads.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle")
                        .font(.largeTitle)
                        .foregroundStyle(.quaternary)

                    Text("暂无下载任务")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(downloadManager.activeDownloads.prefix(5)) { task in
                            MenuBarTaskRow(task: task)
                        }

                        if downloadManager.activeDownloads.count > 5 {
                            Text("+ 还有 \(downloadManager.activeDownloads.count - 5) 个任务")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(12)
                }
                .frame(maxHeight: 250)
            }

            Divider()

            // Actions
            HStack(spacing: 12) {
                Button {
                    Task { await downloadManager.pauseAll() }
                } label: {
                    Label("全部暂停", systemImage: "pause.fill")
                }
                .disabled(downloadManager.activeDownloads.isEmpty)

                Button {
                    Task { await downloadManager.resumeAll() }
                } label: {
                    Label("全部恢复", systemImage: "play.fill")
                }

                Spacer()

                Button {
                    showMainWindow()
                } label: {
                    Label("打开主面板", systemImage: "arrow.up.forward.app")
                }
            }
            .font(.caption)
            .buttonStyle(.plain)
            .padding(12)

            Divider()

            // Quit button
            Button {
                NSApp.terminate(nil)
            } label: {
                Text("退出 MotrixMac (⌘+Q)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .padding(12)
        }
        .frame(width: 320)
    }

    private func showMainWindow() {
        // Activate app first
        NSApp.activate(ignoringOtherApps: true)

        // Try to bring existing window to front
        if let window = NSApp.windows.first(where: {
            $0.title == "MotrixMac" || $0.identifier?.rawValue == "motrixmac-main"
        }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            // Open window using SwiftUI environment
            openWindow(id: "main")
        }
    }
}

// MARK: - Menu Bar Task Row

struct MenuBarTaskRow: View {
    let task: DownloadTask

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(task.name)
                .font(.subheadline)
                .lineLimit(1)

            ProgressView(value: task.progress)
                .progressViewStyle(.linear)
                .tint(.accentColor)

            HStack {
                Text("\(Int(task.progress * 100))%")

                Spacer()

                Text(task.downloadSpeed.formatted(.byteCount(style: .file)) + "/s")
                    .foregroundStyle(.green)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(.quaternary.opacity(0.5))
        }
    }
}

#Preview {
    MenuBarView()
        .environment(DownloadManager.shared)
}
