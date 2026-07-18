import Observation
import SwiftUI
import Quartz

/// List view displaying download tasks with Liquid Glass cards
struct TaskListView: View {
    @Environment(DownloadManager.self) private var downloadManager
    let category: TaskCategory
    @Binding var selectedTaskIds: Set<String>
    @Binding var isInspectorPresented: Bool

    @State private var deleteSheetConfig: DeleteSheetConfig? = nil // nil = sheet hidden
    @State private var lastSelectedId: String? // Track last selection for Shift-click logic
    
    // Marquee Selection State
    @State private var dragStart: CGPoint?
    @State private var dragCurrent: CGPoint?
    @State private var selectionRect: CGRect = .zero
    @AppStorage("language") private var language = "zh-CN"
    @State private var itemFrames: [String: CGRect] = [:]
    @State private var itemWindowFrames: [String: CGRect] = [:] // 追踪相对于窗口内容区域的坐标
    @State private var itemImages: [String: NSImage] = [:] // 缓存缩略图用于动画
    @State private var initialSelectionBeforeDrag: Set<String> = []
    
    // Keyboard Event Monitoring for Navigation (especially during QuickLook)
    @State private var keyMonitor: Any?
    
    // Manual double-click tracking
    @State private var lastClickTime: Date = .distantPast
    @State private var lastClickId: String? = nil
    
    // Quick Look Preview State
    @State private var previewURL: URL?
    
    // Zoom Animation State
    @State private var zoomingTaskId: String?
    @State private var isZooming = false


    var body: some View {
        @Bindable var manager = downloadManager
        
        VStack(spacing: 0) {
            // Header with search and sort
            TaskListHeader(
                category: category,
                taskCount: downloadManager.filteredTasks.count,
                searchText: $manager.searchText,
                sortOrder: $manager.sortOrder,
                onDeleteAll: {
                    deleteSheetConfig = DeleteSheetConfig(
                        displayName: "删除所有任务".localized(for: language),
                        isDeleteAll: true,
                        deleteFiles: downloadManager.deleteWithFilesDefault
                    )
                }
            )
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            Divider()
                .padding(.horizontal, 20)

            // Task list
            if !downloadManager.isConnected {
                engineConnectingView
            } else if downloadManager.filteredTasks.isEmpty {
                EmptyTaskListView(category: category)
            } else {
                taskScrollContent
            }
        }
        .background(.background.opacity(0.5))
        .onDeleteCommand {
            deleteCommandAction()
        }
        .background {
            keyboardShortcutViews
        }
        .sheet(item: $deleteSheetConfig) { config in
            thoroughDeleteSheet(config: config)
        }
        .onAppear {
            downloadManager.currentCategory = category
            setupKeyMonitor()
        }
        .onDisappear {
            removeKeyMonitor()
        }
        .onChange(of: category) { _, newValue in
            downloadManager.currentCategory = newValue
        }
        .onChange(of: selectedTaskIds) { _, newIds in
            // When selection changes, if QuickLook is open, update the preview content
            if QLPreviewPanel.shared()?.isVisible == true {
                handleQuickLook(autoUpdate: true)
            }
        }
    }

