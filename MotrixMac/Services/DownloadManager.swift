import AppKit
import Foundation
import Observation
import UserNotifications

/// Central download manager using aria2 RPC
@Observable
final class DownloadManager {
    static let shared = DownloadManager()

    // Published state
    var tasks: [DownloadTask] = []
    var isConnected = false
    var connectionError: String?
    var lastRpcError: String? = nil

    // UI state
    var showAddTaskSheet = false
    var showAddTorrentSheet = false
    var showAboutPanel = false

    // Deletion preferences
    var deleteWithFilesDefault: Bool {
        get { UserDefaults.standard.bool(forKey: "deleteWithFilesDefault") }
        set { UserDefaults.standard.set(newValue, forKey: "deleteWithFilesDefault") }
    }
    var skipDeleteConfirmation: Bool {
        get { UserDefaults.standard.bool(forKey: "skipDeleteConfirmation") }
        set { UserDefaults.standard.set(newValue, forKey: "skipDeleteConfirmation") }
    }

    // Computed properties
    var activeDownloads: [DownloadTask] {
        tasks.filter { ["active", "waiting", "paused"].contains($0.status) }
    }

    var totalDownloadSpeed: Int64 {
        activeDownloads.reduce(0) { $0 + $1.downloadSpeed }
    }

    var totalUploadSpeed: Int64 {
        activeDownloads.reduce(0) { $0 + $1.uploadSpeed }
    }

    // Private
    private var aria2Service: Aria2Service?
    private var refreshTask: Task<Void, Never>?
    private var speedHistoryCache: [String: [Int64]] = [:]

    private init() {
        requestNotificationPermission()
        loadSpeedHistory()
    }
    
    // MARK: - Persistence
    
    private func loadSpeedHistory() {
        if let data = UserDefaults.standard.data(forKey: "speedHistoryCache"),
           let cache = try? JSONDecoder().decode([String: [Int64]].self, from: data) {
            self.speedHistoryCache = cache
        }
    }
    
    private func saveSpeedHistory() {
        if let data = try? JSONEncoder().encode(speedHistoryCache) {
            UserDefaults.standard.set(data, forKey: "speedHistoryCache")
        }
    }

    // MARK: - Connection

    func connect() async {
        // Prevent multiple connections
        // If we are already connected, just perform a health check
        if isConnected {
            do {
                _ = try await aria2Service?.getVersion()
                print("Already connected and healthy, skipping")
                return
            } catch {
                print("Connection lost, reconnecting...")
                isConnected = false
            }
        }
        
        // Ensure any existing loops are stopped and errors cleared
        connectionError = nil
        lastRpcError = nil
        await disconnect()

        // Retry logic for connection (Wait for aria2 to start)
        for i in 0..<10 {
            // Read from UserDefaults - STRICTLY follow configured port
            // We removed dynamic port switching to ensure Browser Extension compatibility
            var port = UserDefaults.standard.integer(forKey: "rpcPort")
            if port == 0 {
                port = 16800
            }
            
            // ALWAYS reload secret fresh from disk in case EngineProcess updated it
            let secret = UserDefaults.standard.string(forKey: "rpcSecret") ?? ""
            
            let maskedSecret = secret.count >= 8 ? 
                "\(secret.prefix(2))...\(secret.suffix(2))" : 
                (secret.isEmpty ? "empty" : "too short")
            
            print("DownloadManager: Attempt \(i + 1)/10 - Port: \(port), Secret: \(maskedSecret)")

            // Create new service
            let newService = Aria2Service(
                host: "127.0.0.1",
                port: port,
                secret: secret
            )
            self.aria2Service = newService

            do {
                try await newService.connect()
                
                // CRITICAL: Verify the secret works before declaring victory
                _ = try await newService.checkAuth()
                
                await MainActor.run {
                    self.isConnected = true
                    self.connectionError = nil
                    self.lastRpcError = nil
                }
                
                await newService.setOnNotification { [weak self] method, params in
                    Task { @MainActor [weak self] in
                        self?.handleNotification(method: method, params: params)
                    }
                }
                startAutoRefresh()
                print("DownloadManager: Successfully connected and authenticated on attempt \(i + 1)")
                return
            } catch {
                print("DownloadManager: Connection attempt \(i + 1) failed: \(error)")
                
                await MainActor.run {
                    // Update error state immediately so UI reacts
                    if let rpcError = error as? Aria2Error {
                        if case .rpcError(let msg) = rpcError {
                            self.lastRpcError = msg
                        }
                    }
                    
                    if i == 9 {
                        self.connectionError = error.localizedDescription
                        self.isConnected = false
                        print("DownloadManager: Failed to connect to aria2 after 10 attempts: \(error)")
                    }
                }

                if i < 9 {
                    // Wait before retrying - Increase to 1.0s to give engine more boot time
                    try? await Task.sleep(for: .milliseconds(1000))
                }
            }
        }
    }

