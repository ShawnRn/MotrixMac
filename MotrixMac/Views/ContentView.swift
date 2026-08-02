import AppKit
import Observation
import SwiftUI
import UniformTypeIdentifiers

/// Main content view with Liquid Glass three-column navigation
struct MainContentView: View {
    @Environment(DownloadManager.self) private var downloadManager
    @State private var selectedTaskIds: Set<String> = []
    @State private var settingsTab: EmbeddedSettingsTab = .general
    @Namespace private var settingsNamespace
    
    // Notification extensions consolidated in MotrixMacApp.swift
    @State private var sidebarVisibility: NavigationSplitViewVisibility = .all
    @AppStorage("showInDock") private var showInDock = true
    @State private var isInspectorPresented: Bool = false
    @AppStorage("theme") private var appTheme = "auto"
    @AppStorage("language") private var language = "zh-CN"
    
    // For navigation guard
    @State private var showingSettingsGuard = false
    @State private var pendingCategory: TaskCategory?
    @AppStorage("settingsAreDirty") private var settingsAreDirty = false
    
    // For smart transitions
    @State private var previousCategory: TaskCategory = .downloading

    var body: some View {
        @Bindable var manager = downloadManager

        NavigationSplitView(columnVisibility: $sidebarVisibility) {
            // Sidebar
            SidebarView(selectedCategory: manager.currentCategory) { category in
                handleCategorySelection(category)
            }
                .navigationSplitViewColumnWidth(min: 220, ideal: 220, max: 280)
        } detail: {
            detailContent()
                .toolbar {
                    if downloadManager.currentCategory == .settings {
                        ToolbarItem(placement: .principal) {
                            LiquidSettingsPicker(selection: $settingsTab, namespace: settingsNamespace)
                        }
                    } else {
                        // Use .navigation to push items to the right and avoid ghost separators
                        ToolbarItem(placement: .navigation) {
                            Spacer()
                        }
                    }
                    
                    ToolbarItem(placement: .primaryAction) {
                        ToolbarContent()
                    }
                }
        }
        .preferredColorScheme(appTheme == "auto" ? nil : (appTheme == "dark" ? .dark : .light))
        .id(appTheme) // Force full rebuild on theme setting change
        .onAppear {
            applyTheme(appTheme)
            NotificationCenter.default.post(name: .mainInterfaceDidAppear, object: nil)
            Task {
                await downloadManager.connect()
            }
        }
        .onChange(of: appTheme) { _, newValue in
            applyTheme(newValue)
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers)
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
        .background(MainWindowAccessor())
        .onChange(of: downloadManager.shouldResetNavigation) { _, newValue in

            if newValue {
                downloadManager.currentCategory = .downloading
                downloadManager.shouldResetNavigation = false
            }
        }
        .onChange(of: downloadManager.currentCategory) { old, newValue in
            // Track previous category for transitions
            previousCategory = old
            
            // Close inspector and clear selection when switching categories
            if old != newValue {
                withAnimation(.smooth(duration: 0.2)) {
                    isInspectorPresented = false
                    selectedTaskIds.removeAll()
                }
            }
            
            // Reset settings tab to general whenever we switch to settings
            if newValue == .settings {
                settingsTab = .general
            }
        }
        .alert("设置未保存".localized(for: language), isPresented: $showingSettingsGuard) {
            Button("应用并离开".localized(for: language)) {
                NotificationCenter.default.post(name: .saveSettings, object: nil)
                if let category = pendingCategory {
                    switchCategory(category)
                }
            }
            Button("放弃修改".localized(for: language), role: .destructive) {
                NotificationCenter.default.post(name: .discardSettings, object: nil)
                if let category = pendingCategory {
                    switchCategory(category)
                }
            }
            Button("取消".localized(for: language), role: .cancel) {
                pendingCategory = nil
            }
        } message: {
            Text("您在设置页面有未保存的更改。离开前是否应用这些更改？".localized(for: language))
        }
        .sheet(isPresented: $manager.showAddTaskSheet) {
            AddTaskSheet().environment(downloadManager)
        }
        .sheet(isPresented: $manager.showAddTorrentSheet) {
            AddTorrentSheet().environment(downloadManager)
        }
    }

    private func handleCategorySelection(_ category: TaskCategory) {
        if downloadManager.currentCategory == .settings && settingsAreDirty && category != .settings {
            pendingCategory = category
            showingSettingsGuard = true
        } else {
            switchCategory(category)
        }
    }