    @ViewBuilder
    private var engineConnectingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.regular)
            Text("正在启动下载引擎...".localized(for: language))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Task Scroll Content (Rewritten)
    
    @ViewBuilder
    private var taskScrollContent: some View {
        GeometryReader { outerGeometry in
            ScrollView {
                // Content container with minimum height to fill viewport
                ZStack(alignment: .topLeading) {
                    // Layer 1: Background for drag gesture and tap-to-deselect
                    Color.clear
                        .frame(minHeight: outerGeometry.size.height)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            // Tap on empty area clears selection
                            selectedTaskIds.removeAll()
                            lastSelectedId = nil
                        }
                        .gesture(
                            DragGesture(minimumDistance: 5, coordinateSpace: .named("TaskListSpace"))
                                .onChanged { value in
                                    if dragStart == nil {
                                        dragStart = value.startLocation
                                        initialSelectionBeforeDrag = selectedTaskIds
                                    }
                                    dragCurrent = value.location
                                    updateMarqueeSelection(isShortcutPressed: NSEvent.modifierFlags.contains(.command))
                                }
                                .onEnded { _ in
                                    // Set lastSelectedId for subsequent Shift-click
                                    if let last = itemFrames
                                        .filter({ selectedTaskIds.contains($0.key) })
                                        .sorted(by: { $0.value.minY < $1.value.minY })
                                        .last?.key {
                                        lastSelectedId = last
                                    }
                                    dragStart = nil
                                    dragCurrent = nil
                                }
                        )
                    
                    // Layer 2: Task rows
                    LazyVStack(spacing: 8) {
                        ForEach(downloadManager.filteredTasks) { task in
                            taskRow(task)
                        }
                    }
                    .padding(.top, 12)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                    
                    // Layer 3: Marquee selection overlay
                    marqueeSelectionView
                    

                }
                .coordinateSpace(name: "TaskListSpace")
                .textSelection(.disabled) // Fix cursor turning to I-beam
            }
            .onPreferenceChange(TaskItemFramePreferenceKey.self) { frames in
                itemFrames = frames
            }
            .scrollContentBackground(.hidden)
            .textSelection(.disabled) // Ensure entire scroll area, including empty space, disables text selection
            .background(Color.clear)
            .overlay {
                engineStatusOverlays
            }
            .focusable()
            .focusEffectDisabled()
            .onAppear {
                // Initial set
                // Initial set
                QuickLookManager.shared.visibleContentRect = outerGeometry.frame(in: .global)
            }
            .onChange(of: outerGeometry.frame(in: .global)) { _, newFrame in
                // Update on resize/move
                QuickLookManager.shared.visibleContentRect = newFrame
            }
            .overlay {
                // Layer 4: Zoom Animation Overlay (Viewport Level)
                if let zoomingId = zoomingTaskId,
                   let task = downloadManager.filteredTasks.first(where: { $0.id == zoomingId }),
                   let globalIconFrame = itemWindowFrames[zoomingId], // Use Global Icon Frame
                   let image = itemImages[zoomingId] {
                    
                    let outerFrame = outerGeometry.frame(in: .global)
                    let relativeX = globalIconFrame.midX - outerFrame.minX
                    let relativeY = globalIconFrame.midY - outerFrame.minY
                    
                    ZStack {
                        if task.name.lowercased().hasSuffix(".icns") {
                            // ICNS styling (Matched)
                            ZStack {
                                Color.secondary.opacity(0.1)
                                Image(nsImage: image)
                                   .resizable()
                                   .aspectRatio(contentMode: .fit)
                                   .padding(6)
                            }
                        } else {
                            // Standard styling
                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        }
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .scaleEffect(isZooming ? 5.0 : 1.0) // Increased scale for "Fly out" feel
                    .opacity(isZooming ? 0.0 : 1.0)
                    .position(x: relativeX, y: relativeY)
                    .allowsHitTesting(false)
                }
            }
        }

    }
    
    // MARK: - Task Row (Rewritten)
    
    @ViewBuilder
    private func taskRow(_ task: DownloadTask) -> some View {
        let isSelected = selectedTaskIds.contains(task.id)
        
        Button(action: {
            handleTap(task: task)
        }) {
            TaskItemView(
                task: task,
                isSelected: isSelected,
                selectedTaskIds: selectedTaskIds,
                onThumbnailFrameChanged: { frame in
                    itemWindowFrames[task.id] = frame
                    if let filePath = task.files.first?.path, !filePath.isEmpty {
                        QuickLookManager.shared.setCache(for: URL(fileURLWithPath: filePath), frame: frame, image: nil)
                    }
                },
                onThumbnailImageChanged: { image in
                    itemImages[task.id] = image
                    if let filePath = task.files.first?.path, !filePath.isEmpty {
                        QuickLookManager.shared.setCache(for: URL(fileURLWithPath: filePath), frame: itemWindowFrames[task.id] ?? .zero, image: image)
                    }
                },
                onShowInfo: {
                    selectedTaskIds = [task.id]
                    withAnimation(.spring(duration: 0.25)) {
                        isInspectorPresented = true
                    }
                }
            )
            .background(
                ZStack {
                    // Selection highlight
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.accentColor.opacity(0.1))
                    }
                    
                    // Frame reporter (invisible, but captures geometry for marquee selection)
                    GeometryReader { proxy in
                        Color.clear
                            .onAppear {
                                itemFrames[task.id] = proxy.frame(in: .named("TaskListSpace"))
                            }
                            .preference(
                                key: TaskItemFramePreferenceKey.self,
                                value: [task.id: proxy.frame(in: .named("TaskListSpace"))]
                            )
                    }
                }
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(TaskItemButtonStyle())
        // Double-click: open/pause/resume (using simultaneousGesture to not block single-click)
        .simultaneousGesture(
            TapGesture(count: 2).onEnded {
                handleDoubleTap(task: task)
            }
        )
    }

    private func handleDoubleTap(task: DownloadTask) {
        if task.status == "complete" {
            // Trigger Zoom Animation
            // Use itemFrames (local coordinate) check
            if itemFrames[task.id] != nil {
                // Set initial state
                zoomingTaskId = task.id
                
                // Animate
                // Use a slightly faster response for snappier feel
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                     isZooming = true
                }
                
                // Delay opening file to let animation COMPLETELY finish to prevent main thread freeze causing visual stutter
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    downloadManager.openFile(task)
                    
                    // Reset state
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        isZooming = false
                        zoomingTaskId = nil
                    }
                }
            } else {
                // Fallback
                downloadManager.openFile(task)
            }
        } else if category == .downloading {
            if task.canPause {
                Task { await downloadManager.pauseTask(task) }
            } else if task.canResume {
                Task { await downloadManager.resumeTask(task) }
            }
        }
    }

    @ViewBuilder
    private var marqueeSelectionView: some View {
        if let start = dragStart, let end = dragCurrent {
            let rect = CGRect(
                x: min(start.x, end.x),
                y: min(start.y, end.y),
                width: abs(start.x - end.x),
                height: abs(start.y - end.y)
            )
            Rectangle()
                .fill(Color.accentColor.opacity(0.15))
                .stroke(Color.accentColor.opacity(0.5), lineWidth: 1)
                .frame(width: rect.width, height: rect.height)
                .offset(x: rect.minX, y: rect.minY)
        }
    }

    @ViewBuilder
    private var engineStatusOverlays: some View {
        Group {
            if let engine = downloadManager.aria2Process, 
               engine.state != .running && engine.state != .idle && !downloadManager.needsRepair {
                EngineHealOverlay(state: engine.state)
                    .transition(.opacity)
            }
            
            if downloadManager.needsRepair {
                EngineRepairOverlay()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private func deleteCommandAction() {
        guard !selectedTaskIds.isEmpty else { return }
        
        if downloadManager.skipDeleteConfirmation {
             deleteSelectedTasks(withFiles: downloadManager.deleteWithFilesDefault)
        } else {
             let name = selectedDisplayName
             deleteSheetConfig = DeleteSheetConfig(
                 displayName: name,
                 isDeleteAll: false,
                 deleteFiles: downloadManager.deleteWithFilesDefault
             )
        }
    }

    @ViewBuilder
    private var keyboardShortcutViews: some View {
        // Select All (Cmd+A)
        Button("") {
            selectedTaskIds = Set(downloadManager.filteredTasks.map { $0.id })
        }
        .keyboardShortcut("a", modifiers: .command)
        .hidden()
        
        // Delete Shortcuts
        Button("") {
            if !selectedTaskIds.isEmpty {
                if downloadManager.skipDeleteConfirmation {
                     deleteSelectedTasks(withFiles: downloadManager.deleteWithFilesDefault)
                } else {
                     let name = selectedDisplayName
                     deleteSheetConfig = DeleteSheetConfig(
                         displayName: name,
                         isDeleteAll: false,
                         deleteFiles: downloadManager.deleteWithFilesDefault
                     )
                }
            }
        }
        .keyboardShortcut(.delete, modifiers: [])
        .hidden()

        Button("") {
             if !selectedTaskIds.isEmpty {
                 let name = selectedDisplayName
                 deleteSheetConfig = DeleteSheetConfig(
                     displayName: name,
                     isDeleteAll: false,
                     deleteFiles: downloadManager.deleteWithFilesDefault
                 )
             }
        }
        .keyboardShortcut(.delete, modifiers: [.command, .option])
        .hidden()
        
        // Quick Look (Space)
        Button("") {
            handleQuickLook()
        }
        .keyboardShortcut(.space, modifiers: [])
        .hidden()
        
        // Navigation (Up/Down Arrows)
        Button("") {
            moveSelection(direction: -1)
        }
        .keyboardShortcut(.upArrow, modifiers: [])
        .hidden()
        
        Button("") {
            moveSelection(direction: 1)
        }
        .keyboardShortcut(.downArrow, modifiers: [])
        .hidden()
    }

    @ViewBuilder
    private func thoroughDeleteSheet(config: DeleteSheetConfig) -> some View {
        DeleteConfirmationSheetWrapper(
            config: config,
            downloadManager: downloadManager,
            onDeleteAll: { withFiles in
                let tasksToDelete = downloadManager.filteredTasks
                Task {
                    await downloadManager.deleteTasks(tasksToDelete, withFiles: withFiles)
                    selectedTaskIds.removeAll()
                }
                deleteSheetConfig = nil
            },
            onDeleteSelected: { withFiles in
                deleteSelectedTasks(withFiles: withFiles)
                deleteSheetConfig = nil
            },
            onCancel: {
                deleteSheetConfig = nil
            }
        )
    }

    private var selectedDisplayName: String {
        if selectedTaskIds.count == 1 {
            return downloadManager.filteredTasks.first(where: { $0.id == selectedTaskIds.first })?.name ?? "1 个任务".localized(for: language)
        } else {
            return "\(selectedTaskIds.count) " + "个任务".localized(for: language)
        }
    }

    private func handleTap(task: DownloadTask) {
        let isCommandPressed = NSEvent.modifierFlags.contains(.command)
        let isShiftPressed = NSEvent.modifierFlags.contains(.shift)

        if isShiftPressed, let lastId = lastSelectedId, let lastIndex = downloadManager.filteredTasks.firstIndex(where: { $0.id == lastId }), let currentIndex = downloadManager.filteredTasks.firstIndex(where: { $0.id == task.id }) {
            // Range selection
            let range = min(lastIndex, currentIndex)...max(lastIndex, currentIndex)
            let tasksInRange = downloadManager.filteredTasks[range]
            let idsInRange = tasksInRange.map { $0.id }
            selectedTaskIds.formUnion(idsInRange)
        } else if isCommandPressed {
            // Toggle selection
            if selectedTaskIds.contains(task.id) {
                selectedTaskIds.remove(task.id)
            } else {
                selectedTaskIds.insert(task.id)
                lastSelectedId = task.id
            }
        } else {
            // Single selection
            selectedTaskIds = [task.id]
            lastSelectedId = task.id
        }
    }

    private func updateMarqueeSelection(isShortcutPressed: Bool) {
        guard let start = dragStart, let end = dragCurrent else { return }
        
        // Normalize rect
        let selectionRect = CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(start.x - end.x),
            height: abs(start.y - end.y)
        )
        
        var newSelection = isShortcutPressed ? initialSelectionBeforeDrag : Set<String>()
        
        for (id, frame) in itemFrames {
            if selectionRect.intersects(frame) {
                if isShortcutPressed {
                    // Command toggle behavior during marquee
                    if initialSelectionBeforeDrag.contains(id) {
                        newSelection.remove(id)
                    } else {
                        newSelection.insert(id)
                    }
                } else {
                    newSelection.insert(id)
                }
            }
        }
        
        selectedTaskIds = newSelection
    }

    private func deleteSelectedTasks(withFiles: Bool) {
        guard !selectedTaskIds.isEmpty else { return }
        let tasksToDelete = downloadManager.tasks.filter { selectedTaskIds.contains($0.id) }
        
        Task {
            await downloadManager.deleteTasks(tasksToDelete, withFiles: withFiles)
            // Clear selection after delete
            selectedTaskIds.removeAll()
            lastSelectedId = nil
        }
    }

    private func handleQuickLook(autoUpdate: Bool = false) {
        // Find the first selected task that has a valid file path and is completed
        guard let firstId = selectedTaskIds.first,
              let task = downloadManager.filteredTasks.first(where: { $0.id == firstId }),
              task.status == "complete",
              let filePath = task.files.first?.path,
              !filePath.isEmpty else {
            // If panel is open and we have no valid selection, maybe close? 
            // For now, keep it open but show nil if needed.
            return
        }
        
        let url = URL(fileURLWithPath: filePath)
        
        // 使用原生 QLPreviewPanel 实现带动画的展示
        if let panel = QLPreviewPanel.shared() {
            QuickLookManager.shared.updateSourceWindow(NSApp.keyWindow)
            QuickLookManager.shared.currentURL = url
            QuickLookManager.shared.previewingTaskId = firstId
            QuickLookManager.shared.setCache(for: url, frame: itemWindowFrames[firstId] ?? .zero, image: itemImages[firstId])
            
            panel.dataSource = QuickLookManager.shared
            panel.delegate = QuickLookManager.shared
            
            if !autoUpdate {
                panel.makeKeyAndOrderFront(nil as Any?)
            } else {
                panel.reloadData()
            }
        }
    }

    // MARK: - Keyboard Monitor
    
    private func setupKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Handle arrow keys only if the window is active and we are not typing in a text field
            guard NSApp.keyWindow != nil else { return event }
            
            // Avoid intercepting if focus is in a Search field or TextField
            if let firstResponder = NSApp.keyWindow?.firstResponder,
               firstResponder is NSTextView || firstResponder is NSTextField {
                return event
            }

            switch event.keyCode {
            case 125: // Down Arrow
                moveSelection(direction: 1)
                return nil // Consume event
            case 126: // Up Arrow
                moveSelection(direction: -1)
                return nil // Consume event
            default:
                return event
            }
        }
    }
    
    private func removeKeyMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    private func moveSelection(direction: Int) {
        let tasks = downloadManager.filteredTasks
        guard !tasks.isEmpty else { return }
        
        let currentIndex: Int
        if let lastId = lastSelectedId, let index = tasks.firstIndex(where: { $0.id == lastId }) {
            currentIndex = index
        } else {
            currentIndex = direction > 0 ? -1 : tasks.count
        }
        
        let nextIndex = currentIndex + direction
        if nextIndex >= 0 && nextIndex < tasks.count {
            let nextTask = tasks[nextIndex]
            selectedTaskIds = [nextTask.id]
            lastSelectedId = nextTask.id
        }
    }
}