    func disconnect() async {
        refreshTask?.cancel()
        refreshTask = nil
        
        await aria2Service?.disconnect()
        // Don't nil out aria2Service immediately if we want to keep it? 
        // Actually fine to keep simple.
        isConnected = false
    }

    // MARK: - Task Management

    func refreshTasks() async {
        guard let service = aria2Service else { return }

        do {
            let active = try await service.tellActive()
            let waiting = try await service.tellWaiting(offset: 0, num: 100)
            let stopped = try await service.tellStopped(offset: 0, num: 100)

            let newTasks = active + waiting + stopped
            
            if !newTasks.isEmpty {
                print("DownloadManager: Refreshed \(newTasks.count) tasks (Active: \(active.count), Waiting: \(waiting.count), Stopped: \(stopped.count))")
                for task in newTasks {
                    print("  - Task: \(task.name), GID: \(task.id), Status: \(task.status), Progress: \(String(format: "%.2f", task.progress * 100))%")
                }
            }

            await MainActor.run {
                self.tasks = newTasks.map { newTask in
                    var task = newTask
                    
                    // 1. Restore from cache if available
                    if let cachedHistory = self.speedHistoryCache[newTask.id] {
                        task.downloadSpeedHistory = cachedHistory
                    }
                    
                    // 2. Update with new real-time data if active
                    if newTask.status == "active" {
                        var history = task.downloadSpeedHistory
                        history.append(newTask.downloadSpeed)
                        
                        // Limit history size
                        if history.count > 100 {
                            history.removeFirst()
                        }
                        
                        task.downloadSpeedHistory = history
                        
                        // Update cache
                        self.speedHistoryCache[newTask.id] = history
                    }
                    
                    return task
                }
                
                self.saveSpeedHistory()
                self.lastRpcError = nil
                
                // Monitor task list state
                let downloadingCount = self.taskCount(for: .downloading)
                let completedCount = self.taskCount(for: .completed)
                print("DownloadManager: UI State - Downloading: \(downloadingCount), Completed: \(completedCount)")
            }
        } catch {
            if let rpcError = error as? Aria2Error {
                if case .rpcError(let msg) = rpcError {
                    self.lastRpcError = msg
                }
            }
            print("DownloadManager: Failed to refresh tasks: \(error)")
        }
    }
    
    func taskCount(for category: TaskCategory) -> Int {
        tasks.filter { category.aria2Status.contains($0.status) }.count
    }

    func addDownload(uri: String, options: [String: Any]) async throws {
        guard let service = aria2Service else { throw DownloadError.notConnected }
        
        // Deduplication: Check if we already have this URI in active/waiting/paused
        // Note: This is a simple check. Aria2 might normalize URIs, but this catches exact matches from extension.
        let isDuplicate = tasks.contains { task in
            ["active", "waiting", "paused"].contains(task.status) && task.uri == uri
        }
        
        if isDuplicate {
            print("DownloadManager: Duplicate URI ignored: \(uri)")
            return
        }
        
        _ = try await service.addUri(uris: [uri], options: options)
        await refreshTasks()
    }

    func addTorrent(base64: String, options: [String: Any]) async throws {
        guard let service = aria2Service else { throw DownloadError.notConnected }
        _ = try await service.addTorrent(torrent: base64, options: options)
        await refreshTasks()
    }

    func pauseTask(_ task: DownloadTask) async {
        guard let service = aria2Service else { return }
        do {
            try await service.pause(gid: task.id)
            await refreshTasks()
        } catch {
            print("Failed to pause task: \(error)")
        }
    }

    func resumeTask(_ task: DownloadTask) async {
        guard let service = aria2Service else { return }
        do {
            try await service.unpause(gid: task.id)
            await refreshTasks()
        } catch {
            print("Failed to resume task: \(error)")
        }
    }
    
    func retryTask(_ task: DownloadTask) async {
        if task.status == "removed" || task.status == "error" {
            // For removed or error tasks, we try to re-add them
            guard !task.uri.isEmpty else { return }
            
            let options: [String: Any] = [
                "dir": task.dir
            ]
            
            _ = try? await addDownload(uri: task.uri, options: options)
            // Then remove the old result so it doesn't clutter
            await deleteTask(task)
        } else {
            await resumeTask(task)
        }
    }

    func cancelTask(_ task: DownloadTask) async {
        guard let service = aria2Service else { return }
        do {
            // Just remove, it moves to stopped list (Cancelled)
            try await service.remove(gid: task.id)
            await refreshTasks()
        } catch {
            print("Failed to cancel task: \(error)")
        }
    }

