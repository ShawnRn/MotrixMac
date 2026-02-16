import Charts
import Observation
import SwiftUI

/// Detailed view for a selected download task
struct TaskDetailView: View {
    @Environment(DownloadManager.self) private var downloadManager
    let task: DownloadTask
    let initialThumbnail: NSImage?
    @AppStorage("language") private var language = "zh-CN"

    @State private var selectedTab: DetailTab = .general

    var body: some View {
        VStack(spacing: 0) {
            // Header with file info
            TaskDetailHeader(task: task, initialThumbnail: initialThumbnail)
                .padding(.top, 60)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)

            // Divider removed for cleaner look

            if task.isTorrent {
                // Custom sliding tab picker
                SlidingTabPicker(selection: $selectedTab, tabs: DetailTab.allCases) { tab in
                    tab.title.localized(for: language)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }

            // Tab content with animation
            ZStack {
                switch selectedTab {
                case .general:
                    GeneralTabView(task: task)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                case .files:
                    FilesTabView(task: task)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                case .peers:
                    PeersTabView(task: task)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                case .trackers:
                    TrackersTabView(task: task)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedTab)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Detail Header

struct TaskDetailHeader: View {
    @Environment(DownloadManager.self) private var downloadManager
    let task: DownloadTask
    let initialThumbnail: NSImage?
    @AppStorage("language") private var language = "zh-CN"

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            // Icon Container
            // Use precise framing and compositing to prevent layout glitches
            ZStack {
                if task.fileType == .image {
                    TaskThumbnailView(task: task, size: 80, initialImage: initialThumbnail)
                } else {
                    FileIconView(fileType: task.fileType, size: 80)
                        .frame(width: 80, height: 80)
                }
            }
            .frame(width: 80, height: 80)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
            }
            .compositingGroup() // Force flattening to prevent "fly out" rendering issues

            VStack(alignment: .leading, spacing: 12) {
                // Title & Badge
                HStack(alignment: .top, spacing: 8) {
                    Text(task.effectiveName)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true) // Allow multiline expansion
                    
                    Spacer(minLength: 0)
                    
                    StatusBadge(status: task.status, displayStatus: task.displayStatus)
                }

                // Stats Grid - More stable than HStack
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                    GridRow {
                        InfoLabel(icon: "doc", text: task.totalLength.formatted(.byteCount(style: .file)))
                        
                        if task.isActive {
                            InfoLabel(
                                icon: "arrow.down",
                                text: task.downloadSpeed.formatted(.byteCount(style: .file)) + "/s",
                                color: .green
                            )
                        } else {
                            // Placeholder or Completed Date
                            InfoLabel(icon: "folder", text: (task.isTorrent ? "文件夹" : "文件").localized(for: language))
                        }
                    }
                    
                    if task.isActive {
                        GridRow {
                            InfoLabel(icon: "clock", text: task.eta)
                            
                            InfoLabel(
                                icon: "arrow.up",
                                text: task.uploadSpeed.formatted(.byteCount(style: .file)) + "/s",
                                color: .blue
                            )
                        }
                    }
                }
                
                // Progress Bar
                VStack(spacing: 6) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.secondary.opacity(0.1))
                            if !task.isIndeterminate {
                                Capsule()
                                    .fill(task.statusColor)
                                    .frame(width: geo.size.width * task.progress)
                            } else {
                                IndeterminateBar(tint: task.statusColor, height: 6)
                            }
                        }
                        .clipShape(Capsule())
                    }
                    .frame(height: 6)

                    HStack {
                        Text(task.isIndeterminate ? "--" : "\(Int(task.progress * 100))%")
                        Spacer()
                        Text("\(task.completedLength.formatted(.byteCount(style: .file))) / \(task.totalLength.formatted(.byteCount(style: .file)))")
                    }
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// 辅助组件：更统一的信息标签
struct InfoLabel: View {
    let icon: String
    let text: String
    var color: Color = .secondary
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .frame(width: 12) // Fixed icon width
            Text(text)
                .font(.caption)
                .monospacedDigit() // Fixed digit width
        }
        .foregroundStyle(color)
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

// MARK: - Sliding Tab Picker

struct SlidingTabPicker<Tab: Hashable & Identifiable>: View {
    @Binding var selection: Tab
    let tabs: [Tab]
    let titleForTab: (Tab) -> String
    