// MARK: - Quick Look 原生管理类

@Observable
class QuickLookManager: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    static let shared = QuickLookManager()
    
    // 缓存字典：根据 URL 存储坐标和图像
    private var frameCache: [URL: CGRect] = [:]
    private var imageCache: [URL: NSImage] = [:]
    
    var currentURL: URL?
    var previewingTaskId: String? // Track active preview ID for Hero animation logic
    
    var visibleContentRect: CGRect = .zero 
    private(set) var sourceWindow: NSWindow? 
    
    // Observation requires us not to use NSObject if possible, but we need it for delegates.
    // @Observable macro works on classes.
    
    override init() {
        super.init()
        setupNotifications()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: nil, queue: .main) { [weak self] note in
            if let panel = note.object as? QLPreviewPanel, panel == QLPreviewPanel.shared() {
                // Delay clearing to allow animation to finish visually covering the icon
                // Standard macOS duration is roughly 0.25-0.3s. 
                // We keep the icon hidden until the animation completes to prevent ghosting.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    self?.previewingTaskId = nil
                }
            }
        }
    }

    func setCache(for url: URL, frame: CGRect, image: NSImage?) {
        if frame != .zero {
            frameCache[url] = frame
        }
        if let image = image {
            imageCache[url] = image
        }
    }
    
    /// 获取已缓存的图像，用于侧边栏零延迟加载
    func getCachedImage(for url: URL) -> NSImage? {
        return imageCache[url]
    }
    
    /// 当确定是主窗口活动时更新窗口引用
    func updateSourceWindow(_ window: NSWindow?) {
        guard let window = window, !(window is QLPreviewPanel) else { return }
        self.sourceWindow = window
    }
    
    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        return currentURL != nil ? 1 : 0
    }
    
    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        return currentURL as (QLPreviewItem)?
    }
    
    func previewPanel(_ panel: QLPreviewPanel!, sourceFrameOnScreenFor item: QLPreviewItem!) -> NSRect {
        guard let url = item as? URL,
              let itemFrame = frameCache[url],
              let window = sourceWindow else { return .zero }
        
        // 裁剪检查：使用 Window 坐标系进行判断 (因为 visibleContentRect 和 itemFrame 都是 Window 坐标)
        if visibleContentRect != .zero {
            let intersection = itemFrame.intersection(visibleContentRect)
            let originalArea = itemFrame.width * itemFrame.height
            let visibleArea = intersection.width * intersection.height
            
            if visibleArea < (originalArea * 0.5) {
                return .zero
            }
        }
        
        // 翻转坐标系：SwiftUI (Top-left) -> AppKit (Bottom-left) 
        // 必须使用锁定后的主窗口高度，否则当 QL 面板在前时 window.frame.height 是错的
        let windowHeight = window.frame.height
        let appKitY = windowHeight - itemFrame.origin.y - itemFrame.size.height
        
        // 构建相对于窗口基准的 Rect
        let rectInWindow = NSRect(x: itemFrame.origin.x, y: appKitY, width: itemFrame.size.width, height: itemFrame.size.height)
        
        // 转换为屏幕坐标
        return window.convertToScreen(rectInWindow)
    }
    
    func previewPanel(_ panel: QLPreviewPanel!, transitionImageFor item: QLPreviewItem!, contentRect: UnsafeMutablePointer<NSRect>!) -> Any! {
        guard let url = item as? URL, let image = imageCache[url] else { return nil }
        
        // 创建带圆角且保持 Aspect Fill (居中裁剪) 的过渡图像
        // 这样可以确保动画收尾图与渲染出的缩略图视觉完全一致，消除比例压缩感
        let targetSize = NSSize(width: 44, height: 44)
        let isIcns = url.pathExtension.lowercased() == "icns"
        
        let roundedImage = NSImage(size: targetSize, flipped: false) { rect in
            let path = NSBezierPath(roundedRect: rect, xRadius: 10, yRadius: 10)
            path.addClip()
            
            if isIcns {
                // ICNS: 绘制浅色背景 + Fit 模式（带 Padding）
                NSColor.secondaryLabelColor.withAlphaComponent(0.1).setFill()
                rect.fill()
                
                let padding: CGFloat = 6.0
                let drawRect = rect.insetBy(dx: padding, dy: padding)
                image.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1.0)
            } else {
                // 其他格式：保持 Aspect Fill (居中裁剪)
                let originalSize = image.size
                let aspectWidth = targetSize.width / originalSize.width
                let aspectHeight = targetSize.height / originalSize.height
                let maxAspect = max(aspectWidth, aspectHeight)
                
                let drawWidth = originalSize.width * maxAspect
                let drawHeight = originalSize.height * maxAspect
                let drawX = (targetSize.width - drawWidth) / 2
                let drawY = (targetSize.height - drawHeight) / 2
                
                image.draw(in: NSRect(x: drawX, y: drawY, width: drawWidth, height: drawHeight),
                           from: .zero,
                           operation: .sourceOver,
                           fraction: 1.0)
            }
            return true
        }
        return roundedImage
    }
}

