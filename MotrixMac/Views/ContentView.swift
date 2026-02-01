import AppKit
import Observation
import SwiftUI

/// Main content view with Liquid Glass three-column navigation
struct MainContentView: View {
    @Environment(DownloadManager.self) private var downloadManager
    @State private var selectedTaskIds: Set<String> = []
    @State private var settingsTab: EmbeddedSettingsTab = .general
    @Namespace private var settingsNamespace
    
    // State for the main split view (Sidebar + Content)
    @State private var sidebarVisibility: NavigationSplitViewVisibility = .all
    @AppStorage("showInDock") private var showInDock = true
    @State private var isInspectorPresented: Bool = false
    @AppStorage("theme") private var appTheme = "auto"

    var body: some View {
        @Bindable var manager = downloadManager

        NavigationSplitView(columnVisibility: $sidebarVisibility) {
            // Sidebar
            SidebarView(selectedCategory: $manager.currentCategory)
                .navigationSplitViewColumnWidth(min: 220, ideal: 220, max: 280)
        } detail: {
            detailContent()
                .toolbar {
                    if downloadManager.currentCategory == .settings {
                        ToolbarItem(placement: .principal) {
                            LiquidSettingsPicker(selection: $settingsTab)
                        }
                    } else {
                        // Use .navigation to push items to the right and avoid ghost separators
                        ToolbarItem(placement: .navigation) {
                            Spacer()
                        }
                    }
                    
                    ToolbarItemGroup(placement: .primaryAction) {
                        ToolbarButtons()
                        ToolbarSpeedIndicator()
                    }
                }
        }
        .preferredColorScheme(appTheme == "auto" ? nil : (appTheme == "dark" ? .dark : .light))
        .id(appTheme) // Force full rebuild on theme setting change
        .onAppear {
            applyTheme(appTheme)
            Task {
                await downloadManager.connect()
            }
        }
        .onChange(of: appTheme) { _, newValue in
            applyTheme(newValue)
        }
        .onChange(of: selectedTaskIds) { oldValue, newValue in
            // Auto-close inspector if nothing is selected
            if newValue.isEmpty {
                withAnimation(.smooth(duration: 0.2)) {
                    isInspectorPresented = false
                }
            }
        }
        .onChange(of: downloadManager.tasks) { oldTasks, newTasks in
            // Auto-close inspector if the selected task completes (transitions to "complete")
            guard isInspectorPresented,
                  let selectedId = selectedTaskIds.first,
                  let newTask = newTasks.first(where: { $0.id == selectedId }),
                  newTask.status == "complete"
            else { return }

            // Ensure it wasn't already complete (allows viewing history items)
            if let oldTask = oldTasks.first(where: { $0.id == selectedId }),
               oldTask.status != "complete"
            {
                withAnimation(.smooth(duration: 0.2)) {
                    isInspectorPresented = false
                    // We also deselect it to reset the state completely, matching the "dismiss" behavior
                    selectedTaskIds.removeAll()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSettings)) { _ in
            downloadManager.currentCategory = .settings
            sidebarVisibility = .all
        }
        .onChange(of: downloadManager.shouldResetNavigation) { _, newValue in
            if newValue {
                downloadManager.currentCategory = .downloading
                downloadManager.shouldResetNavigation = false
            }
        }
        .sheet(isPresented: $manager.showAddTaskSheet) {
            AddTaskSheet().environment(downloadManager)
        }
        .sheet(isPresented: $manager.showAddTorrentSheet) {
            AddTorrentSheet().environment(downloadManager)
        }
    }

    @ViewBuilder
    private func detailContent() -> some View {
        switch downloadManager.currentCategory {
        case .settings:
            EmbeddedPreferencesView(activeTab: $settingsTab)
                .environment(downloadManager)
        case .about:
            NavigationStack {
                AboutView()
            }
        default:
            taskListWithInspector()
        }
    }

    @ViewBuilder
    private func taskListWithInspector() -> some View {
        ZStack(alignment: .trailing) {
            TaskListView(
                category: downloadManager.currentCategory,
                selectedTaskIds: $selectedTaskIds,
                isInspectorPresented: $isInspectorPresented
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if isInspectorPresented,
                let taskId = selectedTaskIds.first,
                let task = downloadManager.tasks.first(where: { $0.id == taskId })
            {
                inspectorOverlay(for: task)
            }
        }
    }

    @ViewBuilder
    private func inspectorOverlay(for task: DownloadTask) -> some View {
        Color.black.opacity(0.01)
            .onTapGesture {
                withAnimation(.smooth(duration: 0.2)) {
                    selectedTaskIds.removeAll()
                }
            }
            .transition(.opacity)
        
        ZStack(alignment: .topLeading) {
            let cachedImage = task.files.first?.path.isEmpty == false 
                ? QuickLookManager.shared.getCachedImage(for: URL(fileURLWithPath: task.files.first!.path)) 
                : nil
                
            TaskDetailView(task: task, initialThumbnail: cachedImage)
                .frame(width: 400)
                .frame(maxHeight: .infinity)
                .background(.ultraThinMaterial)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(Color.primary.opacity(0.05))
                        .frame(width: 1)
                }
                .shadow(color: .black.opacity(0.08), radius: 15, x: -5, y: 0)
            
            Button {
                withAnimation(.smooth(duration: 0.2)) {
                    isInspectorPresented = false
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
            .padding(.leading, 12)
        }
        .compositingGroup()
        .transition(.move(edge: .trailing))
        .zIndex(1)
    }

    private func applyTheme(_ theme: String) {
        DispatchQueue.main.async {
            switch theme {
            case "dark":
                NSApp.appearance = NSAppearance(named: .darkAqua)
            case "light":
                NSApp.appearance = NSAppearance(named: .aqua)
            default:
                NSApp.appearance = nil
            }
        }
    }
}

// MARK: - Toolbar Content

struct ToolbarButtons: View {
    @Environment(DownloadManager.self) private var downloadManager
    @AppStorage("settingsAreDirty") private var settingsAreDirty = false

    var body: some View {
        Button {
            downloadManager.showAddTaskSheet = true
        } label: {
            Label("Add Download", systemImage: "plus")
        }
        .help("Add new download (⌘N)")

        Button {
            Task { await downloadManager.refreshTasks() }
        } label: {
            Label("Refresh", systemImage: "arrow.clockwise")
        }
        .help("Refresh task list")
        
        if settingsAreDirty {
            Button {
                NotificationCenter.default.post(name: .saveSettings, object: nil)
            } label: {
                Label("Save Settings", systemImage: "checkmark.circle.fill")
            }
            .help("保存设置")
        }
    }
}

struct ToolbarSpeedIndicator: View {
    @Environment(DownloadManager.self) private var downloadManager

    var body: some View {
        // Global speed display
        HStack(spacing: 4) {
            Image(systemName: "arrow.down")
                .foregroundStyle(.green)
            Text(downloadManager.totalDownloadSpeed.formatted(.byteCount(style: .file)) + "/s")
                .monospacedDigit()

            Image(systemName: "arrow.up")
                .foregroundStyle(.blue)
            Text(downloadManager.totalUploadSpeed.formatted(.byteCount(style: .file)) + "/s")
                .monospacedDigit()
        }
        .font(.caption)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}

// MARK: - Empty State

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.down.doc")
                .font(.system(size: 64))
                .foregroundStyle(.tertiary)

            Text("未选择任务")
                .font(.title2)
                .foregroundStyle(.secondary)

            Text("从列表中选择一个下载任务以查看详情")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    MainContentView()
        .environment(DownloadManager.shared)
        .frame(width: 1024, height: 700)
}
