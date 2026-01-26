import Foundation
import AppKit

/// Manages the WebExtension Native Messaging protocol and manifest registration
class NativeMessagingManager {
    static let shared = NativeMessagingManager()
    
    // The designated name for the Native Messaging Host
    private let hostName = "com.shawnrain.motrixmac"
    
    private init() {}
    
    // MARK: - Logging Helper
    
    /// Log to stderr to avoid corrupting stdout (which is used for the protocol)
    private func log(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logMessage = "[\(timestamp)] [NativeMessaging] \(message)\n"
        if let data = logMessage.data(using: .utf8) {
            FileHandle.standardError.write(data)
        }
    }
    
    // MARK: - Manifest Installation
    
    func installManifests() {
        let appPath = Bundle.main.bundlePath
        let executablePath = (appPath as NSString).appendingPathComponent("Contents/MacOS/MotrixMac")
        
        let manifest: [String: Any] = [
            "name": hostName,
            "description": "MotrixMac Native Messaging Host",
            "path": executablePath,
            "type": "stdio",
            "allowed_origins": [
                "chrome-extension://aglhhegbfefdallaoidfclmpcdfgdllo/", 
                "chrome-extension://aglhhegbfefdallaoidfclmpcdfgdllo",
                "extension://aglhhegbfefdallaoidfclmpcdfgdllo/", // Edge specific safety
                "extension://aglhhegbfefdallaoidfclmpcdfgdllo",
                "chrome-extension://kommacjdeicndenjdodbgglglmfbfoio/",
                "chrome-extension://ghmbeeafjkmkbbhdcoaabmaonocpdpnc/",
                "chrome-extension://{9ce99d37-4a5e-409a-a04b-0f3f50491bc7}/"
            ],
            "allowed_extensions": [
                "{9ce99d37-4a5e-409a-a04b-0f3f50491bc7}"
            ]
        ]
        
        guard let data = try? JSONSerialization.data(withJSONObject: manifest, options: .prettyPrinted) else {
            return
        }
        
        let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
        let appSupport = library.appendingPathComponent("Application Support")
        
        let paths = [
            appSupport.appendingPathComponent("Google/Chrome/NativeMessagingHosts"),
            appSupport.appendingPathComponent("Google/Chrome Beta/NativeMessagingHosts"),
            appSupport.appendingPathComponent("Google/Chrome Canary/NativeMessagingHosts"),
            appSupport.appendingPathComponent("Microsoft Edge/NativeMessagingHosts"),
            appSupport.appendingPathComponent("Microsoft Edge Beta/NativeMessagingHosts"),
            appSupport.appendingPathComponent("Microsoft Edge Canary/NativeMessagingHosts"),
            appSupport.appendingPathComponent("Mozilla/NativeMessagingHosts")
        ]
        
        for dir in paths {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let fileURL = dir.appendingPathComponent("\(hostName).json")
            try? data.write(to: fileURL)
            self.log("Installed host manifest at \(fileURL.path)")
        }
    }
    
    // MARK: - Communication Protocol
    
    /// Headless entry point for Native Messaging
    func runHeadlessLoop() {
        self.log("Starting headless messaging worker")
        
        let stdin = FileHandle.standardInput
        
        while true {
            // Read 4-byte length
            let lengthData = stdin.readData(ofLength: 4)
            guard lengthData.count == 4 else { break }
            
            let length = lengthData.withUnsafeBytes { $0.load(as: UInt32.self) }
            guard length > 0 else { continue }
            
            // Read JSON message
            let jsonData = stdin.readData(ofLength: Int(length))
            guard jsonData.count == Int(length) else { break }
            
            if let message = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                self.handleCommand(message)
            }
        }
        
        self.log("Headless worker exiting")
        exit(0)
    }
    
    private func handleCommand(_ message: [String: Any]) {
        self.log("Received command: \(message)")
        
        // Strategy: Use NSWorkspace to trigger the main GUI app
        if let action = message["action"] as? String {
            var urlString = "motrixmac://\(action)"
            if let urlParam = message["url"] as? String {
                let encodedUrl = urlParam.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? urlParam
                urlString += (urlString.contains("?") ? "&" : "?") + "url=\(encodedUrl)"
            }
            
            if let url = URL(string: urlString) {
                // This will either wake the app or launch it as a separate GUI process
                NSWorkspace.shared.open(url)
                self.log("Triggered URL Scheme: \(urlString)")
            }
        }
        
        // Send success response
        sendResponse(["status": "acknowledged", "host": "MotrixMac.app"])
    }
    
    private func sendResponse(_ response: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: response) else { return }
        
        var length = UInt32(data.count)
        let lengthData = Data(bytes: &length, count: 4)
        
        let stdout = FileHandle.standardOutput
        stdout.write(lengthData)
        stdout.write(data)
    }
}