// MARK: - Helper Components for Selection

struct TaskItemButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
    }
}

// MARK: - Engine Repair Overlay

struct EngineRepairOverlay: View {
    @Environment(DownloadManager.self) private var downloadManager
    @AppStorage("language") private var language = "zh-CN"
    @State private var isRepairing = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.orange)

            VStack(spacing: 8) {
                Text("引擎连接失败".localized(for: language))
                    .font(.headline)
                
                Text(downloadManager.connectionError ?? "可能由于残留进程或密钥不一致导致。建议尝试强行重置。".localized(for: language))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            HStack(spacing: 12) {
                Button("不再提示") {
                    downloadManager.needsRepair = false
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Button {
                    isRepairing = true
                    Task {
                        await downloadManager.forceRepair()
                        isRepairing = false
                    }
                } label: {
                    if isRepairing {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("强行重置并修复".localized(for: language))
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isRepairing)
            }
        }
        .padding(24)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.background)
                .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                }
        }
        .padding(40)
        .frame(maxWidth: 400)
    }
}

struct TaskListHeader: View {
    @Environment(DownloadManager.self) private var downloadManager
    let category: TaskCategory
    let taskCount: Int
    @Binding var searchText: String
    @Binding var sortOrder: SortOrder
    @AppStorage("language") private var language = "zh-CN"
    var onDeleteAll: () -> Void


