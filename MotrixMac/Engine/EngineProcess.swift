import AppKit
import Foundation

/// Manages the aria2 engine subprocess
class EngineProcess {
    private var process: Process?
    
    // MARK: - Public Properties (Thread-safe access to actual runtime values)
    
    /// The actual port being used by the running aria2 process
    private(set) var currentPort: Int = 16800
    
    /// The actual secret being used by the running aria2 process  
    private(set) var currentSecret: String = ""
    
    /// The last error message or exit reason from the engine
    private(set) var lastErrorMessage: String? = nil
    
    /// Callback triggered when a port conflict is detected that cannot be resolved automatically
    var onPortConflict: ((Int, String, Int32) -> Void)?
    
    // MARK: - Initialization
    
    init(port: Int = 16800) {
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
        // 1. Kill any known previous instance by PID or Name
        killExistingProcess()
        
        // 2. Use the exact preferred port
        let preferredPort = UserDefaults.standard.integer(forKey: "rpcPort") != 0 ? 
                           UserDefaults.standard.integer(forKey: "rpcPort") : 16800
        currentPort = preferredPort
        
        // 3. Confirm Secret
        currentSecret = UserDefaults.standard.string(forKey: "rpcSecret") ?? currentSecret
        if currentSecret.isEmpty { currentSecret = Self.generateSecret() }
        
        // 4. Check if the port is already occupied and if we can use it
        if !isPortAvailable(currentPort) {
            print("EngineProcess: Port \(currentPort) is occupied. Testing connection with current secret...")
            
            // Wait a moment in case it's in the middle of a restart
            Thread.sleep(forTimeInterval: 0.8)
            
            // If we can connect with current secret, just use it!
            if testConnection(port: currentPort, secret: currentSecret) {
                print("EngineProcess: Successfully verified and attached to existing aria2 instance on port \(currentPort).")
                // Update runtime values to ensuring UI connects to this port
                UserDefaults.standard.set(currentPort, forKey: "rpcRuntimePort")
                UserDefaults.standard.set(currentSecret, forKey: "rpcSecret")
                UserDefaults.standard.synchronize()
                
                // IMPORTANT: Since we are attaching to an external process, we must set our internal state 
                // to reflect that we are "running" even though we didn't spawn the process object.
                // We can't set `process` object but we can assume we are good.
                // However, without a `process` object, `stop()` might be limited to RPC only. 
                return 
            }
            
            print("EngineProcess: Port \(currentPort) is held by a process with a DIFFERENT secret or is unresponsive. Terminating definitively...")
            killExistingProcess()
            
            // Wait longer for OS to release the socket
            print("EngineProcess: Waiting for socket release...")
            Thread.sleep(forTimeInterval: 2.0)
            
            if !isPortAvailable(currentPort) {
                print("EngineProcess: WARNING - Port \(currentPort) still busy. Trying one more cleanup...")
                killExistingProcess()
                Thread.sleep(forTimeInterval: 1.0)
            }
        }
            
        if !isPortAvailable(currentPort) {
            print("EngineProcess: Port \(currentPort) is permanently occupied by an external process.")
            
            // STRICT MODE: We do NOT switch ports anymore. We alert the user.
            DispatchQueue.main.async {
                self.onPortConflict?(self.currentPort, "外部残留进程", 0)
            }
            return
        }
        
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
            print("EngineProcess: aria2 launched (PID: \(pid)) on port \(currentPort)")
            
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
            print("EngineProcess: Failed to run process: \(error)")
        }
    }
    

    
    func stop() {
        guard let process = process, process.isRunning else { return }
        
        print("EngineProcess: Stopping aria2 (PID: \(process.processIdentifier))...")
        
        // Try RPC shutdown first for graceful exit
        if testConnection(port: currentPort, secret: currentSecret) {
            print("EngineProcess: Sending RPC shutdown...")
            sendRpcShutdown(port: currentPort, secret: currentSecret, force: false)
        } else {
            // Signal-based termination if RPC unreachable
            process.terminate() // SIGTERM
        }
        
        // Wait up to 2 seconds for exit
        let startTime = Date()
        while process.isRunning && Date().timeIntervalSince(startTime) < 2.0 {
            Thread.sleep(forTimeInterval: 0.1)
        }
        
        if process.isRunning {
            print("EngineProcess: aria2 still running after 2s, using process.interrupt()")
            process.interrupt() // SIGINT
        }
        
        print("EngineProcess: aria2 stopped status: \(!process.isRunning)")
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
            if currentPort == 0 { currentPort = 16800 }
        }
        
        if secret == nil {
            currentSecret = UserDefaults.standard.string(forKey: "rpcSecret") ?? ""
        }
        
        // CRITICAL: Sync to UserDefaults
        UserDefaults.standard.set(currentPort, forKey: "rpcPort")
        UserDefaults.standard.set(currentSecret, forKey: "rpcSecret")
        UserDefaults.standard.synchronize()
        print("EngineProcess: Restart - Synced to UserDefaults - Port: \(currentPort), Secret: \(currentSecret)")
        
        stop()
        // Give it a moment to fully stop
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
        let maxDownloadSpeed = UserDefaults.standard.integer(forKey: "maxDownloadSpeed")
        let maxUploadSpeed = UserDefaults.standard.integer(forKey: "maxUploadSpeed")
        let btPort = UserDefaults.standard.integer(forKey: "btListenPort")
        let enableDht = UserDefaults.standard.bool(forKey: "enableDht")
        let userAgent = UserDefaults.standard.string(forKey: "userAgent") ?? "MotrixMac/2.0"
        
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
    
    private func killExistingProcess() {
        // In Sandbox, we cannot reliably kill processes by PID using kill() or ps.
        // The most reliable way is RPC shutdown.
        
        print("EngineProcess: Cleanup - Trying RPC shutdown on port \(currentPort)...")
        if testConnection(port: currentPort, secret: currentSecret) {
            print("EngineProcess: Lingering aria2 found on port \(currentPort) with valid secret. Shutting down...")
            sendRpcShutdown(port: currentPort, secret: currentSecret, force: true)
            Thread.sleep(forTimeInterval: 1.0)
        } else {
            print("EngineProcess: Port \(currentPort) is either free or using a different secret.")
        }

        // We can still try terminate() on our own process object if it exists
        if let proc = process, proc.isRunning {
            proc.terminate()
            proc.waitUntilExit()
        }
        
        removePidFile()
        Thread.sleep(forTimeInterval: 0.5)
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
            "rpc-save-upload-metadata=true",
            "check-certificate=false", // Disable strict SSL check to prevent handshake failures
            "--rpc-allow-origin-all=true"
        ]
    }
    
    private static func generateSecret() -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<16).map { _ in letters.randomElement()! })
    }
}