    private func switchCategory(_ category: TaskCategory) {
        if downloadManager.currentCategory != category {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                downloadManager.currentCategory = category
            }
        }
    }

    @ViewBuilder
    private func detailContent() -> some View {
        let current = downloadManager.currentCategory
        let isCrossGroup = isCrossGroup(from: previousCategory, to: current)
        
        ZStack {
            switch current {
            case .settings:
                EmbeddedPreferencesView(activeTab: $settingsTab)
                    .environment(downloadManager)
                    .id("detail-settings")
            case .about:
                AboutView()
                    .id("detail-about")
            case .downloading:
                taskListWithInspector()
                    .id("detail-downloading")
            case .completed:
                taskListWithInspector()
                    .id("detail-completed")
            }
        }
        .transition(isCrossGroup ? crossGroupTransition : smoothTransition)
        .animation(.spring(response: 0.4, dampingFraction: 0.82), value: current)
    }

    private func isCrossGroup(from: TaskCategory, to: TaskCategory) -> Bool {
        let topGroup: Set<TaskCategory> = [.downloading, .completed]
        // If one is in top group and the other is not, it's a cross-group transition
        return topGroup.contains(from) != topGroup.contains(to)
    }

    private var smoothTransition: AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active: LiquidBlurModifier(radius: 12, opacity: 0),
                identity: LiquidBlurModifier(radius: 0, opacity: 1)
            ),
            removal: .modifier(
                active: LiquidBlurModifier(radius: 12, opacity: 0),
                identity: LiquidBlurModifier(radius: 0, opacity: 1)
            )
        )
    }

    private var crossGroupTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .leading).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
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
            .keyboardShortcut(.escape, modifiers: [])
            .padding(.top, 8)
            .padding(.leading, 12)
        }
        .compositingGroup()
        .transition(.move(edge: .trailing))
        .zIndex(1)
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        
        // We only care about file URLs
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            // Asynchronously load the URL
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url = url, url.pathExtension.lowercased() == "torrent" else { return }
                
                DispatchQueue.main.async {
                    // Activate app
                    NSApp.activate(ignoringOtherApps: true)
                    
                    // Trigger "Add Torrent" sheet
                    DownloadManager.shared.pendingTorrentURL = url
                    DownloadManager.shared.showAddTorrentSheet = true
                }
            }
            return true
        }
        
        return false
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

struct ToolbarContent: View {
    @Environment(DownloadManager.self) private var downloadManager
    @AppStorage("settingsAreDirty") private var settingsAreDirty = false
    @AppStorage("language") private var language = "zh-CN"

    var body: some View {
        HStack(spacing: 12) {
            // Action Buttons - Tight Spacing
            HStack(spacing: 0) {
                Button {
                    downloadManager.showAddTaskSheet = true
                } label: {
                    Label("添加下载".localized(for: language), systemImage: "plus")
                }
                .help("新建下载 (⌘N)".localized(for: language))

                Button {
                    Task { await downloadManager.refreshTasks() }
                } label: {
                    Label("刷新".localized(for: language), systemImage: "arrow.clockwise")
                }
                .help("刷新任务列表".localized(for: language))
                
                if settingsAreDirty && downloadManager.currentCategory == .settings {
                    Button {
                        NotificationCenter.default.post(name: .saveSettings, object: nil)
                    } label: {
                        Label("应用".localized(for: language), systemImage: "checkmark")
                    }
                    .help("应用设置")
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity).combined(with: .scale(scale: 0.8)),
                        removal: .scale(scale: 0.8).combined(with: .opacity)
                    ))
                }
            }
            
            // Speed Indicator (Restored Original Harmonious Spacing)
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down")
                        .foregroundStyle(.green)
                    Text(downloadManager.totalDownloadSpeed.formatted(.byteCount(style: .file)) + "/s")
                        .monospacedDigit()
                }

                HStack(spacing: 4) {
                    Image(systemName: "arrow.up")
                        .foregroundStyle(.blue)
                    Text(downloadManager.totalUploadSpeed.formatted(.byteCount(style: .file)) + "/s")
                        .monospacedDigit()
                }
            }
            .font(.caption)
        }
        .padding(.trailing, 8) // Prevent sticking to the edge
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: settingsAreDirty)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: downloadManager.currentCategory)
    }
}

// MARK: - Empty State

struct EmptyStateView: View {
    @AppStorage("language") private var language = "zh-CN"
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.down.doc")
                .font(.system(size: 64))
                .foregroundStyle(.tertiary)

            Text("未选择下载任务".localized(for: language))
                .font(.title2)
                .foregroundStyle(.secondary)

            Text("从列表中选择一个下载任务以查看详情".localized(for: language))
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

// MARK: - Transition Helpers

struct LiquidBlurModifier: ViewModifier {
    var radius: CGFloat
    var opacity: Double
    
    func body(content: Content) -> some View {
        content
            .blur(radius: radius)
            .opacity(opacity)
    }
}

// MARK: - Window Delegate & Accessor for Ghost Window Prevention

final class MainWindowDelegate: NSObject, NSWindowDelegate {
    static let shared = MainWindowDelegate()

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Order out (hide) the window instead of destroying it
        sender.orderOut(nil)
        return false // Cancel standard destroy behavior
    }
}

struct MainWindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                window.delegate = MainWindowDelegate.shared
                DownloadManager.shared.mainWindow = window
            }
        }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

