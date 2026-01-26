import Observation
import SwiftUI

/// List view displaying download tasks with Liquid Glass cards
struct TaskListView: View {
    @Environment(DownloadManager.self) private var downloadManager
    let category: TaskCategory
    @Binding var selectedTaskIds: Set<String>
    @Binding var isInspectorPresented: Bool

    @State private var showThoroughDeleteAlert = false
    @State private var deleteFiles = false
    @State private var rememberChoice = false
    @State private var lastSelectedId: String? // Track last selection for Shift-click logic
    @State private var isDeleteAllMode = false // New state for delete all
    
    // Marquee Selection State
    @State private var dragStart: CGPoint?
    @State private var dragCurrent: CGPoint?
    @State private var itemFrames: [String: CGRect] = [:]
    @State private var initialSelectionBeforeDrag: Set<String> = []
    
    // Manual double-click tracking
    @State private var lastClickTime: Date = .distantPast
    @State private var lastClickId: String? = nil


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
                    isDeleteAllMode = true
                    deleteFiles = downloadManager.deleteWithFilesDefault
                    showThoroughDeleteAlert = true
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
        .sheet(isPresented: $showThoroughDeleteAlert) {
            thoroughDeleteSheet
        }
        .onAppear {
            downloadManager.currentCategory = category
        }
        .onChange(of: category) { _, newValue in
            downloadManager.currentCategory = newValue
        }
    }

    @ViewBuilder
    private var engineConnectingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.regular)
            Text("Starting download engine...")
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
            }
            .onPreferenceChange(TaskItemFramePreferenceKey.self) { frames in
                itemFrames = frames
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .overlay {
                engineStatusOverlays
            }
            .focusable()
            .focusEffectDisabled()
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
                onShowInfo: {
                    selectedTaskIds = [task.id]
                    withAnimation(.spring(duration: 0.25)) {
                        isInspectorPresented = true
                    }
                }
            )
            // Single background with ZStack for selection highlight + frame reporter
            .background(
                ZStack {
                    // Selection highlight
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.accentColor.opacity(0.1))
                    }
                    
                    // Frame reporter (invisible, but captures geometry)
                    GeometryReader { proxy in
                        Color.clear
                            .onAppear {
                                // Force initial frame report
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
        .buttonStyle(.plain)
        // Double-click: open/pause/resume (using simultaneousGesture to not block single-click)
        .simultaneousGesture(
            TapGesture(count: 2).onEnded {
                handleDoubleTap(task: task)
            }
        )
    }

    private func handleDoubleTap(task: DownloadTask) {
        if task.status == "complete" {
            downloadManager.openFile(task)
        } else if task.canPause {
            Task { await downloadManager.pauseTask(task) }
        } else if task.canResume {
            Task { await downloadManager.resumeTask(task) }
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
             deleteFiles = downloadManager.deleteWithFilesDefault
             showThoroughDeleteAlert = true
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
                     deleteFiles = downloadManager.deleteWithFilesDefault
                     showThoroughDeleteAlert = true
                }
            }
        }
        .keyboardShortcut(.delete, modifiers: [])
        .hidden()

        Button("") {
             if !selectedTaskIds.isEmpty {
                 showThoroughDeleteAlert = true
             }
        }
        .keyboardShortcut(.delete, modifiers: [.command, .option])
        .hidden()
    }

    @ViewBuilder
    private var thoroughDeleteSheet: some View {
        DeleteConfirmationSheet(
            taskName: thoroughDeleteDisplayName,
            deleteFiles: $deleteFiles,
            rememberChoice: $rememberChoice,
            onConfirm: {
                if rememberChoice {
                    downloadManager.skipDeleteConfirmation = true
                    downloadManager.deleteWithFilesDefault = deleteFiles
                }
                
                if isDeleteAllMode {
                    let tasksToDelete = downloadManager.filteredTasks
                    Task {
                        await downloadManager.deleteTasks(tasksToDelete, withFiles: deleteFiles)
                        selectedTaskIds.removeAll()
                        isDeleteAllMode = false
                    }
                } else {
                    deleteSelectedTasks(withFiles: deleteFiles)
                }
                showThoroughDeleteAlert = false
            },
            onCancel: {
                isDeleteAllMode = false
                showThoroughDeleteAlert = false
            }
            )
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

    private var thoroughDeleteDisplayName: String {
        if isDeleteAllMode {
            return "当前列表中的所有任务"
        } else if selectedTaskIds.count == 1 {
            return downloadManager.filteredTasks.first(where: { $0.id == selectedTaskIds.first })?.name ?? "1 个任务"
        } else {
            return "\(selectedTaskIds.count) 个任务"
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
}

// MARK: - Helper Components for Selection

struct TaskItemButtonStyle: ButtonStyle {
    let isSelected: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                if configuration.isPressed {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.accentColor.opacity(0.1))
                }
            }
            .contentShape(Rectangle())
            .animation(.none, value: configuration.isPressed)
    }
}

// MARK: - Engine Repair Overlay

struct EngineRepairOverlay: View {
    @Environment(DownloadManager.self) private var downloadManager
    @State private var isRepairing = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.orange)

            VStack(spacing: 8) {
                Text("引擎连接失败")
                    .font(.headline)
                
                Text(downloadManager.connectionError ?? "可能由于残留进程或密钥不一致导致。建议尝试强行重置。")
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
                        Text("强行重置并修复")
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
    var onDeleteAll: () -> Void


    var body: some View {
        ZStack {
            // Layer 1: Title (Absolute Leading)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(category.title)
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("\(taskCount) 个任务")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .fixedSize(horizontal: true, vertical: false)

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

                    TextField("搜索", text: $searchText)
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
                    .help(category == .completed ? "全部清除" : "全部移除")
                }

                // Sort menu
                Menu {
                    ForEach(SortOrder.allCases) { order in
                        Button {
                            sortOrder = order
                        } label: {
                            HStack {
                                Text(order.title)
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
                    Label("添加下载", systemImage: "plus")
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
        case .downloading: return "暂无下载任务"
        case .completed: return "暂无已完成任务"
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
                    
                    Text("由于上次异常退出，正在尝试自愈系统以确保稳定。")
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
