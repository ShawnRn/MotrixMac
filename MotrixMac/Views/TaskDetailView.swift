import Charts
import Observation
import SwiftUI

/// Detailed view for a selected download task
struct TaskDetailView: View {
    @Environment(DownloadManager.self) private var downloadManager
    let task: DownloadTask

    @State private var selectedTab: DetailTab = .general

    var body: some View {
        VStack(spacing: 0) {
            // Header with file info
            TaskDetailHeader(task: task)
                .padding(.top, 60)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)

            Divider()

            if task.isTorrent {
                // Tab picker
                Picker("详细信息", selection: $selectedTab) {
                    ForEach(DetailTab.allCases) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }

            // Tab content (Replaced TabView with switch to avoid unwanted UI elements)
            Group {
                switch selectedTab {
                case .general:
                    GeneralTabView(task: task)
                case .files:
                    FilesTabView(task: task)
                case .peers:
                    PeersTabView(task: task)
                case .trackers:
                    TrackersTabView(task: task)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(.background.opacity(0.3))
    }
}

// MARK: - Detail Header

struct TaskDetailHeader: View {
    @Environment(DownloadManager.self) private var downloadManager
    let task: DownloadTask

    var body: some View {
        HStack(spacing: 20) {
            // Large file icon
            FileIconView(fileType: task.fileType)
                .frame(width: 72, height: 72)

            VStack(alignment: .leading, spacing: 8) {
                Text(task.name)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .lineLimit(2)

                HStack(spacing: 16) {
                    if task.totalLength == 0 {
                        Label(
                            task.completedLength > 0
                                ? task.completedLength.formatted(.byteCount(style: .file))
                                : "正在获取...", systemImage: "doc")
                    } else {
                        Label(
                            task.totalLength.formatted(.byteCount(style: .file)), systemImage: "doc"
                        )
                    }

                    if task.isActive && task.displayStatus != "Connecting..." {
                        Label(
                            task.downloadSpeed.formatted(.byteCount(style: .file)) + "/s",
                            systemImage: "arrow.down"
                        )
                        .foregroundStyle(.green)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                    }

                    StatusBadge(status: task.status, displayStatus: task.displayStatus)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                
                // Error Message Display
                if task.status == "error", let errorMsg = task.errorMessage {
                    HStack(alignment: .top, spacing: 12) {
                        Text(errorMsg)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Button {
                            Task {
                                await downloadManager.retryTask(task)
                            }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(6)
                                .background(.red, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .help("Retry Download")
                    }
                    .padding(8)
                    .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                }

                // Large progress bar
                VStack(alignment: .leading, spacing: 4) {
                    if task.isIndeterminate {
                        ProgressView()
                            .progressViewStyle(.linear)
                            .tint(.accentColor)
                    } else {
                        ProgressView(value: task.progress)
                            .progressViewStyle(.linear)
                            .tint(.accentColor)
                    }

                    HStack {
                        if task.isIndeterminate {
                            Text("Gathering Metadata...")
                        } else {
                            Text("\(Int(task.progress * 100))%")
                        }
                        Spacer()
                        if task.isActive && task.displayStatus != "Connecting..."
                            && task.totalLength > 0
                        {
                            Text("ETA: \(task.eta)")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Detail Tabs

enum DetailTab: String, CaseIterable, Identifiable {
    case general
    case files
    case peers
    case trackers

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "常规"
        case .files: return "文件"
        case .peers: return "用户"
        case .trackers: return "Tracker"
        }
    }
}

// MARK: - General Tab

struct GeneralTabView: View {
    let task: DownloadTask

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !task.downloadSpeedHistory.isEmpty {
                    DetailSection(title: "速度走势") {
                        SpeedChartView(history: task.downloadSpeedHistory)
                            .padding(.top, 4)
                    }
                }

                DetailSection(title: "下载") {
                    DetailRow(label: "链接", value: task.uri)
                    DetailRow(label: "保存位置", value: task.dir)
                    if task.isActive {
                        DetailRow(label: "连接数", value: "\(task.connections)")
                    }
                }

                DetailSection(title: "进度") {
                    DetailRow(
                        label: "已下载",
                        value: task.completedLength.formatted(.byteCount(style: .file)))
                    DetailRow(
                        label: "总大小",
                        value: task.totalLength.formatted(.byteCount(style: .file)))
                    DetailRow(
                        label: "进度", value: String(format: "%.1f%%", task.progress * 100))
                }

                if task.isActive {
                    DetailSection(title: "速度") {
                        DetailRow(
                            label: "下载速度",
                            value: task.downloadSpeed.formatted(.byteCount(style: .file)) + "/s")
                        DetailRow(
                            label: "上传速度",
                            value: task.uploadSpeed.formatted(.byteCount(style: .file)) + "/s")
                    }
                }

                if task.isTorrent {
                    DetailSection(title: "BitTorrent") {
                        DetailRow(label: "Info Hash", value: task.infoHash ?? "N/A")
                        DetailRow(label: "做种数", value: "\(task.numSeeders)")
                        DetailRow(label: "分块数", value: "\(task.numPieces)")
                    }
                }
            }
            .padding(24)
        }
    }
}

struct DetailSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                content
            }
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.quaternary.opacity(0.5))
            }
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
        }
        .font(.subheadline)
    }
}

// MARK: - Components

struct SpeedChartView: View {
    let history: [Int64]

    var body: some View {
        Chart {
            ForEach(Array(history.enumerated()), id: \.offset) { index, speed in
                LineMark(
                    x: .value("Time", index),
                    y: .value("Speed", Double(speed))
                )
                .foregroundStyle(Color.accentColor)
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("Time", index),
                    y: .value("Speed", Double(speed))
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.accentColor.opacity(0.3), Color.accentColor.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisValueLabel {
                    if let speed = value.as(Double.self) {
                        Text(Int64(speed).formatted(.byteCount(style: .file)) + "/s")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                    .foregroundStyle(.quaternary)
            }
        }
        .frame(height: 100)
        .padding(.vertical, 8)
    }
}

// MARK: - Files Tab

struct FilesTabView: View {
    let task: DownloadTask

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(task.files, id: \.path) { file in
                    FileRow(file: file)
                }
            }
            .padding(24)
        }
    }
}

struct FileRow: View {
    let file: TaskFile

