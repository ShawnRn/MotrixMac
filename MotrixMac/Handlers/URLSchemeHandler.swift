import AppKit
import Foundation

// Notification for opening main window
extension Notification.Name {
    static let openMainWindow = Notification.Name("openMainWindow")
}

/// Handles URL schemes for magnet links, thunder links, etc.
class URLSchemeHandler {
    static let shared = URLSchemeHandler()

    private init() {}

    /// Supported URL schemes
    enum Scheme: String, CaseIterable {
        case motrix = "motrix"
        case motrixmac = "motrixmac"
        case mo = "mo"
        case magnet = "magnet"
        case thunder = "thunder"

        static func from(_ url: URL) -> Scheme? {
            guard let scheme = url.scheme?.lowercased() else { return nil }
            return Scheme(rawValue: scheme)
        }
    }

    // MARK: - URL Handling

    func handle(_ url: URL) {
        guard let scheme = Scheme.from(url) else {
            print("Unsupported URL scheme: \(url.scheme ?? "nil")")
            return
        }

        switch scheme {
        case .motrix, .motrixmac, .mo:
            handleMotrixURL(url)
        case .magnet:
            handleMagnetURL(url)
        case .thunder:
            handleThunderURL(url)
        }
    }

    private func handleMotrixURL(_ url: URL) {
        // motrix://add?url=xxx
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return
        }

        let host = components.host ?? ""
        let path = components.path.trimmingCharacters(in: ["/"])
        let command = host.isEmpty ? path : host

        switch command {
        case "add":
            if let downloadURL = components.queryItems?.first(where: { $0.name == "url" })?.value {
                addDownload(uri: downloadURL)
            }
        case "show", "open":
            // Bring app to foreground and open main window
            openMainWindow()
        default:
            print("Unknown motrix command: \(command)")
        }
    }

    private func openMainWindow() {
        // Activate app
        NSApp.activate(ignoringOtherApps: true)

        // Check if main window exists, if not create it
        if let mainWindow = NSApp.windows.first(where: {
            $0.canBecomeMain && $0.identifier?.rawValue != "com_apple_SwiftUI_Settings_window"
        }) {
            mainWindow.makeKeyAndOrderFront(nil)
        } else {
            // Open main window using SwiftUI environment
            // Post notification to open main window
            NotificationCenter.default.post(name: .openMainWindow, object: nil)
        }
    }

    private func handleMagnetURL(_ url: URL) {
        // magnet:?xt=urn:btih:...
        addDownload(uri: url.absoluteString)
    }

    private func handleThunderURL(_ url: URL) {
        // thunder://base64encodedurl
        // Decode the thunder link
        guard
            let encoded = url.absoluteString.dropFirst("thunder://".count).removingPercentEncoding,
            let data = Data(base64Encoded: String(encoded)),
            var decoded = String(data: data, encoding: .utf8)
        else {
            print("Failed to decode thunder URL")
            return
        }

        // Thunder links are wrapped with "AA" prefix and "ZZ" suffix
        if decoded.hasPrefix("AA") {
            decoded = String(decoded.dropFirst(2))
        }
        if decoded.hasSuffix("ZZ") {
            decoded = String(decoded.dropLast(2))
        }

        addDownload(uri: decoded)
    }

    private func addDownload(uri: String) {
        // Show main window
        NSApp.activate(ignoringOtherApps: true)

        // Add to download manager
        Task {
            let manager = DownloadManager.shared
            manager.showAddTaskSheet = true

            // Pre-fill the URL (this would need UI binding)
            // For now, we directly add it
            do {
                let dir =
                    UserDefaults.standard.string(forKey: "defaultDownloadDirectory")
                    ?? FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)
                    .first!.path

                try await manager.addDownload(uri: uri, options: ["dir": dir])
            } catch {
                print("Failed to add download: \(error)")
            }
        }
    }

    // MARK: - Registration (Moved to Info.plist/Modern API)
}

// MARK: - Browser Extension Support

/// Handles communication with browser extensions via native messaging
class BrowserExtensionHandler {
    static let shared = BrowserExtensionHandler()

    private init() {}

    /// Process message from browser extension
    func processMessage(_ message: [String: Any]) {
        guard let type = message["type"] as? String else { return }

        switch type {
        case "addUri":
            if let uri = message["uri"] as? String,
                let options = message["options"] as? [String: Any]
            {
                Task {
                    try? await DownloadManager.shared.addDownload(uri: uri, options: options)
                }
            }

        case "ping":
            // Respond to ping from extension
            sendResponse(["type": "pong", "version": "1.0"])

        default:
            print("Unknown message type: \(type)")
        }
    }

    private func sendResponse(_ response: [String: Any]) {
        // Send response back to extension via stdout (native messaging protocol)
        if let data = try? JSONSerialization.data(withJSONObject: response),
            let message = String(data: data, encoding: .utf8)
        {
            // Write message length as 4 bytes followed by message
            var length = UInt32(message.utf8.count)
            let lengthData = Data(bytes: &length, count: 4)
            FileHandle.standardOutput.write(lengthData)
            FileHandle.standardOutput.write(message.data(using: .utf8)!)
        }
    }
}
