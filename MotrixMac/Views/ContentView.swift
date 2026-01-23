import AppKit
import Observation
import SwiftUI

/// Main content view with Liquid Glass three-column navigation
struct MainContentView: View {
    @Environment(DownloadManager.self) private var downloadManager
    @State private var selectedCategory: TaskCategory = .downloading
    @State private var selectedTaskIds: Set<String> = []
    // State for the main split view (Sidebar + Content)
    @State private var sidebarVisibility: NavigationSplitViewVisibility = .all
    @State private var isInspectorPresented: Bool = false
    @AppStorage("showInDock") private var showInDock = true

    var body: some View {
        @Bindable var manager = downloadManager

        // Outer SplitView for Sidebar and Main Content
        NavigationSplitView(columnVisibility: $sidebarVisibility) {
            // Sidebar
            SidebarView(selectedCategory: $selectedCategory)
                .navigationSplitViewColumnWidth(min: 220, ideal: 220, max: 280)
        } detail: {
            // Content Area - show settings or task list
            if selectedCategory == .settings {
                // Embedded settings view
                EmbeddedPreferencesView()
                    .environment(downloadManager)
            } else if selectedCategory == .about {
                // Embedded about view
                AboutView()
            } else {
                // Task List + Detail Area
                ZStack(alignment: .trailing) {
                    // Base Layer: Task List (Full Width)
                    TaskListView(
                        category: selectedCategory,
                        selectedTaskIds: $selectedTaskIds,
                        isInspectorPresented: $isInspectorPresented
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // Overlay Layer: Dismiss Barrier & Detail View
                    if isInspectorPresented,
                        !selectedTaskIds.isEmpty,
                        let taskId = selectedTaskIds.first,
                        let task = downloadManager.tasks.first(where: { $0.id == taskId })
                    {
                        // Dismiss Barrier: Catches clicks outside the detail pane
                        Color.black.opacity(0.01)
                            .onTapGesture {
                                withAnimation(.smooth(duration: 0.2)) {
                                    selectedTaskIds.removeAll()
                                }
                            }
                        
                        // Detail View
                        TaskDetailView(task: task)
                            .frame(width: 400)
                            .background(.thickMaterial)
                            .overlay(alignment: .topLeading) {
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
                                .padding(.top, 20)
                                .padding(.leading, 12)
                            }
                            .transition(.move(edge: .trailing))
                            .zIndex(1)
                    }
                }
            }
        }
        .onChange(of: selectedTaskIds) { oldValue, newValue in
            // Auto-close inspector if nothing is selected
            if newValue.isEmpty {
                withAnimation(.smooth(duration: 0.2)) {
                    isInspectorPresented = false
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSettings)) { _ in
            selectedCategory = .settings
            sidebarVisibility = .all
        }
        // Note: .glassEffectContainer() will be available in macOS 26 SDK
        // For now, using standard styling
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                ToolbarButtons()
            }
            
            ToolbarItem(placement: .confirmationAction) {
                ToolbarSpeedIndicator()
            }
        }
        .sheet(isPresented: $manager.showAddTaskSheet) {
            AddTaskSheet()
                .environment(downloadManager)
        }
        .sheet(isPresented: $manager.showAddTorrentSheet) {
            AddTorrentSheet()
                .environment(downloadManager)
        }
        .onAppear {
            Task {
                await downloadManager.connect()
            }
        }
    }
}

// MARK: - Toolbar Content

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