    var body: some View {
        HStack(spacing: 12) {
            FileIconView(fileType: FileType.from(filename: file.path))
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text((file.path as NSString).lastPathComponent)
                    .lineLimit(1)

                Text(file.length.formatted(.byteCount(style: .file)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if file.selected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Image(systemName: "circle")
                    .foregroundStyle(.quaternary)
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(.quaternary.opacity(0.3))
        }
    }
}

// MARK: - Peers Tab

struct PeersTabView: View {
    let task: DownloadTask

    var body: some View {
        ScrollView {
            if task.peers.isEmpty {
                ContentUnavailableView(
                    "暂无用户",
                    systemImage: "person.2.slash",
                    description: Text("未连接到任何用户")
                )
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(task.peers, id: \.ip) { peer in
                        PeerRow(peer: peer)
                    }
                }
                .padding(24)
            }
        }
    }
}

struct PeerRow: View {
    let peer: TaskPeer

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(peer.ip)
                    .font(.body.monospaced())

                Text(peer.client)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 8) {
                    Label(
                        peer.downloadSpeed.formatted(.byteCount(style: .file)) + "/s",
                        systemImage: "arrow.down"
                    )
                    .foregroundStyle(.green)

                    Label(
                        peer.uploadSpeed.formatted(.byteCount(style: .file)) + "/s",
                        systemImage: "arrow.up"
                    )
                    .foregroundStyle(.blue)
                }
                .font(.caption)
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(.quaternary.opacity(0.3))
        }
    }
}

// MARK: - Trackers Tab

struct TrackersTabView: View {
    let task: DownloadTask

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(task.trackers, id: \.url) { tracker in
                    TrackerRow(tracker: tracker)
                }
            }
            .padding(24)
        }
    }
}

struct TrackerRow: View {
    let tracker: TaskTracker

    var body: some View {
        HStack {
            Circle()
                .fill(tracker.status == "active" ? .green : .orange)
                .frame(width: 8, height: 8)

            Text(tracker.url)
                .font(.body.monospaced())
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            Text(tracker.status.capitalized)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(.quaternary.opacity(0.3))
        }
    }
}

#Preview {
    TaskDetailView(task: .preview)
        .environment(DownloadManager.shared)
        .frame(width: 500, height: 700)
}