    var body: some View {
        ZStack {
            // Layer 1: Title (Absolute Leading)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    if category == .downloading && downloadManager.singleListMode {
                        Text("所有下载任务".localized(for: language))
                            .font(.title2)
                            .fontWeight(.semibold)
                    } else {
                        Text(category.title(for: language))
                            .font(.title2)
                            .fontWeight(.semibold)
                    }



                    Text("\(taskCount) " + "个任务".localized(for: language))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .transaction { $0.animation = nil }

            // Layer 2: Controls (Absolute Trailing)
            HStack(spacing: 16) {
                Spacer()

                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)

                    TextField("搜索".localized(for: language), text: $searchText)
                        .textFieldStyle(.plain)

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(nsColor: .controlBackgroundColor))
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                    }
                .frame(width: 200)

                // Clear All / Delete All button
                if taskCount > 0 {
                    Button {
                        onDeleteAll()
                    } label: {
                        Image(systemName: "trash")
                            .font(.body.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .frame(width: 24)
                    .help(category == .completed ? "全部清除".localized(for: language) : "全部移除".localized(for: language))
                }

                // Sort menu
                Menu {
                    ForEach(SortOrder.allCases) { order in
                        Button {
                            sortOrder = order
                        } label: {
                            HStack {
                                Text(order.title.localized(for: language))
                                if sortOrder == order {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: 24)
            }
        }
        .frame(height: 44) // Fix height to prevent jitters during transition
    }
}

// MARK: - Empty Task List

struct EmptyTaskListView: View {
    let category: TaskCategory
    @Environment(DownloadManager.self) private var downloadManager
    @AppStorage("language") private var language = "zh-CN"

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: emptyIcon)
                .font(.system(size: 48))
                .foregroundStyle(.quaternary)

            Text(emptyMessage)
                .font(.title3)
                .foregroundStyle(.secondary)

            if category == .downloading {
                Button {
                    downloadManager.showAddTaskSheet = true
                } label: {
                    Label("添加下载".localized(for: language), systemImage: "plus")
                        .font(.system(size: 14, weight: .medium))
                        .font(.system(size: 14, weight: .medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.accentColor.opacity(0.1), in: Capsule())
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyIcon: String {
        switch category {
        case .downloading: return "arrow.down.app"
        case .completed: return "checkmark.seal"
        case .settings: return "gearshape"
        case .about: return "info.circle"
        }
    }

    private var emptyMessage: String {
        switch category {
        case .downloading: return "暂无下载任务".localized(for: language)
        case .completed: return "暂无已完成任务".localized(for: language)
        case .settings: return ""
        case .about: return ""
        }
    }
}

// MARK: - Sort Order

enum SortOrder: String, CaseIterable, Identifiable {
    case dateAdded
    case name
    case size
    case progress

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dateAdded: return "添加时间"
        case .name: return "名称"
        case .size: return "大小"
        case .progress: return "进度"
        }
    }
}

extension Array where Element == DownloadTask {
    func sorted(by order: SortOrder) -> [DownloadTask] {
        switch order {
        case .dateAdded:
            return sorted { $0.addedAt > $1.addedAt }
        case .name:
            return sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        case .size:
            return sorted { $0.totalLength > $1.totalLength }
        case .progress:
            return sorted { $0.progress > $1.progress }
        }
    }
}

#Preview {
    TaskListView(
        category: .downloading, 
        selectedTaskIds: .constant([]),
        isInspectorPresented: .constant(false)
    )
    .environment(DownloadManager.shared)
    .frame(width: 400, height: 600)
}

// MARK: - Engine Heal Overlay (Passive status)

struct EngineHealOverlay: View {
    @AppStorage("language") private var language = "zh-CN"
    let state: EngineProcess.EngineState

    var body: some View {
        ZStack {
            // High-end glassmorphism freeze
            Rectangle()
                .fill(.ultraThinMaterial)
                .contentShape(Rectangle()) // Capture all taps
            
            VStack(spacing: 20) {
                ProgressView()
                    .controlSize(.large)
                
                VStack(spacing: 8) {
                    Text(state.rawValue)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Text("由于上次异常退出，正在尝试自愈系统以确保稳定。".localized(for: language))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(40)
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.background)
                    .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
            }
            .padding(40)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Delete Sheet Config

struct DeleteSheetConfig: Identifiable {
    let id = UUID()
    let displayName: String
    let isDeleteAll: Bool
    let deleteFiles: Bool
}

struct DeleteConfirmationSheetWrapper: View {
    let config: DeleteSheetConfig
    let downloadManager: DownloadManager
    let onDeleteAll: (Bool) -> Void
    let onDeleteSelected: (Bool) -> Void
    let onCancel: () -> Void
    
    @State private var deleteFiles: Bool
    @State private var rememberChoice = false
    
    init(config: DeleteSheetConfig, downloadManager: DownloadManager, onDeleteAll: @escaping (Bool) -> Void, onDeleteSelected: @escaping (Bool) -> Void, onCancel: @escaping () -> Void) {
        self.config = config
        self.downloadManager = downloadManager
        self.onDeleteAll = onDeleteAll
        self.onDeleteSelected = onDeleteSelected
        self.onCancel = onCancel
        self._deleteFiles = State(initialValue: config.deleteFiles)
    }
    
    var body: some View {
        DeleteConfirmationSheet(
            taskName: config.displayName,
            deleteFiles: $deleteFiles,
            rememberChoice: $rememberChoice,
            onConfirm: {
                if rememberChoice {
                    downloadManager.skipDeleteConfirmation = true
                    downloadManager.deleteWithFilesDefault = deleteFiles
                }
                if config.isDeleteAll {
                    onDeleteAll(deleteFiles)
                } else {
                    onDeleteSelected(deleteFiles)
                }
            },
            onCancel: onCancel
        )
    }
}