    @Namespace private var namespace
    
    init(selection: Binding<Tab>, tabs: [Tab], titleForTab: @escaping (Tab) -> String) {
        self._selection = selection
        self.tabs = tabs
        self.titleForTab = titleForTab
    }
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs) { tab in
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        selection = tab
                    }
                } label: {
                    VStack(spacing: 6) {
                        Text(titleForTab(tab))
                            .font(.system(size: 12, weight: selection == tab ? .medium : .regular))
                            .foregroundStyle(selection == tab ? .primary : .secondary)
                        
                        // Underline indicator
                        ZStack {
                            Rectangle()
                                .fill(.clear)
                                .frame(height: 2)
                            
                            if selection == tab {
                                Rectangle()
                                    .fill(Color.accentColor)
                                    .frame(height: 2)
                                    .matchedGeometryEffect(id: "underline", in: namespace)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

extension SlidingTabPicker where Tab == DetailTab {
    init(selection: Binding<DetailTab>, tabs: [DetailTab]) {
        self.init(selection: selection, tabs: tabs) { $0.title }
    }
}

// MARK: - General Tab

struct GeneralTabView: View {
    let task: DownloadTask
    @AppStorage("language") private var language = "zh-CN"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !task.downloadSpeedHistory.isEmpty, (task.downloadSpeedHistory.max() ?? 0) > 0 {
                    DetailSection(title: "速度走势".localized(for: language)) {
                        if let maxSpeed = task.downloadSpeedHistory.max(), maxSpeed > 0 {
                            Label("峰值: ".localized(for: language) + "\(maxSpeed.formatted(.byteCount(style: .file)))/s", systemImage: "bolt.fill")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.accentColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.accentColor.opacity(0.1), in: Capsule())
                        }
                    } content: {
                        SpeedChartView(history: task.downloadSpeedHistory, isComplete: task.status == "complete")
                            .padding(.top, 4)
                        
                        if let bitfield = task.bitfield, !bitfield.isEmpty {
                            Divider()
                                .padding(.vertical, 8)
                            
                            PieceProgressView(bitfield: bitfield, numPieces: task.numPieces, connections: task.connections)
                                .padding(.bottom, 4)
                        }
                    }
                }
 else if let bitfield = task.bitfield, !bitfield.isEmpty {
                    DetailSection(title: "分块进度".localized(for: language)) {
                        PieceProgressView(bitfield: bitfield, numPieces: task.numPieces, connections: task.connections)
                    }
                }

                DetailSection(title: "下载".localized(for: language)) {
                    DetailRow(label: "链接".localized(for: language), value: task.uri)
                    DetailRow(label: "保存位置".localized(for: language), value: task.dir)
                    if task.isActive {
                        DetailRow(label: "连接数".localized(for: language), value: "\(task.connections)")
                    }
                }

                DetailSection(title: "进度".localized(for: language)) {
                    DetailRow(
                        label: "已下载".localized(for: language),
                        value: task.completedLength.formatted(.byteCount(style: .file)))
                    DetailRow(
                        label: "总大小".localized(for: language),
                        value: task.totalLength.formatted(.byteCount(style: .file)))
                    DetailRow(
                        label: "进度".localized(for: language), value: String(format: "%.1f%%", task.progress * 100))
                }

                if task.isActive {
                    DetailSection(title: "速度".localized(for: language)) {
                        DetailRow(
                            label: "下载速度".localized(for: language),
                            value: task.downloadSpeed.formatted(.byteCount(style: .file)) + "/s")
                        DetailRow(
                            label: "上传速度".localized(for: language),
                            value: task.uploadSpeed.formatted(.byteCount(style: .file)) + "/s")
                    }
                }

                if task.isTorrent {
                    DetailSection(title: "BitTorrent") {
                        DetailRow(label: "Info Hash".localized(for: language), value: task.infoHash ?? "N/A")
                        DetailRow(label: "做种数".localized(for: language), value: "\(task.numSeeders)")
                        DetailRow(label: "分块数".localized(for: language), value: "\(task.numPieces)")
                    }
                }
            }
            .padding(24)
        }
    }
}

struct DetailSection<Header: View, Content: View>: View {
    let title: String
    @ViewBuilder let header: Header
    @ViewBuilder let content: Content