    func deleteTask(_ task: DownloadTask, withFiles: Bool = false) async {
        guard let service = aria2Service else { return }
        
        // Instant UI Removal: Remove from local list immediately
        await MainActor.run {
            if let index = self.tasks.firstIndex(where: { $0.id == task.id }) {
                self.tasks.remove(at: index)
            }
        }
        
        do {
            // Always try to remove from active/waiting/paused first
            if ["active", "waiting", "paused"].contains(task.status) {
                try? await service.remove(gid: task.id)
            }
            
            // ALWAYS remove download result to ensure it's gone from UI
            try await service.removeDownloadResult(gid: task.id)

            if withFiles {
                deleteFiles(for: task)
            }

            // We don't need to await refreshTasks() here because we already removed it locally.
            // But doing it ensures consistency with the engine state eventually.
            // We can spawn it detached or just let the auto-refresh catch it.
            // For safety, let's call it but not wait on it for the UI update.
            Task { await refreshTasks() }
        } catch {
            print("Failed to delete task: \(error)")
            // If failed, we might want to add it back? But usually better to force sync.
            await refreshTasks()
        }
    }

    func clearAllStopped() async {
        guard let service = aria2Service else { return }
        let stoppedStatuses = ["complete", "removed", "error"]
        let stoppedTasks = tasks.filter { stoppedStatuses.contains($0.status) }

        for task in stoppedTasks {
            do {
                try await service.removeDownloadResult(gid: task.id)
            } catch {
                print("Failed to remove stopped task result: \(error)")
            }
        }
        await refreshTasks()
    }

    func pauseAll() async {
        guard let service = aria2Service else { return }
        do {
            try await service.pauseAll()
            await refreshTasks()
        } catch {
            print("Failed to pause all: \(error)")
        }
    }

    func resumeAll() async {
        guard let service = aria2Service else { return }
        do {
            try await service.unpauseAll()
            await refreshTasks()
        } catch {
            print("Failed to resume all: \(error)")
        }
    }

    // MARK: - File Operations

    func revealInFinder(_ task: DownloadTask) {
        let path = task.dir + "/" + task.name
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func openFile(_ task: DownloadTask) {
        let path = task.dir + "/" + task.name
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.open(url)
    }

    private func deleteFiles(for task: DownloadTask) {
        let path = task.dir + "/" + task.name
        let url = URL(fileURLWithPath: path)
        try? FileManager.default.trashItem(at: url, resultingItemURL: nil)
    }

    // MARK: - Auto Refresh

    private func startAutoRefresh() {
        // Cancel existing task to prevent leaks
        refreshTask?.cancel()
        
        refreshTask = Task {
            print("DownloadManager: Starting auto-refresh loop")
            while !Task.isCancelled {
                // Check cancellation at start of loop
                if Task.isCancelled { break }
                
                await refreshTasks()

                // Adaptive polling:
                // If there are active downloads/tasks, refresh faster (1s)
                // If idle, refresh slower (3s) to save CPU
                let hasActiveTasks = !activeDownloads.isEmpty || !tasks.filter({ $0.status == "waiting" }).isEmpty
                let sleepDuration: UInt64 = hasActiveTasks ? 1_000_000_000 : 3_000_000_000 // 1s vs 3s

                do {
                    try await Task.sleep(nanoseconds: sleepDuration)
                } catch {
                    // Task cancelled
                    print("DownloadManager: Refresh loop cancelled")
                    break 
                }
            }
            print("DownloadManager: Auto-refresh loop exited")
        }
    }

    // MARK: - Notifications

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) {
            granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }

    private func handleNotification(method: String, params: [Any]) {
        // Refresh tasks on any relevant event
        Task {
            await refreshTasks()

            // Handle specific events for notifications
            if method == "aria2.onDownloadComplete" || method == "aria2.onBtDownloadComplete" {
                if let firstParam = params.first as? [String: Any],
                    let gid = firstParam["gid"] as? String
                {
                    // We need to fetch the task to get its name
                    // Since we just called refreshTasks(), we might be able to find it in the new list,
                    // but refreshTasks is async and might race. Safer to fetch specific task status.
                    if let task = try? await aria2Service?.tellStatus(gid: gid) {
                        sendNotification(title: "下载完成", body: "\(task.name) 已下载完成")
                    }
                }
            } else if method == "aria2.onDownloadError" {
                if let firstParam = params.first as? [String: Any],
                    let gid = firstParam["gid"] as? String
                {
                    if let task = try? await aria2Service?.tellStatus(gid: gid) {
                        let errorMessage = task.errorMessage ?? "未知错误"
                        print("DownloadManager: Task \(task.name) (GID: \(gid)) failed: \(errorMessage)")
                        sendNotification(title: "下载失败", body: "\(task.name) 下载失败: \(errorMessage)")
                    }
                }
            }
        }
    }

    private func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - Errors

enum DownloadError: LocalizedError {
    case notConnected
    case invalidResponse
    case rpcError(String)

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Not connected to aria2 engine"
        case .invalidResponse:
            return "Invalid response from aria2"
        case .rpcError(let message):
            return "RPC Error: \(message)"
        }
    }
}
