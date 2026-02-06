import AppKit
import Foundation
import Observation
import UserNotifications
import CryptoKit

/// Central download manager using aria2 RPC
@Observable @MainActor
final class DownloadManager {
    static let shared = DownloadManager()

    // Published state
    var tasks: [DownloadTask] = []
    var isConnected = false
    var connectionError: String?
    var lastRpcError: String? = nil
    var needsRepair = false // Signals persistent engine issues
    private var deletingGIDs: Set<String> = [] // Track tasks being deleted
    private var notifiedStartedGIDs: Set<String> = [] // Track tasks that have triggered speed notification
    private var persistentTasks: [String: DownloadTask] = [:] // Local storage for completed tasks

    // UI state
    var showAddTaskSheet = false
    var showAddTorrentSheet = false
    var showAboutPanel = false
    var shouldOpenMainWindow = false
    var shouldResetNavigation = false
    var pendingTorrentURL: URL? = nil  // For opening .torrent files from Finder

    // UI Filtering & Search (Scheme B)
    var searchText: String = "" { didSet { updateFilteredTasks() } }
    var sortOrder: SortOrder = .dateAdded { didSet { updateFilteredTasks() } }
    var currentCategory: TaskCategory = .downloading { didSet { updateFilteredTasks() } }
    private(set) var filteredTasks: [DownloadTask] = []