    init(title: String, @ViewBuilder header: () -> Header = { EmptyView() }, @ViewBuilder content: () -> Content) {
        self.title = title
        self.header = header()
        self.content = content()
    }

    // Convenience for no header case
    init(title: String, @ViewBuilder content: () -> Content) where Header == EmptyView {
        self.title = title
        self.header = EmptyView()
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
                header
            }

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
    var isComplete: Bool = false
    
    // Smooth the data using a moving average to reduce jaggedness
    private var smoothedHistory: [Int64] {
        guard history.count > 4 else { return history }
        let windowSize = 3 // 3-point moving average
        var result: [Int64] = []
        for i in 0..<history.count {
            let start = max(0, i - windowSize / 2)
            let end = min(history.count - 1, i + windowSize / 2)
            let window = history[start...end]
            let avg = window.reduce(0, +) / Int64(window.count)
            result.append(avg)
        }
        return result
    }
    @State private var hoverIndex: Int?
    @State private var lastRelativeX: Double? = nil

    var body: some View {
        Chart {
            // Main chart content
            chartContent
            
            // Interaction overlay
            if let index = hoverIndex, index >= 0, index < history.count {
               interactionContent(for: index)
            }
        }
        .chartXAxis { xAxis }
        .chartYAxis { yAxis }
        .chartYScale(domain: 0...max(1, Double(history.max() ?? 0) * 1.1))
        .chartOverlay { proxy in
            GeometryReader { geometry in
                if let anchor = proxy.plotFrame {
                    let plotFrame = geometry[anchor]
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .onContinuousHover { phase in
                            handleHover(phase, proxy: proxy, plotFrame: plotFrame)
                        }
                }
            }
        }
        .frame(height: 140)
        .padding(.vertical, 8)
        .chartXScale(domain: 0...max(1, history.count - 1))
        .onChange(of: history) { oldValue, newValue in
            updateHoverIndexFromRelativeX()
        }
    }
    
