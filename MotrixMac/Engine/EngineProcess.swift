import AppKit
import Foundation
import Combine

/// Manages the aria2 engine subprocess with self-healing capabilities
class EngineProcess: ObservableObject {
    enum EngineState: String {
        case idle = "空闲"
        case scanning = "正在扫描僵尸进程..."
        case cleaning = "正在清理冲突进程..."
        case starting = "正在启动引擎..."
        case connecting = "正在建立连接..."
        case running = "引擎运行中"
        case failed = "引擎启动失败"
    }

    private var process: Process?
    
    @Published var state: EngineState = .idle
    @Published var lastErrorMessage: String?
    
    // MARK: - Public Properties
    
    /// The actual port being used by the running aria2 process
    private(set) var currentPort: Int = 12800
    
    /// The actual secret being used by the running aria2 process  
    private(set) var currentSecret: String = ""
    
    /// Callback triggered when a port conflict is detected that cannot be resolved automatically
    var onPortConflict: ((Int, String, Int32) -> Void)?
    
    // MARK: - Initialization
    
    init(port: Int = 12800) {
        let defaults = UserDefaults.standard
        
        // 1. Load or Generate Secret (Keep it stable if possible)
        var secret = defaults.string(forKey: "rpcSecret") ?? ""
        if secret.isEmpty || secret.count < 8 {
            secret = Self.generateSecret()
            defaults.set(secret, forKey: "rpcSecret")
            defaults.synchronize()
        }
        
        // 2. Initial Port (Will probe for free one during start)
        var storedPort = defaults.integer(forKey: "rpcPort")
        if storedPort == 0 {
            storedPort = port
        }
        
        self.currentPort = storedPort
        self.currentSecret = secret
    }
    
        
    // MARK: - Lifecycle
    
    func start() {
        state = .scanning
        Logger.info("EngineProcess: Starting self-healing sequence...")
        
        // 1. Zombie Scan & Immediate Cleanup
        zombieScan()
        
        // 2. Refresh runtime values
        let preferredPort = UserDefaults.standard.integer(forKey: "rpcPort") != 0 ? 
                           UserDefaults.standard.integer(forKey: "rpcPort") : 12800
        currentPort = preferredPort
        currentSecret = UserDefaults.standard.string(forKey: "rpcSecret") ?? currentSecret
        if currentSecret.isEmpty { currentSecret = Self.generateSecret() }
        
        // 3. Check if the port is already occupied (even after cleanup)
        if !isPortAvailable(currentPort) {
            state = .cleaning
            print("EngineProcess: Port \(currentPort) is occupied. Force cleaning to ensure App ownership...")
            aggressiveCleanup()
            
            if !isPortAvailable(currentPort) {
                state = .failed
                lastErrorMessage = "无法释放端口 \(currentPort)，请手动检查端口占用。"
                return
            }
        }
            
        if !isPortAvailable(currentPort) {
            state = .failed
            lastErrorMessage = "端口 \(currentPort) 已被其他应用永久占用。"
            return
        }
        
        state = .starting
        
        // 5. Synchronize runtime values
        UserDefaults.standard.set(currentPort, forKey: "rpcRuntimePort")
        UserDefaults.standard.set(currentSecret, forKey: "rpcSecret")
        UserDefaults.standard.synchronize() 
        
        print("EngineProcess: Starting new aria2 process. Port: \(currentPort)")
        
        let aria2Path = findAria2Binary()
        guard FileManager.default.fileExists(atPath: aria2Path) else {
            print("aria2-error: binary not found at \(aria2Path)")
            return
        }
        
        let sessionPath = getSessionPath()
        if !FileManager.default.fileExists(atPath: sessionPath) {
            FileManager.default.createFile(atPath: sessionPath, contents: nil, attributes: nil)
        }
        
        let configPath = createConfigFile()
        
        process = Process()
        process?.executableURL = URL(fileURLWithPath: aria2Path)
        process?.arguments = buildArguments(sessionPath: sessionPath, configPath: configPath)
        
        // Pipe stderr for debugging
        process?.standardOutput = FileHandle.nullDevice
        let pipe = Pipe()
        process?.standardError = pipe
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if let str = String(data: data, encoding: .utf8), !str.isEmpty {
                print("aria2-stderr: \(str.trimmingCharacters(in: .whitespacesAndNewlines))")
            }
        }
        
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin"
        process?.environment = env
        