    // Static formatter to avoid recreation (Scheme A)
    private static let byteCountFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = .useAll
        formatter.countStyle = .file
        return formatter
    }()

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

    var aria2Process: EngineProcess? {
        (NSApplication.shared.delegate as? AppDelegate)?.aria2Process
    }
    
    // Private
    private var aria2Service: Aria2Service?
    private var refreshTask: Task<Void, Never>?
    private var speedHistoryCache: [String: [Int64]] = [:]
    private var taskDates: [String: Date] = [:] // Cache to store stable addedAt/completedAt dates

    private init() {
        requestNotificationPermission()
        loadSpeedHistory()
        loadPersistentTasks()
        
        // Start Tracker auto-sync in background
        Task {
            await TrackerService.shared.startAutoUpdate()
        }
        
        // Listen for tracker updates to hot-reload engine
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("TrackersDidUpdate"),
            object: nil,
            queue: .main
        ) { _ in
            Task {
                print("DownloadManager: Trackers updated, restarting engine to apply new trackers...")
                await self.restartEngine()
            }
        }
    }
    
    // MARK: - Persistence
    
    private func getPersistentTasksPath() -> URL? {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let motrixDir = appSupport?.appendingPathComponent("MotrixMac")
        return motrixDir?.appendingPathComponent("tasks.json")
    }

    private func loadPersistentTasks() {
        guard let path = getPersistentTasksPath(),
              FileManager.default.fileExists(atPath: path.path) else { return }
        
        do {
            let data = try Data(contentsOf: path)
            let tasks = try JSONDecoder().decode([String: DownloadTask].self, from: data)
            self.persistentTasks = tasks
            // Restore dates from persistence
            for (id, task) in tasks {
                self.taskDates[id] = task.addedAt
            }
            print("DownloadManager: Loaded \(tasks.count) persistent tasks")
        } catch {
            print("DownloadManager: Failed to load persistent tasks: \(error)")
        }
    }

    private func savePersistentTasks() {
        guard let path = getPersistentTasksPath() else { return }
        
        do {
            // Persist all known tasks to preserve their metadata (like addedAt)
            let data = try JSONEncoder().encode(persistentTasks)
            try data.write(to: path)
        } catch {
            print("DownloadManager: Failed to save persistent tasks: \(error)")
        }
    }
    
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
        for i in 0..<8 { // Reduced from 10 attempts
            // Read from UserDefaults - STRICTLY follow configured port
            // We removed dynamic port switching to ensure Browser Extension compatibility
            var port = UserDefaults.standard.integer(forKey: "rpcPort")
            if port == 0 {
                port = 12800
            }
            
            // ALWAYS reload secret fresh from disk in case EngineProcess updated it
            let secret = UserDefaults.standard.string(forKey: "rpcSecret") ?? ""
            
            print("DownloadManager: Attempt \(i + 1)/8 - Port: \(port), State: \(aria2Process?.state.rawValue ?? "unknown")")

            // FAST-FAIL: If engine reports failed, don't bother retrying RPC
            if let engine = aria2Process, engine.state == .failed {
                await MainActor.run {
                    self.connectionError = engine.lastErrorMessage ?? "引擎启动失败"
                    self.isConnected = false
                    self.needsRepair = true
                }
                return
            }

            // Create new service
            let newService = Aria2Service(
                host: "127.0.0.1",
                port: port,
                secret: secret
            )
            self.aria2Service = newService

            do {
                // Reduced timeout for initial connection verification
                try await newService.connect()
                
                // CRITICAL: Verify the secret works before declaring victory
                _ = try await newService.checkAuth()
                
                await MainActor.run {
                    self.isConnected = true
                    self.connectionError = nil
                    self.lastRpcError = nil
                    self.needsRepair = false
                }
                
                await newService.setOnNotification { [weak self] method, params in
                    Task { @MainActor [weak self] in
                        self?.handleNotification(method: method, params: params)
                    }
                }
                
                // [Sanitization] Purge legacy UDP tasks that might be causing loop errors
                await sanitizeSession()
                
                startAutoRefresh()
                Logger.info("DownloadManager: Successfully connected and authenticated on attempt \(i + 1)")
                aria2Process?.state = .running
                return
            } catch {
                if i == 7 { // Last attempt
                    Logger.error("DownloadManager: Connection attempt \(i + 1) failed: \(error)")
                    
                    // Logic to detect if it's a residual process (Connection Refused vs Auth Error)
                    // Note: Aria2Error.rpcError("Request timeout") usually happens when port is open but unresponsive
                    
                    await MainActor.run {
                        self.connectionError = error.localizedDescription
                        self.isConnected = false
                        self.needsRepair = true // Mark for global alert
                    }
                    await MainActor.run {
                        aria2Process?.state = .failed
                    }
                } else {
                    // Wait before retrying - FAST RETRY
                    try? await Task.sleep(for: .milliseconds(300))
                }
            }
        }
    }
    
    /// Definitive engine reset and repair
    func forceRepair() async {
        print("DownloadManager: Starting definitive force repair...")
        await MainActor.run {
            self.needsRepair = false
            self.connectionError = "正在执行引擎自愈程序..."
        }
        
        // Re-initiate engine process with full self-healing
        if let engine = aria2Process {
            engine.start() // start() now includes zombieScan + aggressiveCleanup
        }
        
        // Give the engine time to heal and start
        try? await Task.sleep(for: .milliseconds(1500))
        await connect()
    }

    func disconnect() async {
        disconnectSync()
        
        await aria2Service?.disconnect()
        // Don't nil out aria2Service immediately if we want to keep it? 
        // Actually fine to keep simple.
        isConnected = false
    }

    /// Synchronous disconnect for app termination
    func disconnectSync() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    // MARK: - Task Management

    func refreshTasks() async {
        guard let service = aria2Service, isConnected && !needsRepair else { return }
        
        // PAUSE refresh if engine is busy healing
        if let engine = aria2Process, engine.state != .running {
            return
        }

        do {
            var active = try await service.tellActive()
            let waiting = try await service.tellWaiting(offset: 0, num: 100)
            // Increase stopped limit to catch real tasks buried under "announce" phantoms
            let stopped = (try? await aria2Service?.tellStopped(offset: 0, num: 1000)) ?? []
        
        // --- Deduplication & Merging ---
            // Fetch peers for active BT tasks
            for i in active.indices {
                if active[i].isTorrent {
                    do {
                        let peers = try await service.getPeers(gid: active[i].id)
                        active[i].peers = peers
                    } catch {
                        // If peer detailed info fetch fails, it shouldn't crash active list refresh
                        // Specifically check for "GID not found" if needed, but for now ignoring is safe
                        // as the task itself was returned by tellActive
                    }
                }
            }

            var newTasks = active + waiting + stopped
            
            // [Fix] Deduplicate by GID immediately (in case a task moved between lists during calls)
            // This prevents "Duplicate values for key" crash later
            var seenGIDs = Set<String>()
            newTasks = newTasks.filter { seenGIDs.insert($0.id).inserted }
            
            // [Critical Fix] Filter out "announce" phantom tasks and auto-remove them to clean session
            // Extended criteria to catch all variants: announce, announce.php, /announce paths, tracker URIs
            let phantomTasks = newTasks.filter { task in
                let name = task.name.lowercased()
                let uri = task.uri.lowercased()
                return name == "announce" ||
                       name.contains("announce") ||
                       name.hasSuffix(".php") ||
                       uri.contains("/announce") ||
                       (task.totalLength == 0 && (name.hasPrefix("udp://") || name.hasPrefix("http://") && uri.hasSuffix("/announce")))
            }
            
            if !phantomTasks.isEmpty {
                let phantomIds = Set(phantomTasks.map { $0.id })
                newTasks.removeAll { phantomIds.contains($0.id) }
                
                // Aggressively remove them from the engine to clean up aria2.session
                // [Optimized] Throttle cleanup tasks to avoid storming the CPU
                // Only spawn a cleanup task if we aren't already cleaning a large batch,
                // or use a static/shared cleaner? 
                // For now, simpler: Just don't let the loop run wild.
                // We'll proceed with detached task but we rely on aria2 eventually responding.
                
                // Better approach: ONLY clean if not already cleaning?
                // But we need to clean THESE specific tasks.
                // Let's just launch it but log less and maybe throttle via random drop?
                // No, better to just let it run but ensure NO UI NOTIFICATIONS (already done).
                
                let tasksToRemove = phantomTasks // Capture for closure
                Task.detached {
                    // Reduce log spam
                    // Logger.info("DownloadManager: Background cleanup of \(tasksToRemove.count) phantom tasks")
                    for phantom in tasksToRemove {
                        // Ideally we try removeResult first as most are 'error' state
                        if (try? await service.removeDownloadResult(gid: phantom.id)) == nil {
                             _ = try? await service.forceRemove(gid: phantom.id)
                             _ = try? await service.removeDownloadResult(gid: phantom.id)
                        }
                    }
                }
            }
            
            if !newTasks.isEmpty {
                // Debug log reduced to only when count changes or very distinct events
                // print("DownloadManager: Refreshed \(newTasks.count) tasks...")
            }
            
            // [Critical Fix] Orphan Adoption: Reconcile GID changes (e.g. Magnet -> metadata -> new GID)
            // If aria2 has a task with NewGID, and we have a persistent task with OldGID but SAME infoHash,
            // we must adopt the new GID to maintain persistence and control.
            var persistentUpdatesMade = false
            for newTask in newTasks {
                if newTask.isTorrent, 
                   let infoHash = newTask.infoHash, !infoHash.isEmpty,
                   self.persistentTasks[newTask.id] == nil { // It's "new" to our storage
                    
                    // Search for a matching "orphan" in persistent storage
                    // (A task with same infoHash but different GID)
                    if let (oldGid, oldTask) = self.persistentTasks.first(where: { $0.value.infoHash == infoHash && $0.key != newTask.id }) {
                        print("DownloadManager: Adopting orphan task! infoHash: \(infoHash)")
                        print("  - Changing GID from \(oldGid) -> \(newTask.id)")
                        
                        // Remove old record
                        self.persistentTasks.removeValue(forKey: oldGid)
                        
                        // Add new record (preserve addedAt from old task if desired, or just use new)
                        var adoptedTask = newTask
                        adoptedTask.addedAt = oldTask.addedAt // Keep original add date
                        self.persistentTasks[newTask.id] = adoptedTask
                        
                        persistentUpdatesMade = true
                    }
                }
            }
            
            if persistentUpdatesMade {
                self.savePersistentTasks()
            }

                // [Fix] Use uniquingKeysWith to safely handle any residual duplicates in self.tasks (just in case)
                // Although self.tasks should be clean now, this is safer.
                let oldTasksMap = Dictionary(self.tasks.map { ($0.id, $0) }, uniquingKeysWith: { (_, last) in last })
                
                self.tasks = newTasks.compactMap { newTask -> DownloadTask? in
                    // Skip tasks that are currently being deleted to prevent ghosting
                    if self.deletingGIDs.contains(newTask.id) {
                        return nil
                    }
                    
                    var task = newTask
                    let oldTask = oldTasksMap[newTask.id]
                    
                    // 1. Restore speed history from cache if available
                    if let cachedHistory = self.speedHistoryCache[newTask.id] {
                        task.downloadSpeedHistory = cachedHistory
                    }
                    
                    // 2. Update with new real-time data if active
                    if newTask.status == "active" {
                        var history = task.downloadSpeedHistory
                        
                        // [New] Notify when speed appears (delayed start notification)
                        // [Critical Fix] Also check persistent status to prevent ghost notifications for completed tasks
                        if newTask.downloadSpeed > 0 && 
                           !self.notifiedStartedGIDs.contains(newTask.id) &&
                           (self.persistentTasks[newTask.id]?.status != "complete") {
                            self.notifiedStartedGIDs.insert(newTask.id)
                            self.sendNotification(title: "开始下载", body: "\(newTask.name) 速度: \(newTask.downloadSpeed.formatted(.byteCount(style: .file)))/s")
                        }
                        
                        // If this is the first time we see it active, prepend a 0 for a cleaner chart start
                        if history.isEmpty {
                            history.append(0)
                        }
                        
                        history.append(newTask.downloadSpeed)
                        
                        // Limit history size
                        if history.count > 100 {
                            history.removeFirst()
                        }
                        
                        task.downloadSpeedHistory = history
                        self.speedHistoryCache[newTask.id] = history
                    } 
                    // 2a. Handle completion transition: append 0 to show speed drop
                    else if newTask.status == "complete" {
                        var history = task.downloadSpeedHistory
                        
                        // Case A: Just transitioned from active to complete
                        if let old = oldTask, old.status == "active" {
                            if history.last != 0 {
                                history.append(0)
                            }
                        }
                        // Case B: Instant download (Discovered as complete with no history)
                        else if history.isEmpty && task.totalLength > 0 {
                            // Synthesize a spike [0, speed, 0] to show it actually downloaded something
                            // Since it was "instant", we can estimate a high speed relative to its size
                            let estimatedSpeed = task.totalLength // Assume it took ~1s if instant
                            history = [0, estimatedSpeed, 0]
                        }
                        
                        if history != task.downloadSpeedHistory {
                            task.downloadSpeedHistory = history
                            self.speedHistoryCache[newTask.id] = history
                        }
                    }
                    
                    // 2b. Restore Stable Date (addedAt)
                    if let cachedDate = self.taskDates[newTask.id] {
                        task.addedAt = cachedDate
                    } else {
                        // First time seeing this task.
                        // If we are discovering multiple new tasks in one batch, 
                        // stagger their addedAt dates by 1ms to maintain list order
                        let offset = Double(self.taskDates.count) * 0.001
                        let staggeredDate = Date().addingTimeInterval(offset)
                        task.addedAt = staggeredDate
                        self.taskDates[newTask.id] = staggeredDate
                    }

                    // 3. Persistent Storage logic:
                    // Persist all tasks to ensure addedAt remains consistent across restarts
                    if self.persistentTasks[task.id] != task {
                        self.persistentTasks[task.id] = task
                        self.savePersistentTasks()
                    }

                    // 4. Pre-calculate strings for UI (Scheme A)
                    self.precalculateUIStrings(for: &task)
                    
                    return task
                }
                
                // 5. Merge persistent tasks that are not in the current engine list
                // This handles cases where aria2 session drops completed tasks
                let engineGIDs = Set(newTasks.map { $0.id })
                for (gid, task) in self.persistentTasks {
                    if !engineGIDs.contains(gid) && !self.deletingGIDs.contains(gid) {
                        var pTask = task
                        
                        // Restore speed history for persistent tasks if missing
                        if pTask.downloadSpeedHistory.isEmpty, let cachedHistory = self.speedHistoryCache[gid] {
                            pTask.downloadSpeedHistory = cachedHistory
                        }
                        
                        self.precalculateUIStrings(for: &pTask)
                        self.tasks.append(pTask)
                    }
                }
                
                self.updateFilteredTasks()
                self.saveSpeedHistory()
                self.lastRpcError = nil
                
                // Monitor task list state
                let downloadingCount = self.taskCount(for: .downloading)
                let completedCount = self.taskCount(for: .completed)
                print("DownloadManager: UI State - Downloading: \(downloadingCount), Completed: \(completedCount)")
        } catch {
            if let rpcError = error as? Aria2Error {
                if case .rpcError(let msg) = rpcError {
                    self.lastRpcError = msg
                }
            }
            print("DownloadManager: Failed to refresh tasks: \(error)")
        }
    }
    
    /// Sync user preferences to aria2 live via RPC
    func applyGlobalOptions() async {
        guard let service = aria2Service, isConnected else { return }
        
        let defaults = UserDefaults.standard
        let maxConcurrent = defaults.integer(forKey: "maxConcurrentDownloads")
        let defaultConnections = defaults.integer(forKey: "defaultConnections")
        let userAgent = defaults.string(forKey: "userAgent") ?? "MotrixMac/2.0"
        
        // BitTorrent Settings
        let enableDht = defaults.bool(forKey: "enableDht")
        let enablePex = defaults.bool(forKey: "enablePex")
        let enableLpd = defaults.bool(forKey: "enableLpd")
        let btPort = defaults.integer(forKey: "btListenPort")
        let btEncryptionMode = defaults.integer(forKey: "btEncryptionMode")
        let btTrackers = defaults.string(forKey: "btTrackers") ?? ""
        
        // Seeding and Metadata
        let btSaveMetadata = defaults.bool(forKey: "btSaveMetadata")
        let btContinuousSeeding = defaults.bool(forKey: "btContinuousSeeding")
        let seedRatio = defaults.double(forKey: "seedRatio")
        let seedTime = defaults.integer(forKey: "seedTime")
        
        // Speed limits
        let maxDownloadSpeed = defaults.integer(forKey: "maxDownloadSpeed")
        let downloadSpeedUnit = defaults.string(forKey: "downloadSpeedUnit") ?? "KB/s"
        let maxUploadSpeed = defaults.integer(forKey: "maxUploadSpeed")
        let uploadSpeedUnit = defaults.string(forKey: "uploadSpeedUnit") ?? "KB/s"

        var options: [String: String] = [:]
        
        if maxConcurrent > 0 {
            options["max-concurrent-downloads"] = String(maxConcurrent)
        }
        
        if defaultConnections > 0 {
            options["max-connection-per-server"] = String(defaultConnections)
            options["split"] = String(defaultConnections)
        }
        
        options["user-agent"] = userAgent
        
        // BitTorrent Options
        let autoRename = defaults.bool(forKey: "autoRenameFiles") // Defaults to false if missing, but usually initialized true
        
        options["enable-dht"] = String(enableDht)
        options["bt-enable-lpd"] = String(enableLpd)
        options["enable-peer-exchange"] = String(enablePex)
        options["bt-tracker"] = btTrackers.replacingOccurrences(of: "\n", with: ",")
        options["bt-save-metadata"] = String(btSaveMetadata)
        options["bt-detach-seed-only"] = "false" // Enforce seeding
        options["auto-file-renaming"] = String(autoRename)
        
        if btContinuousSeeding {
            // [Critical Fix] In aria2, 0 means "stop immediately", not "seed forever"
            // Use very high values to effectively seed indefinitely
            options["seed-ratio"] = "100000.0"
            options["seed-time"] = "525600" // 1 year in minutes
        } else {
            options["seed-ratio"] = String(format: "%.1f", seedRatio)
            options["seed-time"] = String(seedTime)
        }
        
        if btPort > 0 {
            options["listen-port"] = String(btPort)
        }
        
        // Speed Limits
        options["max-download-limit"] = formatSpeedLimit(maxDownloadSpeed, unit: downloadSpeedUnit)
        options["max-upload-limit"] = formatSpeedLimit(maxUploadSpeed, unit: uploadSpeedUnit)
        
        // Encryption
        // Mode 0:Allow, 1:Force, 2:Disable
        switch btEncryptionMode {
        case 1: // Force
            options["bt-require-crypto"] = "true"
            options["bt-min-crypto-level"] = "arc4"
        case 2: // Disable
            options["bt-require-crypto"] = "false"
            options["bt-min-crypto-level"] = "plain"
        default: // Allow (Hybrid)
            options["bt-require-crypto"] = "false"
            options["bt-min-crypto-level"] = "plain"
        }
        
        if defaults.bool(forKey: "continueDownload") {
            options["continue"] = "true"
        } else {
            options["continue"] = "false"
        }
        
        // Proxy Settings
        // [Fix] Construct proxy string from individual AppStorage keys
        if defaults.bool(forKey: "proxyEnabled") {
            let host = defaults.string(forKey: "proxyHost") ?? ""
            let port = defaults.string(forKey: "proxyPort") ?? ""
            let user = defaults.string(forKey: "proxyUsername") ?? ""
            let pass = defaults.string(forKey: "proxyPassword") ?? ""
            
            if !host.isEmpty {
                var proxyString = "http://"
                if !user.isEmpty {
                    proxyString += "\(user)"
                    if !pass.isEmpty {
                        proxyString += ":\(pass)"
                    }
                    proxyString += "@"
                }
                proxyString += host
                if !port.isEmpty {
                    proxyString += ":\(port)"
                }
                options["all-proxy"] = proxyString
                Logger.info("DownloadManager: Applied proxy settings: \(host):\(port)")
            } else {
                options["all-proxy"] = ""
            }
        } else {
            options["all-proxy"] = ""
        }
        
        guard !options.isEmpty else { return }
        
        do {
            try await service.changeGlobalOption(options: options)
            Logger.info("DownloadManager: Successfully applied global options: \(options)")
            
            // Per-task updates for existing downloads
            // [Fix] Enforce critical options on running tasks too
            let taskUpdateOptions: [String: String] = [
                "max-connection-per-server": options["max-connection-per-server"] ?? "16",
                "split": options["split"] ?? "16",
                "bt-detach-seed-only": "false", // Enforce seeding for active tasks
                "seed-ratio": options["seed-ratio"] ?? "0.0",
                "seed-time": options["seed-time"] ?? "0"
            ]
            
            for task in tasks {
                guard ["active", "waiting", "paused"].contains(task.status) else { continue }
                try? await service.changeOption(gid: task.id, options: taskUpdateOptions)
            }
        } catch {
            print("DownloadManager: Failed to apply global options: \(error)")
        }
    }
    
    private func formatSpeedLimit(_ value: Int, unit: String) -> String {
        if value <= 0 { return "0" }
        let isMB = unit.lowercased().hasPrefix("m")
        return "\(value)\(isMB ? "M" : "K")"
    }

    /// Restart the aria2 engine to apply settings that require a restart (e.g. split)
    func restartEngine() async {
        guard let engine = aria2Process else { return }
        
        Logger.info("DownloadManager: Requesting engine restart...")
        await disconnect()
        
        // Restart the process (which re-generates aria2.conf with new defaults)
        engine.restart()
        
        // Wait for it to come back up
        try? await Task.sleep(for: .milliseconds(1500))
        await connect()
    }
    
    func taskCount(for category: TaskCategory) -> Int {
        tasks.filter { task in
            if category == .downloading {
                // 进行中：包括除“已完成”之外的所有状态，此外“正在做种”的任务也属于进行中
                if task.isSeeding { return true }
                return task.status != "complete"
            } else if category == .completed {
                // 已完成：仅限“已完成”状态，且不能是正在做种的 BT 任务
                if task.isSeeding { return false }
                return task.status == "complete"
            }
            return false
        }.count
    }

    func addDownload(uri: String, options: [String: Any]) async throws {
        guard let service = aria2Service else {
            throw Aria2Error.connectionFailed
        }
        
        // [Critical Fix] Prevent adding tracker/announce URLs as regular downloads
        // These are frequently injected by external tools but cause "Read-only file system" errors in aria2
        let lowerUri = uri.lowercased()
        if lowerUri.contains("/announce") || lowerUri.hasPrefix("udp://") || lowerUri.hasSuffix(".php") {
            Logger.info("DownloadManager: Intercepted and ignored phantom task: \(uri)")
            return
        }
        
        // [Fundamental Fix] Clean Magnet links to remove unsupported UDP trackers
        // This prevents aria2 from attempting UDP connections that fail and create phantom "announce" tasks
        let finalUri = uri.hasPrefix("magnet:") ? cleanMagnetLink(uri) : uri
        
        // Deduplication: Check if we already have this URI in active/waiting/paused
        // Note: This is a simple check. Aria2 might normalize URIs, but this catches exact matches from extension.
        let isDuplicate = tasks.contains { task in
            ["active", "waiting", "paused"].contains(task.status) && task.uri == finalUri
        }
        
        if isDuplicate {
            print("DownloadManager: Duplicate URI ignored: \(uri)")
            return
        }
        
        var finalOptions = options
        
        // [Feature] Inject cached/user trackers to compensate for filtered UDP trackers
        // This ensures High Availability even if the Magnet link's own trackers are all UDP
        let cachedTrackers = UserDefaults.standard.string(forKey: "cachedAutoTrackers") ?? ""
        let userTrackers = UserDefaults.standard.string(forKey: "btTrackers") ?? ""
        let injectedTrackers = [cachedTrackers, userTrackers]
            .filter { !$0.isEmpty }
            .joined(separator: ",")
            
        if !injectedTrackers.isEmpty {
            // Append to existing trackers if any
            if let existing = finalOptions["bt-tracker"] as? String {
                finalOptions["bt-tracker"] = existing + "," + injectedTrackers
            } else {
                finalOptions["bt-tracker"] = injectedTrackers
            }
        }

        let defaultConnections = UserDefaults.standard.integer(forKey: "defaultConnections")
        if defaultConnections > 0 {
            if finalOptions["split"] == nil {
                finalOptions["split"] = "\(defaultConnections)"
            }
            if finalOptions["max-connection-per-server"] == nil {
                finalOptions["max-connection-per-server"] = "\(defaultConnections)"
            }
        }
        
        // [Fix] Enforce seeding options for magnet links too
        let btContinuous = UserDefaults.standard.bool(forKey: "btContinuousSeeding")
        if btContinuous {
            // [Critical Fix] In aria2, 0 means "stop immediately", not "seed forever"
            finalOptions["seed-ratio"] = "100000.0"
            finalOptions["seed-time"] = "525600" // 1 year in minutes
        } else {
            let ratio = UserDefaults.standard.double(forKey: "seedRatio")
            let time = UserDefaults.standard.integer(forKey: "seedTime") 
            finalOptions["seed-ratio"] = ratio > 0 ? String(format: "%.1f", ratio) : "1.0"
            finalOptions["seed-time"] = time > 0 ? String(time) : "60"
        }
        finalOptions["bt-detach-seed-only"] = "false"
        
        // [Critical Fix] Explicitly disable auto-following of torrent/metalink files
        // This ensures that when a user adds a link to a .torrent file, we download the file itself defined by the URI,
        // rather than parsing it and starting a BT download.
        finalOptions["follow-torrent"] = "false"
        finalOptions["follow-metalink"] = "false"
        
        _ = try await service.addUri(uris: [finalUri], options: finalOptions)
        await refreshTasks()
    }

    /// Removes unsupported UDP trackers from a Magnet link
    private func cleanMagnetLink(_ uri: String) -> String {
        guard let components = URLComponents(string: uri),
              let queryItems = components.queryItems else {
            return uri
        }
        
        // Filter out 'tr' (tracker) parameters that start with udp://
        let filteredItems = queryItems.filter { item in
            if item.name == "tr", let value = item.value {
                return !value.hasPrefix("udp://")
            }
            return true
        }
        
        var newComponents = components
        newComponents.queryItems = filteredItems
        return newComponents.string ?? uri
    }
    
    /// Scans for and removes "phantom" tasks caused by UDP trackers from legacy sessions
    private func sanitizeSession() async {
        guard let service = aria2Service else { return }
        
        do {
            // Check all queues. "Phantom" tasks usually appear as failed/stopped tasks,
            // but sometimes hang in waiting/active if they are retrying.
            let stopped = try await service.tellStopped(offset: 0, num: 1000)
            let waiting = try await service.tellWaiting(offset: 0, num: 1000)
            let active = try await service.tellActive()
            
            let allTasks = stopped + waiting + active
            
            var purgedCount = 0
            for task in allTasks {
                // Criteria: Task is purely a UDP tracker URL or has the specific UDP error
                let isPhantomUDP = task.uri.hasPrefix("udp://") ||
                                   task.name.hasPrefix("udp://") ||
                                   (task.errorMessage?.contains("udp is not supported") == true)
                
                if isPhantomUDP {
                    print("DownloadManager: Purging phantom UDP task: \(task.id) (\(task.name))")
                    
                    if ["active", "waiting", "paused"].contains(task.status) {
                        _ = try? await service.forceRemove(gid: task.id)
                    } else {
                        _ = try? await service.removeDownloadResult(gid: task.id)
                    }
                    purgedCount += 1
                }
            }
            
            if purgedCount > 0 {
                print("DownloadManager: Sanitization complete. Purged \(purgedCount) phantom tasks.")
            }
        } catch {
            print("DownloadManager: Session sanitization scan failed: \(error)")
        }
    }

    func addTorrent(base64: String, options: [String: Any]) async throws {
        guard let service = aria2Service else { throw DownloadError.notConnected }
        var finalOptions = options
        
        // --- Smart Deduplication & Renaming Logic ---
        if let data = Data(base64Encoded: base64, options: .ignoreUnknownCharacters) {
            // 1. Calculate InfoHash locally to check for collisions
            if let decoded = try? BencodeDecoder.decode(data) as? [String: Any],
               let info = decoded["info"] as? [String: Any] {
                
                // Calculate InfoHash (SHA1 of info dict)
                // Note: We need the *encoded* info dictionary bytes. 
                // Since we parsed it, we might not have the exact original bytes of 'info' part easily 
                // without a BencodeEncoder (which we don't have).
                // Alternative: If we can't easily hash, we can fallback to name matching or 
                // rely on the user dragging the file implying a potential duplicate intent?
                // Actually, duplicate check by name is safer if we can't reliably hash 'info' without encoder.
                // Let's rely on NAME matching for now which is 99% effective for "same file" collisions.
                
                if let name = info["name"] as? String {
                    let isMultiFile = info["files"] != nil
                    
                    // Check if we have a collision
                    // We check both active tasks and persistent (completed) tasks
                    let collision = tasks.first { $0.isTorrent && ($0.name == name || $0.infoHash == nil) } ??
                                    persistentTasks.values.first { $0.isTorrent && $0.name == name }
                    
                    if let _ = collision {
                        // Collision detected! Rename to "Name (1)"
                        let newName = findUniqueName(baseName: name)
                        print("DownloadManager: Collision detected for '\(name)'. Renaming to '\(newName)'")
                        
                        if isMultiFile {
                            // Multi-file: The 'name' in metadata is the root directory name.
                            // We can't easily change the internal root directory name of the torrent.
                            // Strategy: Change the download 'dir' to a subdirectory named "Name (N)"
                            // resulting in /Downloads/Name (N)/Name/...
                            if let currentDir = finalOptions["dir"] as? String {
                                let newDir = (currentDir as NSString).appendingPathComponent(newName)
                                finalOptions["dir"] = newDir
                            } else {
                                // Default dir
                                let defaultDir = UserDefaults.standard.string(forKey: "defaultDownloadLocation") ?? 
                                                 FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!.path
                                finalOptions["dir"] = (defaultDir as NSString).appendingPathComponent(newName)
                            }
                        } else {
                             // Single-file: We can use 'out' option to rename the file
                            // But we need to keep the extension.
                            let ext = (name as NSString).pathExtension
                            let nameNoExt = (name as NSString).deletingPathExtension // This strips extension
                            
                            // Re-calculate unique name strictly for filename
                             let uniqueFileName = findUniqueFileName(baseName: nameNoExt, extension: ext)
                             finalOptions["out"] = uniqueFileName
                        }
                    }
                }
            }
        }
        
        let defaultConnections = UserDefaults.standard.integer(forKey: "defaultConnections")
        if defaultConnections > 0 {
            if finalOptions["split"] == nil {
                finalOptions["split"] = "\(defaultConnections)"
            }
            if finalOptions["max-connection-per-server"] == nil {
                finalOptions["max-connection-per-server"] = "\(defaultConnections)"
            }
        }
        
        // [Fix] Enforce seeding options for new tasks to prevent immediate completion
        // Explicitly override any defaults with user preferences
        let btContinuous = UserDefaults.standard.bool(forKey: "btContinuousSeeding")
        if btContinuous {
            // [Critical Fix] In aria2, 0 means "stop immediately", not "seed forever"
            finalOptions["seed-ratio"] = "100000.0"
            finalOptions["seed-time"] = "525600" // 1 year in minutes
        } else {
            let ratio = UserDefaults.standard.double(forKey: "seedRatio")
            let time = UserDefaults.standard.integer(forKey: "seedTime")
            // Use defaults if keys are missing (ratio 1.0, time 60 min, etc? or rely on aria2 default?)
             // Better to just set them if they exist or set safe defaults.
            finalOptions["seed-ratio"] = ratio > 0 ? String(format: "%.1f", ratio) : "1.0"
            finalOptions["seed-time"] = time > 0 ? String(time) : "60"
        }
        finalOptions["bt-detach-seed-only"] = "false"

        _ = try await service.addTorrent(torrent: base64, options: finalOptions)
        await refreshTasks()
    }
    
    // Helper to find unique name "Name (N)"
    private func findUniqueName(baseName: String) -> String {
        var name = baseName
        var counter = 1
        
        // Simple check against our known task list
        // Note: This isn't perfect against file system if the app doesn't know about them, 
        // but solves the "App Logic" duplicate issue.
        while tasks.contains(where: { $0.name == name }) || 
              persistentTasks.values.contains(where: { $0.name == name }) {
            name = "\(baseName) (\(counter))"
            counter += 1
        }
        return name
    }

    private func findUniqueFileName(baseName: String, extension ext: String) -> String {
        var name = ext.isEmpty ? baseName : "\(baseName).\(ext)"
        var counter = 1
        
        while tasks.contains(where: { $0.name == name }) || 
              persistentTasks.values.contains(where: { $0.name == name }) {
            name = ext.isEmpty ? "\(baseName) (\(counter))" : "\(baseName) (\(counter)).\(ext)"
            counter += 1
        }
        return name
    }

    func pauseTask(_ task: DownloadTask) async {
        guard let service = aria2Service else { return }
        
        // Try with stored GID first
        do {
            try await service.pause(gid: task.id)
            await refreshTasks()
            return
        } catch {
            // GID not found - try to resolve using infoHash
            if task.isTorrent, let infoHash = task.infoHash, !infoHash.isEmpty {
                if let realGid = await resolveRealGid(forInfoHash: infoHash) {
                    do {
                        try await service.pause(gid: realGid)
                        await refreshTasks()
                        return
                    } catch {
                        print("Failed to pause task with resolved GID: \(error)")
                    }
                }
            }
            print("Failed to pause task: \(error)")
        }
    }
    
    /// Resolves the actual aria2 GID for a BT task by matching infoHash
    private func resolveRealGid(forInfoHash infoHash: String) async -> String? {
        guard let service = aria2Service else { return nil }
        do {
            let activeTasks = try await service.tellActive()
            // Search in active tasks
            if let match = activeTasks.first(where: { $0.infoHash?.lowercased() == infoHash.lowercased() }) {
                return match.id
            }
            // Also check waiting tasks
            let waitingTasks = try await service.tellWaiting(offset: 0, num: 100)
            if let match = waitingTasks.first(where: { $0.infoHash?.lowercased() == infoHash.lowercased() }) {
                return match.id
            }
        } catch {
            print("Failed to resolve real GID: \(error)")
        }
        return nil
    }

    func resumeTask(_ task: DownloadTask) async {
        guard let service = aria2Service else { return }
        
        // Try with stored GID first
        do {
            try await service.unpause(gid: task.id)
            await refreshTasks()
            return
        } catch {
            // GID not found - try to resolve using infoHash
            if task.isTorrent, let infoHash = task.infoHash, !infoHash.isEmpty {
                if let realGid = await resolveRealGid(forInfoHash: infoHash) {
                    do {
                        try await service.unpause(gid: realGid)
                        await refreshTasks()
                        return
                    } catch {
                        print("Failed to resume task with resolved GID: \(error)")
                    }
                }
            }
            print("Failed to resume task: \(error)")
        }
    }
    
    func retryTask(_ task: DownloadTask) async {
        if task.status == "removed" || task.status == "error" {
            // First, remove the old task record from aria2
            await deleteTask(task, withFiles: false)
            
            // For BT tasks, check if we have an infoHash to re-add
            if task.isTorrent, let infoHash = task.infoHash, !infoHash.isEmpty {
                // Re-add via magnet link constructed from infoHash
                let magnetUri = "magnet:?xt=urn:btih:\(infoHash)"
                let options: [String: Any] = [
                    "dir": task.dir,
                    "auto-file-renaming": "true"
                ]
                _ = try? await addDownload(uri: magnetUri, options: options)
            } else if !task.uri.isEmpty {
                // For regular HTTP downloads
                let options: [String: Any] = [
                    "dir": task.dir,
                    "auto-file-renaming": "true"
                ]
                _ = try? await addDownload(uri: task.uri, options: options)
            }
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
            Logger.error("Failed to cancel task: \(error)")
        }
    }

    func stopSeeding(_ task: DownloadTask) async {
        guard let service = aria2Service else { return }
        
        do {
            // 1. Force remove from engine (stops the active seeding)
            _ = try? await service.forceRemove(gid: task.id)
            
            // 2. Mark as complete in our persistent storage
            var updatedTask = task
            updatedTask.status = "complete"
            self.persistentTasks[task.id] = updatedTask
            self.savePersistentTasks()
            
            // 3. Clean up engine result
            _ = try? await service.removeDownloadResult(gid: task.id)
            
            // 4. Final refresh
            await refreshTasks()
        } catch {
            print("Failed to stop seeding: \(error)")
        }
    }

    func deleteTask(_ task: DownloadTask, withFiles: Bool = false) async {
        await deleteTasks([task], withFiles: withFiles)
    }

    func deleteTasks(_ tasksToDelete: [DownloadTask], withFiles: Bool = false) async {
        guard !tasksToDelete.isEmpty, let service = aria2Service else { return }
        
        let idsToRemove = Set(tasksToDelete.map { $0.id })
        
        // 1. Mark as deleting and remove from UI
        self.deletingGIDs.formUnion(idsToRemove)
        self.tasks.removeAll { idsToRemove.contains($0.id) }
        
        // Remove from persistent storage too
        for id in idsToRemove {
            self.persistentTasks.removeValue(forKey: id)
            self.notifiedStartedGIDs.remove(id)
        }
        self.savePersistentTasks()
        
        self.updateFilteredTasks()
        
        // 2. Engine Removal (Concurrent)
        await withTaskGroup(of: Void.self) { group in
            for task in tasksToDelete {
                group.addTask {
                    // Step A: Stop if active
                    if ["active", "waiting", "paused"].contains(task.status) {
                        _ = try? await service.forceRemove(gid: task.id)
                        // Give aria2 a moment to move the task to 'stopped' list 
                        try? await Task.sleep(for: .milliseconds(200))
                    }
                    
                    // Step B: Thoroughly remove from memory
                    // We try twice to handle race conditions in aria2 transition
                    if (try? await service.removeDownloadResult(gid: task.id)) == nil {
                        try? await Task.sleep(for: .milliseconds(300))
                        _ = try? await service.removeDownloadResult(gid: task.id)
                    }

                    if withFiles {
                        await self.deleteFiles(for: task)
                    }
                }
            }
        }
        
        // 3. Cleanup: allow some breathing room before removing from blacklist
        try? await Task.sleep(for: .milliseconds(500))
        self.deletingGIDs.subtract(idsToRemove)
        
        // 4. Force aria2 to save session to disk immediately to prevent ghosting on reboot
        try? await service.saveSession()
        
        // Final refresh
        await refreshTasks()
    }

    func clearAllStopped() async {
        guard let service = aria2Service else { return }
        let stoppedStatuses = ["complete", "removed", "error"]
        let stoppedTasks = tasks.filter { stoppedStatuses.contains($0.status) }

        for task in stoppedTasks {
            do {
                try await service.removeDownloadResult(gid: task.id)
                self.persistentTasks.removeValue(forKey: task.id)
            } catch {
                print("Failed to remove stopped task result: \(error)")
            }
        }
        self.savePersistentTasks()
        try? await service.saveSession()
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
        let dirUrl = URL(fileURLWithPath: task.dir)
        let url = dirUrl.appendingPathComponent(task.name)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func openFile(_ task: DownloadTask) {
        let dirUrl = URL(fileURLWithPath: task.dir)
        let url = dirUrl.appendingPathComponent(task.name)
        NSWorkspace.shared.open(url)
    }

    private func deleteFiles(for task: DownloadTask) {
        let dirUrl = URL(fileURLWithPath: task.dir)
        let url = dirUrl.appendingPathComponent(task.name)
        
        // 1. Delete the main data file or folder
        try? FileManager.default.removeItem(at: url)
        
        // 2. Delete the .aria2 control file (usually named [filename].aria2)
        let aria2Url = url.appendingPathExtension("aria2")
        try? FileManager.default.removeItem(at: aria2Url)
        
        // 3. Extra cleanup: Check for [filename].torrent (if it was a local file)
        let torrentUrl = url.appendingPathExtension("torrent")
        try? FileManager.default.removeItem(at: torrentUrl)
    }

    // MARK: - Auto Refresh

    private func startAutoRefresh() {
        // Cancel existing task to prevent leaks
        refreshTask?.cancel()
        
        refreshTask = Task {
            print("DownloadManager: Starting auto-refresh loop")
            while !Task.isCancelled {
                // Check cancellation at start of loop
                // PAUSE loop if engine needs repair to avoid spamming timeouts
                if !needsRepair {
                    await refreshTasks()
                }

                // Adaptive polling:
                // If there are active downloads/tasks, refresh faster (1s)
                // If idle, refresh slower (3s) to save CPU
                let hasActiveTasks = !activeDownloads.isEmpty || !tasks.filter({ $0.status == "waiting" }).isEmpty
                let sleepDuration: UInt64 = hasActiveTasks ? 500_000_000 : 3_000_000_000 // 500ms vs 3s

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
            if method == "aria2.onDownloadStart" {
                 if let firstParam = params.first as? [String: Any],
                    let gid = firstParam["gid"] as? String
                 {
                    // [Feature] Immediate notification on task start
                    // We check if it's a metadata task to avoid noise
                    Task {
                        if let task = try? await aria2Service?.tellStatus(gid: gid) {
                            // [Critical Fix] Filter out all announce/tracker phantom tasks
                            let name = task.name.lowercased()
                            if task.name.hasPrefix("[METADATA]") ||
                               name.contains("announce") ||
                               name.hasSuffix(".php") ||
                               task.uri.contains("/announce") { return }
                            
                            // [Critical Fix] Don't notify for tasks already known as complete
                            // This prevents "ghost" notifications when aria2 briefly re-reports completed tasks on startup
                            if let persistent = self.persistentTasks[gid], persistent.status == "complete" { return }
                            
                            // Prevent duplicate start notifications if speed check already fired
                            if !self.notifiedStartedGIDs.contains(gid) {
                                self.notifiedStartedGIDs.insert(gid)
                                sendNotification(title: "开始下载", body: "\(task.name) 已开始下载")
                            }
                        }
                    }
                }
            } else if method == "aria2.onDownloadComplete" {
                if let firstParam = params.first as? [String: Any],
                    let gid = firstParam["gid"] as? String
                {
                    if let task = try? await aria2Service?.tellStatus(gid: gid) {
                        // [Critical Fix] Filter out all announce/tracker phantom tasks
                        let name = task.name.lowercased()
                        if task.name.hasPrefix("[METADATA]") ||
                           name.contains("announce") ||
                           name.hasSuffix(".php") ||
                           task.uri.contains("/announce") { return }
                        
                        // [Fix] Suppress notification if task is already known as complete in persistent storage
                        if let persistent = persistentTasks[gid], persistent.status == "complete" {
                            return
                        }
                        
                        sendNotification(title: "下载完成", body: "\(task.name) 已下载完成")
                        
                        // [Critical Fix] Force save session immediately upon completion
                        try? await self.aria2Service?.saveSession()
                        
                        // Update persistent state immediately
                        if let existing = self.persistentTasks[gid] {
                            var updated = existing
                            updated.status = "complete"
                            self.persistentTasks[gid] = updated
                            self.savePersistentTasks()
                        }
                    }
                }
            } else if method == "aria2.onBtDownloadComplete" {
                if let firstParam = params.first as? [String: Any],
                   let gid = firstParam["gid"] as? String
                {
                   Task {
                       if let task = try? await aria2Service?.tellStatus(gid: gid) {
                           // [Critical Fix] Filter out all announce/tracker phantom tasks
                           let name = task.name.lowercased()
                           if task.name.hasPrefix("[METADATA]") ||
                              name.contains("announce") ||
                              name.hasSuffix(".php") ||
                              task.uri.contains("/announce") { return }
                           
                           // Deduplicate against persistent status
                           if let persistent = persistentTasks[gid], persistent.status == "complete" { return }
                           
                           // Also unlikely to need deduplication against onDownloadComplete if we check persistent status first?
                           // But to be safe, we can check if we just notified.
                           // For simplicity, we rely on the persistent status check, assuming onDownloadComplete (if fired) set it.
                           // If onDownloadComplete didn't fire (BT specific case), then we notify here.
                           
                           sendNotification(title: "BT 下载完成", body: "\(task.name) 已下载完成")
                           
                           try? await self.aria2Service?.saveSession()
                           
                           if let existing = self.persistentTasks[gid] {
                               var updated = existing
                               updated.status = "complete"
                               self.persistentTasks[gid] = updated
                               self.savePersistentTasks()
                           }
                       }
                   }
                }
            } else if method == "aria2.onDownloadError" {
                if let firstParam = params.first as? [String: Any],
                    let gid = firstParam["gid"] as? String
                {
                    if let task = try? await aria2Service?.tellStatus(gid: gid) {
                        // Suppress notifications for phantom "announce" tasks
                        if task.name == "announce" || (task.totalLength == 0 && task.name.hasPrefix("announce")) {
                             return
                        }
                        
                        let errorMessage = task.errorMessage ?? "未知错误"
                        Logger.error("DownloadManager: Task \(task.name) (GID: \(gid)) failed: \(errorMessage)")
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

    // MARK: - Performance Optimizations
    
    private func precalculateUIStrings(for task: inout DownloadTask) {
        let formatter = Self.byteCountFormatter
        
        // 1. Size Text
        let completed = formatter.string(fromByteCount: task.completedLength)
        let total = formatter.string(fromByteCount: task.totalLength)
        if task.status == "complete" {
            task.formattedSizeText = total
        } else {
            task.formattedSizeText = "\(completed) / \(total)"
        }
        
        // 2. Speed and ETA
        task.formattedStatusText = task.displayStatus // Restore missing assignment
        if task.isSeeding {
            // Seeding: Show upload speed instead of download
            let uploadSpeed = formatter.string(fromByteCount: task.uploadSpeed) + "/s"
            task.formattedDownloadSpeed = uploadSpeed
            task.formattedETA = "--"
            task.formattedStatusLine = "\(task.formattedSizeText) · ↑ \(uploadSpeed) · 做种中"
        } else if task.isActive {
            task.formattedDownloadSpeed = formatter.string(fromByteCount: task.downloadSpeed) + "/s"
            task.formattedETA = task.eta
            
            if task.totalLength > 0 {
                task.formattedStatusLine = "\(task.formattedSizeText) · \(task.formattedDownloadSpeed) · 剩余时间: \(task.formattedETA)"
            } else {
                task.formattedStatusLine = "\(task.formattedSizeText) · \(task.formattedDownloadSpeed)"
            }
        } else {
            task.formattedStatusLine = "\(task.formattedSizeText) · \(task.formattedStatusText)"
        }
        
        // 3. File existence check (for sorting and UI)
        if task.status == "complete" {
            // Only check if files array is populated, or rely on dir/name
            var filePath = ""
            if let firstFile = task.files.first?.path, !firstFile.isEmpty {
                filePath = firstFile
            } else {
                filePath = task.dir + "/" + task.name
            }
            
            // Should calculate this asynchronously?
            // Doing it here (called in refreshTasks) is on background actor or MainActor?
            // DownloadManager is @MainActor.
            // FileExists is fast on SSD, but might block main thread slightly if many files.
            // But this is the only way to support "Real-time" sorting without complex state.
            task.isFileMissing = !FileManager.default.fileExists(atPath: filePath)
        } else {
            task.isFileMissing = false
        }
    }

    private func updateFilteredTasks() {
        let categoryTasks = tasks.filter { task in
            // Logic to handle "Seeding" tasks (Active but download finished)
            // Seeding tasks should appear in 'Downloading' per user request
            let isSeeding = task.isSeeding
            
            // Logic to prevent "Flashing" of completed HTTP tasks on startup
            // If a standard task is fully downloaded but briefly "active" (verifying), treat as complete
            let isHTTPComplete = !task.isTorrent && task.totalLength > 0 && task.completedLength == task.totalLength
            
            if currentCategory == .downloading {
                // Downloading: Include seeding tasks.
                if task.isSeeding { return true }
                return task.status != "complete"
            } else if currentCategory == .completed {
                // Completed: Include complete tasks. Exclude seeding tasks.
                if task.isSeeding { return false }
                return task.status == "complete"
            }
            
            return false
        }

        let sorted: [DownloadTask]
        switch sortOrder {
        case .dateAdded:
            sorted = categoryTasks.sorted { $0.addedAt > $1.addedAt }
        case .name:
            sorted = categoryTasks.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        case .size:
            sorted = categoryTasks.sorted { $0.totalLength > $1.totalLength }
        case .progress:
            // Custom Logic:
            // 1. Files NOT missing come first (isFileMissing == false < isFileMissing == true)
            // 2. Completed tasks (Progress=1.0) sort by Date Added (Descending)
            // 3. Active tasks sorting (Descending progress)
            sorted = categoryTasks.sorted { t1, t2 in
                if t1.isFileMissing != t2.isFileMissing {
                    return !t1.isFileMissing // Present files first
                }
                
                // If both are completed
                if t1.status == "complete" && t2.status == "complete" {
                     return t1.addedAt > t2.addedAt
                }
                
                return t1.progress > t2.progress
            }
        }

        if searchText.isEmpty {
            self.filteredTasks = sorted
        } else {
            self.filteredTasks = sorted.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
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