    @ChartContentBuilder
    private var chartContent: some ChartContent {
        // Use smoothed data for the visual curve, but keep original data for tooltips
        ForEach(Array(smoothedHistory.enumerated()), id: \.offset) { index, speed in
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
    
    @ChartContentBuilder
    private func interactionContent(for index: Int) -> some ChartContent {
        RuleMark(x: .value("Time", index))
            .foregroundStyle(Color.secondary.opacity(0.5))
            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            .annotation(position: .top, overflowResolution: .init(x: .fit, y: .disabled)) {
                VStack(spacing: 4) {
                    Text(history[index].formatted(.byteCount(style: .file)) + "/s")
                        .font(.system(.caption, design: .monospaced).bold())
                        .foregroundStyle(.primary)
                    Text(timeLabel(for: index))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(8)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
            }
        
        PointMark(
            x: .value("Time", index),
            y: .value("Speed", Double(smoothedHistory[index]))
        )
        .symbolSize(60)
        .foregroundStyle(Color.white)
        .symbol {
            Circle()
                .fill(Color.accentColor)
                .frame(width: 8, height: 8)
                .overlay {
                    Circle().stroke(.white, lineWidth: 2)
                }
                .shadow(radius: 2)
        }
    }
    
    @AxisContentBuilder
    private var xAxis: some AxisContent {
        AxisMarks(values: .automatic(desiredCount: 5)) { value in
            if let i = value.as(Int.self) {
                AxisValueLabel {
                    Text(timeLabel(for: i))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(.quaternary)
                AxisTick()
                    .foregroundStyle(.quaternary)
            }
        }
    }
    
    @AxisContentBuilder
    private var yAxis: some AxisContent {
        AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
            AxisValueLabel {
                if let speed = value.as(Double.self) {
                    Text(Int64(speed).formatted(.byteCount(style: .file)) + "/s")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 40, alignment: .trailing)
                }
            }
            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                .foregroundStyle(.quaternary)
        }
    }
    
    private func handleHover(_ phase: HoverPhase, proxy: ChartProxy, plotFrame: CGRect) {
        switch phase {
        case .active(let location):
            // Calculate x relative to plot area (compensate for Y-axis width)
            let xInPlot = location.x - plotFrame.origin.x
            
            // Safe range check
            if xInPlot >= 0 && xInPlot <= plotFrame.width {
                lastRelativeX = xInPlot / plotFrame.width
                
                let xValue: Int? = proxy.value(atX: xInPlot)
                if let x = xValue, x >= 0, x < history.count {
                    hoverIndex = x
                } else {
                    hoverIndex = nil
                }
            } else {
                lastRelativeX = nil
                hoverIndex = nil
            }
        case .ended:
            lastRelativeX = nil
            hoverIndex = nil
        }
    }
    
    private func updateHoverIndexFromRelativeX() {
        guard let rx = lastRelativeX, !history.isEmpty else {
            return
        }
        
        // Linear mapping matching the chart's X Scale (0 to history.count - 1)
        let totalCount = Double(history.count)
        if totalCount <= 1 {
            hoverIndex = 0
            return
        }
        
        let index = Int(round(rx * (totalCount - 1)))
        hoverIndex = max(0, min(history.count - 1, index))
    }
    
    // Helper to convert index to relative time string (assuming 1s interval)
    private func timeLabel(for index: Int) -> String {
        let total = history.count
        let secondsAgo = total - 1 - index
        if secondsAgo <= 0 {
            return isComplete ? "完成".localized(for: "zh-CN") : "现在".localized(for: "zh-CN") // Placeholder
        }
        return "-\(secondsAgo)s"
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
            FileIconView(fileType: FileType.from(filename: file.path), size: 32)
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
    @AppStorage("language") private var language = "zh-CN"

    var body: some View {
        if task.peers.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "person.2.slash")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(.tertiary)
                Text("暂无用户".localized(for: language))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .offset(y: -30)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    let sortedPeers = task.peers.sorted { $0.ip < $1.ip }
                    
                    ForEach(sortedPeers) { peer in
                        PeerMinimalRow(peer: peer)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        }
    }
}

// MARK: - 极简行 (点击触发 Popover)

struct PeerMinimalRow: View {
    let peer: TaskPeer
    @State private var showPopover = false
    @State private var isHovering = false
    
    // 实时获取国旗
    var flag: String {
        GeoIPService.shared.flag(for: peer.ip)
    }

    var body: some View {
        Button {
            showPopover.toggle()
        } label: {
            HStack(spacing: 12) {
                // 1. 国旗 (使用固定尺寸防止抖动)
                Text(flag)
                    .font(.system(size: 16))
                    .frame(width: 20, alignment: .center)
                
                // 2. IP 地址
                Text(peer.ip)
                    .font(.system(.callout, design: .monospaced)) // Smaller font
                    .foregroundStyle(.primary)
                
                Spacer()
                
                // 3. 实时网速 (直接显示)
                if peer.downloadSpeed > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.down")
                        .font(.system(size: 8))
                        Text(peer.downloadSpeed.formatted(.byteCount(style: .file)) + "/s")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(.green)
                    }
                } else if peer.uploadSpeed > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.up")
                        .font(.system(size: 8))
                        Text(peer.uploadSpeed.formatted(.byteCount(style: .file)) + "/s")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(.blue)
                    }
                }
                
                // 4. 信息图标
                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .opacity(isHovering ? 1 : 0)
            }
            .padding(.vertical, 4) // Compact padding
            .padding(.horizontal, 12)
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovering ? AnyShapeStyle(Color.secondary.opacity(0.1)) : AnyShapeStyle(Color.clear))
            }
        }
        .buttonStyle(.plain)
        .onHover { hover in
            isHovering = hover 
        } 
        // 核心交互：macOS 原生风格气泡
        .popover(isPresented: $showPopover, arrowEdge: .trailing) {
            PeerDetailPopover(peer: peer, flag: flag)
        }
    }
}

// MARK: - 详情气泡 (Popover Content)

struct PeerDetailPopover: View {
    let peer: TaskPeer
    let flag: String
    @AppStorage("language") private var language = "zh-CN"
    
    var clientName: String {
        peer.clientName
    }

