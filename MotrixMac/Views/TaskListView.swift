import Observation
import SwiftUI

/// List view displaying download tasks with Liquid Glass cards
struct TaskListView: View {
    @Environment(DownloadManager.self) private var downloadManager
    let category: TaskCategory
    @Binding var selectedTaskIds: Set<String>
    @Binding var isInspectorPresented: Bool

    @State private var searchText = ""
    @State private var sortOrder: SortOrder = .dateAdded
    @State private var showThoroughDeleteAlert = false
    @State private var deleteFiles = false
    @State private var rememberChoice = false
    @State private var lastSelectedId: String? // Track last selection for Shift-click logic

    private var filteredTasks: [DownloadTask] {
        let categoryTasks = downloadManager.tasks.filter { task in
            category.aria2Status.contains(task.status)
        }

        if searchText.isEmpty {
            return categoryTasks.sorted(by: sortOrder)
        }

        return
            categoryTasks
            .filter { $0.name.localizedCaseInsensitiveContains(searchText) }
            .sorted(by: sortOrder)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with search and sort
            TaskListHeader(
                category: category,
                taskCount: filteredTasks.count,
                searchText: $searchText,
                sortOrder: $sortOrder
            )
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            Divider()
                .padding(.horizontal, 20)

            // Task list
            if !downloadManager.isConnected {
                // Startup / Connecting State
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.regular)
                    Text("Starting download engine...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredTasks.isEmpty {
                EmptyTaskListView(category: category)
            } else {
                GeometryReader { geometry in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(filteredTasks) { task in
                                TaskItemView(
                                    task: task,
                                    isSelected: selectedTaskIds.contains(task.id),
                                    onShowInfo: {
                                        if !selectedTaskIds.contains(task.id) {
                                            selectedTaskIds = [task.id]
                                        }
                                        withAnimation(.spring(duration: 0.25)) {
                                            isInspectorPresented = true
                                        }
                                    }
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    handleTap(task: task)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                        }
                        .frame(minHeight: geometry.size.height, alignment: .top)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedTaskIds.removeAll()
                            lastSelectedId = nil
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .focusable()
                    .focusEffectDisabled()
                }
            }
        }
        .background(.background.opacity(0.5))
        .onDeleteCommand {
            guard !selectedTaskIds.isEmpty else { return }
            let tasksToDelete = downloadManager.tasks.filter { selectedTaskIds.contains($0.id) }
            
            Task {
                for t in tasksToDelete {
                    await downloadManager.deleteTask(t, withFiles: false)
                }
                selectedTaskIds.removeAll()
            }
        }
        .background {
            // Select All (Cmd+A)
            Button("") {
                selectedTaskIds = Set(filteredTasks.map { $0.id })
            }
            .keyboardShortcut("a", modifiers: .command)
            .hidden()
            
            // Delete Shortcuts
            Button("") {
                deleteSelectedTasks(withFiles: false)
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
        .sheet(isPresented: $showThoroughDeleteAlert) {
            DeleteConfirmationSheet(
                taskName: selectedTaskIds.count == 1 
                    ? (filteredTasks.first(where: { $0.id == selectedTaskIds.first })?.name ?? "1 个任务")
                    : "\(selectedTaskIds.count) 个任务",
                deleteFiles: $deleteFiles,
                rememberChoice: $rememberChoice,
                onConfirm: {
                    if rememberChoice {
                        downloadManager.skipDeleteConfirmation = true
                        downloadManager.deleteWithFilesDefault = deleteFiles
                    }
                    deleteSelectedTasks(withFiles: deleteFiles)
                    showThoroughDeleteAlert = false
                },
                onCancel: {
                    showThoroughDeleteAlert = false
                }
            )
        }
    }

    private func handleTap(task: DownloadTask) {
        let isCommandPressed = NSEvent.modifierFlags.contains(.command)
        let isShiftPressed = NSEvent.modifierFlags.contains(.shift)

        if isShiftPressed, let lastId = lastSelectedId, let lastIndex = filteredTasks.firstIndex(where: { $0.id == lastId }), let currentIndex = filteredTasks.firstIndex(where: { $0.id == task.id }) {
            // Range selection
            let range = min(lastIndex, currentIndex)...max(lastIndex, currentIndex)
            let tasksInRange = filteredTasks[range]
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
        
        withAnimation(.spring(duration: 0.25)) {
             // Animate layout changes if any
        }
    }

    private func deleteSelectedTasks(withFiles: Bool) {
        guard !selectedTaskIds.isEmpty else { return }
        let tasksToDelete = downloadManager.tasks.filter { selectedTaskIds.contains($0.id) }
        
        Task {
            for t in tasksToDelete {
                await downloadManager.deleteTask(t, withFiles: withFiles)
            }
            // Clear selection after delete
            selectedTaskIds.removeAll()
            lastSelectedId = nil
        }
    }
}

// MARK: - Task List Header

struct TaskListHeader: View {
    @Environment(DownloadManager.self) private var downloadManager
    let category: TaskCategory
    let taskCount: Int
    @Binding var searchText: String
    @Binding var sortOrder: SortOrder

    @State private var showClearConfirmation = false

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

                // Clear All button for completed tasks
                if category == .completed && taskCount > 0 {
                    Button {
                        showClearConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.body.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .frame(width: 24)
                    .help("全部清除")
                    .alert("确认清除所有已完成任务？", isPresented: $showClearConfirmation) {
                        Button("取消", role: .cancel) {}
                        Button("确认清除", role: .destructive) {
                            Task { await downloadManager.clearAllStopped() }
                        }
                    } message: {
                        Text("此操作将仅从列表中移除任务记录，不会删除您的本地文件。")
                    }
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
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
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