        do {
            try process?.run()
            let pid = process?.processIdentifier ?? 0
            writePidFile(pid: pid)
            Logger.info("EngineProcess: aria2 launched (PID: \(pid)) on port \(currentPort)")
            state = .running
            
            // Post-launch verification: check if it stayed alive
            DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard let self = self else { return }
                if let proc = self.process, !proc.isRunning {
                    let exitCode = proc.terminationStatus
                    let msg = "aria2 意外退出 (退出码: \(exitCode))。通常是因为端口被占用或配置错误。"
                    print("EngineProcess: CRITICAL ERROR - \(msg)")
                    self.lastErrorMessage = msg
                } else {
                    self.lastErrorMessage = nil
                }
            }
        } catch {
            Logger.error("EngineProcess: Failed to run process: \(error)")
        }
    }
    

    
    func stop() {
        // 1. Try graceful stop if we have the reference
        if let process = process, process.isRunning {
            print("EngineProcess: Stopping aria2 (PID: \(process.processIdentifier))...")
            
            // Try RPC shutdown first (save session)
            if testConnection(port: currentPort, secret: currentSecret) {
                sendRpcShutdown(port: currentPort, secret: currentSecret, force: false)
                
                // Wait for a short moment for aria2 to save its state and exit
                let startTime = Date()
                while process.isRunning && Date().timeIntervalSince(startTime) < 0.5 {
                    Thread.sleep(forTimeInterval: 0.05)
                }
            }
            
            // If still running, use term signal
            if process.isRunning {
                process.terminate() // SIGTERM
                
                let startTime = Date()
                while process.isRunning && Date().timeIntervalSince(startTime) < 0.3 {
                    Thread.sleep(forTimeInterval: 0.05)
                }
            }
        }
        
        // 2. Final Check & Aggressive Cleanup only if necessary
        if !isPortAvailable(currentPort) {
            print("EngineProcess: Port still busy after stop, performing aggressive cleanup...")
            aggressiveCleanup()
        } else {
            // Even if port is free, clean up our own process reference
            process?.terminate()
            removePidFile()
        }
        
        print("EngineProcess: Engine shutdown complete.")
        state = .idle
    }
    
    /// Restart aria2 with new settings
    func restart(port: Int? = nil, secret: String? = nil) {
        print("Restarting aria2 engine...")
        
        // Update runtime values if provided
        if let newPort = port {
            currentPort = newPort
        }
        
        if let newSecret = secret {
            currentSecret = newSecret
        }
        
        // Read from UserDefaults if not provided
        if port == nil {
            currentPort = UserDefaults.standard.integer(forKey: "rpcPort")
            if currentPort == 0 { currentPort = 12800 }
        }
        
        if secret == nil {
            currentSecret = UserDefaults.standard.string(forKey: "rpcSecret") ?? ""
        }
        
        // CRITICAL: Sync to UserDefaults
        UserDefaults.standard.set(currentPort, forKey: "rpcPort")
        UserDefaults.standard.set(currentSecret, forKey: "rpcSecret")
        UserDefaults.standard.synchronize()
        print("EngineProcess: Restart - Synced to UserDefaults - Port: \(currentPort), Secret: \(currentSecret)")
        
        // STOP is not enough. We must ensure the old process is GONE.
        // Otherwise start() might re-attach to the old instance if it hasn't exited yet.
        stop()
        
        // Force cleanup to ensure port is free and we don't accidentally re-attach
        aggressiveCleanup()
        
        // Give it a moment to settle
        Thread.sleep(forTimeInterval: 0.5)
        
        start()
    }
    
    var isRunning: Bool {
        process?.isRunning ?? false
    }
    
    // MARK: - Configuration
    
    private func findAria2Binary() -> String {
        // First check in app bundle
        if let bundlePath = Bundle.main.path(
            forResource: "aria2c", ofType: nil, inDirectory: "Resources")
        {
            return bundlePath
        }
        
        // Check in Resources directory
        if let resourcePath = Bundle.main.resourcePath {
            let path = resourcePath + "/aria2c"
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        
        // Fallback to system path
        let systemPaths = [
            "/usr/local/bin/aria2c",
            "/opt/homebrew/bin/aria2c",
            "/usr/bin/aria2c",
        ]
        
        for path in systemPaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        
        return "/usr/local/bin/aria2c"
    }
    
    private func getSessionPath() -> String {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!
        let motrixDir = appSupport.appendingPathComponent("MotrixMac")
        
        try? FileManager.default.createDirectory(at: motrixDir, withIntermediateDirectories: true)
        
        return motrixDir.appendingPathComponent("aria2.session").path
    }
    
    private func createConfigFile() -> String {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!
        let motrixDir = appSupport.appendingPathComponent("MotrixMac")
        let configPath = motrixDir.appendingPathComponent("aria2.conf")
        
        // Read user preferences
        let maxConcurrent = UserDefaults.standard.integer(forKey: "maxConcurrentDownloads")
        let defaultConnections = UserDefaults.standard.integer(forKey: "defaultConnections")
        print("EngineProcess: [Config Generation] Read defaultConnections from UserDefaults: \(defaultConnections)")
        
        let maxDownloadSpeed = UserDefaults.standard.integer(forKey: "maxDownloadSpeed")
        let maxUploadSpeed = UserDefaults.standard.integer(forKey: "maxUploadSpeed")
        let btPort = UserDefaults.standard.integer(forKey: "btListenPort")
        let enableDht = UserDefaults.standard.bool(forKey: "enableDht")
        let userAgent = UserDefaults.standard.string(forKey: "userAgent") ?? "MotrixMac/2.0"
        
        // Force sync to ensure we have the latest written values from UI
        UserDefaults.standard.synchronize()
        
        // Use current runtime values for RPC - NO LEADING SPACES in config file
        let config = """
# MotrixMac aria2 configuration
# Generated automatically - do not edit

# RPC - Using current runtime values
enable-rpc=true
rpc-listen-port=\(currentPort)
rpc-secret=\(currentSecret)
rpc-allow-origin-all=true

# Downloads
max-concurrent-downloads=\(maxConcurrent > 0 ? maxConcurrent : 5)
split=\(defaultConnections > 0 ? defaultConnections : 16)
max-connection-per-server=\(defaultConnections > 0 ? defaultConnections : 16)
min-split-size=1M

# Speed limits
max-overall-download-limit=\(maxDownloadSpeed)K
max-overall-upload-limit=\(maxUploadSpeed)K

# BitTorrent
enable-dht=\(enableDht ? "true" : "false")
enable-dht6=\(enableDht ? "true" : "false")
listen-port=\(btPort > 0 ? btPort : 6881)
dht-listen-port=\(btPort > 0 ? btPort : 6881)
bt-enable-lpd=true
bt-max-peers=50
seed-time=0

# HTTP
user-agent=\(userAgent)

# Other
continue=true
auto-file-renaming=true
allow-overwrite=false
disk-cache=64M
file-allocation=falloc
"""
        
        try? config.write(toFile: configPath.path, atomically: true, encoding: .utf8)
        print("aria2 config created at: \(configPath.path)")
        
        return configPath.path
    }
    
    /// Comprehensive scan for port and process anomalies
    private func zombieScan() {
        if !isPortAvailable(currentPort) {
            print("EngineProcess: Port \(currentPort) is occupied at launch. Cleaning to ensure fresh start...")
            aggressiveCleanup()
        }
    }

    private func aggressiveCleanup() {
        print("EngineProcess: AGGRESSIVE CLEANUP - Clearing all aria2c traces...")
        
        // 1. Kill all aria2c by name (MacOS specific)
        let task = Process()
        task.launchPath = "/usr/bin/killall"
        task.arguments = ["-9", "aria2c"]
        // Run synchronously but with a timeout to avoid hanging if killall hangs
        try? task.run()
        
        // 2. Kill by PID file if exists
        DispatchQueue.global().async {
            if let pid = self.readPidFile() {
                self.forceKillProcess(pid: pid)
            }
            self.removePidFile()
        }
        
        task.waitUntilExit()
    }

    private func killExistingProcess() {
        aggressiveCleanup()
    }
    
    /// Aggressively terminates a process by PID
    private func forceKillProcess(pid: Int32) {
        print("EngineProcess: Sending SIGKILL to PID \(pid)...")
        kill(pid, SIGKILL)
    }
    
    /// Sends a shutdown command via RPC (Synchronous for cleanup use)
    private func sendRpcShutdown(port: Int, secret: String, force: Bool) {
        let url = URL(string: "http://127.0.0.1:\(port)/jsonrpc")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 2.0
        
        let method = force ? "aria2.forceShutdown" : "aria2.shutdown"
        let body: [String: Any] = [
            "jsonrpc": "2.0",
            "id": "cleanup",
            "method": method,
            "params": ["token:\(secret)"]
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let semaphore = DispatchSemaphore(value: 0)
        let task = URLSession.shared.dataTask(with: request) { _, _, _ in
            semaphore.signal()
        }
        task.resume()
        _ = semaphore.wait(timeout: .now() + 2.5)
    }
    
    // MARK: - Helper Methods (PID & Port)
    
    private func getPidFilePath() -> String {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let motrixDir = appSupport.appendingPathComponent("MotrixMac")
        return motrixDir.appendingPathComponent("engine.pid").path
    }
    
    private func writePidFile(pid: Int32) {
        let path = getPidFilePath()
        try? String(pid).write(toFile: path, atomically: true, encoding: .utf8)
    }
    
    
    private func readPidFile() -> Int32? {
        let path = getPidFilePath()
        if let content = try? String(contentsOfFile: path, encoding: .utf8), let pid = Int32(content.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return pid
        }
        return nil
    }
    
    private func removePidFile() {
        try? FileManager.default.removeItem(atPath: getPidFilePath())
    }
    
    private func findFreePort(startingAt startPort: Int) -> Int {
        var port = startPort
        while port < 65535 {
            if isPortAvailable(port) {
                return port
            }
            port += 1
        }
        return startPort // Should not happen, but fallback
    }
    
    private func isPortAvailable(_ port: Int) -> Bool {
        var socketAddress = sockaddr_in()
        socketAddress.sin_family = sa_family_t(AF_INET)
        socketAddress.sin_port = in_port_t(UInt16(port).bigEndian)
        socketAddress.sin_addr.s_addr = inet_addr("127.0.0.1")
        socketAddress.sin_len = __uint8_t(MemoryLayout<sockaddr_in>.size)
        
        let socketFileDescriptor = socket(AF_INET, SOCK_STREAM, 0)
        if socketFileDescriptor == -1 { return false }
        
        defer { close(socketFileDescriptor) }
        
        // Set SO_REUSEADDR just in case
        var reuse = 1
        setsockopt(socketFileDescriptor, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int>.size))
        
        // Try to bind - if it fails, the port is likely in use
        let bindResult = withUnsafePointer(to: &socketAddress) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(socketFileDescriptor, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        
        return bindResult == 0
    }
    
    /// Basic synchronous connection test for aria2 RPC - VERIFIES SECRET
    private func testConnection(port: Int, secret: String) -> Bool {
        let url = URL(string: "http://127.0.0.1:\(port)/jsonrpc")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 2.0
        
        let body: [String: Any] = [
            "jsonrpc": "2.0",
            "id": "test",
            "method": "aria2.getVersion",
            "params": ["token:\(secret)"]
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let semaphore = DispatchSemaphore(value: 0)
        var success = false
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               json["result"] != nil {
                // If "result" is present, the secret is correct!
                success = true
            } else if let data = data,
                      let str = String(data: data, encoding: .utf8) {
                print("EngineProcess: Test Connection detail: \(str)")
            }
            semaphore.signal()
        }
        task.resume()
        _ = semaphore.wait(timeout: .now() + 2.5)
        
        return success
    }
    
    private func buildArguments(sessionPath: String, configPath: String) -> [String] {
        return [
            "--conf-path=\(configPath)",
            "--input-file=\(sessionPath)",
            "--save-session=\(sessionPath)",
            "--save-session-interval=30",
            "--check-certificate=false",
            "--rpc-secret=\(currentSecret)",
            "--rpc-listen-port=\(currentPort)",
            "--rpc-listen-all=false",
            "--enable-rpc=true",
            "--rpc-save-upload-metadata=true",
            "--check-certificate=false", // Disable strict SSL check to prevent handshake failures
            "--rpc-allow-origin-all=true"
        ]
    }
    
    private static func generateSecret() -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<16).map { _ in letters.randomElement()! })
    }
}