    var countryName: String {
        guard let isoCode = GeoIPService.shared.lookup(ip: peer.ip) else { return "Unknown Location" }
        return Locale.current.localizedString(forRegionCode: isoCode) ?? isoCode
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 顶部：IP 和 地理位置
            HStack(spacing: 12) {
                Text(flag)
                    .font(.system(size: 32))
                    .shadow(radius: 1)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(peer.ip)
                        .font(.headline.monospaced())
                        .textSelection(.enabled) // 允许复制 IP
                    
                    Text(countryName) 
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 4)
            
            Divider()
            
            // 中部：详细数据网格
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                // 客户端
                GridRow {
                    Label("客户端".localized(for: language), systemImage: "desktopcomputer")
                        .foregroundStyle(.secondary)
                    Text(clientName)
                        .lineLimit(1)
                }
                
                // 端口
                GridRow {
                    Label("端口".localized(for: language), systemImage: "network")
                        .foregroundStyle(.secondary)
                    Text(peer.port, format: .number.grouping(.never))
                        .monospacedDigit()
                }
                
                // 连接状态
                GridRow {
                    Label("状态".localized(for: language), systemImage: "antenna.radiowaves.left.and.right")
                        .foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        Circle()
                            .fill(statusColor(for: peer))
                            .frame(width: 8, height: 8)
                        Text(peer.connectionStatus)
                            .foregroundStyle(statusColor(for: peer))
                    }
                }
            }
            .font(.callout)
            
            Divider()
            
            // 底部：速度面板
            HStack(spacing: 20) {
                SpeedIndicator(
                    title: "下载".localized(for: language),
                    value: peer.downloadSpeed,
                    color: .green,
                    icon: "arrow.down"
                )
                
                Divider().frame(height: 20)
                
                SpeedIndicator(
                    title: "上传".localized(for: language),
                    value: peer.uploadSpeed,
                    color: .blue,
                    icon: "arrow.up"
                )
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
        }
        .padding(20)
        .frame(width: 280) // 气泡固定宽度
    }
    
    /// Returns color based on peer connection status
    private func statusColor(for peer: TaskPeer) -> Color {
        if peer.seeder {
            return .green
        } else if peer.amChoking && peer.peerChoking {
            return .gray
        } else if peer.amChoking || peer.peerChoking {
            return .orange
        } else {
            return .blue
        }
    }
}

// 辅助组件：气泡内的速度显示
struct SpeedIndicator: View {
    let title: String
    let value: Int64
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(value.formatted(.byteCount(style: .file)) + "/s")
                    .font(.system(.callout, design: .monospaced))
                    .fontWeight(.medium)
            }
            .foregroundStyle(value > 0 ? color : .secondary)
        }
    }
}

// MARK: - Trackers Tab

struct TrackersTabView: View {
    let task: DownloadTask
    @AppStorage("language") private var language = "zh-CN"

    var body: some View {
        if task.trackers.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "antenna.radiowaves.left.and.right.slash")
                    .font(.system(size: 36, weight: .thin))
                    .foregroundStyle(.tertiary)
                
                Text("暂无 Tracker".localized(for: language))
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                
                Text("未配置或未连接到任何 Tracker".localized(for: language))
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .offset(y: -30)
        } else {
            ScrollView {
                LazyVStack(spacing: 8) {
                    // Deduplicate trackers by URL to avoid SwiftUI duplicate ID warnings
                    let uniqueTrackers = task.trackers.reduce(into: [String: TaskTracker]()) { dict, tracker in
                        if dict[tracker.url] == nil { dict[tracker.url] = tracker }
                    }.values.sorted { $0.url < $1.url }
                    
                    ForEach(uniqueTrackers, id: \.url) { tracker in
                        TrackerRow(tracker: tracker)
                    }
                }
                .padding(24)
            }
        }
    }
}

struct TrackerRow: View {
    let tracker: TaskTracker
    @AppStorage("language") private var language = "zh-CN"
    
    private var statusColor: Color {
        switch tracker.status.lowercased() {
        case "active": return .green
        case "waiting": return .orange
        case "error", "failed": return .red
        default: return .gray
        }
    }
    
    private var localizedStatus: String {
        switch tracker.status.lowercased() {
        case "active": return "active".localized(for: language)
        case "waiting": return "waiting".localized(for: language)
        case "error", "failed": return "error".localized(for: language)
        default: return tracker.status.capitalized
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)

            Text(tracker.url)
                .font(.caption.monospaced())
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            Text(localizedStatus)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(.quaternary.opacity(0.3))
        }
    }
}

// MARK: - Piece Progress View (Helper)
// Use the implementation in Views/Components/PieceProgressView.swift
