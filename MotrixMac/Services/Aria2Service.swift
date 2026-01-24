import Foundation
import Starscream

/// Service for communicating with aria2 via JSON-RPC over WebSocket
actor Aria2Service {
    private let host: String
    private let port: Int
    private let secret: String
    private var socket: WebSocket?
    private var requestId = 0
    private var pendingRequests: [String: CheckedContinuation<Any, Error>] = [:]

    init(host: String, port: Int, secret: String) {
        self.host = host
        self.port = port
        self.secret = secret
    }

    // MARK: - Connection

    func connect() async throws {
        let urlString = "ws://\(host):\(port)/jsonrpc"
        guard let url = URL(string: urlString) else {
            throw Aria2Error.invalidURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 5

        return try await withCheckedThrowingContinuation { continuation in
            self.connectContinuation = continuation
            socket = WebSocket(request: request)

            socket?.onEvent = { [weak self] event in
                Task {
                    await self?.handleEvent(event)
                }
            }
            
            // Add connection timeout
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 5 * 1_000_000_000) // 5s timeout
                await self?.timeoutConnection()
            }

            socket?.connect()
        }
    }
    
    private func timeoutConnection() {
        if let cont = self.connectContinuation {
            print("Aria2Service: Connection timeout")
            self.connectContinuation = nil
            cont.resume(throwing: Aria2Error.connectionFailed)
            socket?.disconnect()
        }
    }

    func disconnect() async {
        socket?.disconnect()
        socket = nil
    }

    private var connectContinuation: CheckedContinuation<Void, Error>?

    private func handleEvent(_ event: WebSocketEvent) {
        switch event {
        case .connected:
            if let continuation = connectContinuation {
                self.connectContinuation = nil
                continuation.resume()
            }

        case .disconnected(let reason, let code):
            print("Disconnected: \(reason) (\(code))")
            if let continuation = connectContinuation {
                self.connectContinuation = nil
                continuation.resume(throwing: Aria2Error.connectionFailed)
            }

        case .text(let text):
            handleResponse(text)

        case .error(let error):
            if let continuation = connectContinuation {
                self.connectContinuation = nil
                continuation.resume(throwing: error ?? Aria2Error.connectionFailed)
            }

        default:
            break
        }
    }

    private var onNotification: (@Sendable (String, [Any]) -> Void)?

    func setOnNotification(_ handler: @escaping @Sendable (String, [Any]) -> Void) {
        self.onNotification = handler
    }

    private func handleResponse(_ text: String) {
        guard let data = text.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }

        // Handle method invocation response (has id)
        if let id = json["id"] as? String {
            if let continuation = pendingRequests.removeValue(forKey: id) {
                if let error = json["error"] as? [String: Any],
                    let message = error["message"] as? String
                {
                    continuation.resume(throwing: Aria2Error.rpcError(message))
                } else if let result = json["result"] {
                    continuation.resume(returning: result)
                } else {
                    continuation.resume(throwing: Aria2Error.invalidResponse)
                }
            }
        }
        // Handle server notification (has method, no id)
        else if let method = json["method"] as? String,
            let params = json["params"] as? [Any]
        {
            let handler = onNotification
            Task { @MainActor in
                handler?(method, params)
            }
        }
    }

    // MARK: - RPC Methods

    private func call(method: String, params: [Any] = []) async throws -> Any {
        guard socket != nil else {
            throw Aria2Error.connectionFailed
        }

        requestId += 1
        let id = "motrix-\(requestId)"

        var fullParams: [Any] = []
        if !secret.isEmpty {
            fullParams.append("token:\(secret)")
        }
        fullParams.append(contentsOf: params)

        let request: [String: Any] = [
            "jsonrpc": "2.0",
            "id": id,
            "method": method,
            "params": fullParams,
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: request),
            let text = String(data: data, encoding: .utf8)
        else {
            throw Aria2Error.invalidRequest
        }

        return try await withCheckedThrowingContinuation { continuation in
            pendingRequests[id] = continuation
            socket?.write(string: text)

            // Timeout to clean up pendingRequests if no response is received
            Task {
                try? await Task.sleep(nanoseconds: 10 * 1_000_000_000) // 10s
                if let _ = self.pendingRequests[id] {
                    self.pendingRequests.removeValue(forKey: id)?.resume(throwing: Aria2Error.rpcError("Request timeout"))
                }
            }
        }
    }

    // MARK: - Download Control

    func addUri(uris: [String], options: [String: Any] = [:]) async throws -> String {
        let result = try await call(method: "aria2.addUri", params: [uris, options])
        guard let gid = result as? String else {
            throw Aria2Error.invalidResponse
        }
        return gid
    }

    func addTorrent(torrent: String, options: [String: Any] = [:]) async throws -> String {
        let result = try await call(method: "aria2.addTorrent", params: [torrent, [], options])
        guard let gid = result as? String else {
            throw Aria2Error.invalidResponse
        }
        return gid
    }

    func addMetalink(metalink: String, options: [String: Any] = [:]) async throws -> [String] {
        let result = try await call(method: "aria2.addMetalink", params: [metalink, options])
        guard let gids = result as? [String] else {
            throw Aria2Error.invalidResponse
        }
        return gids
    }

    func changeGlobalOption(options: [String: String]) async throws {
        _ = try await call(method: "aria2.changeGlobalOption", params: [options])
    }

    func changeOption(gid: String, options: [String: String]) async throws {
        _ = try await call(method: "aria2.changeOption", params: [gid, options])
    }

    func remove(gid: String) async throws {
        _ = try await call(method: "aria2.remove", params: [gid])
    }

    func forceRemove(gid: String) async throws {
        _ = try await call(method: "aria2.forceRemove", params: [gid])
    }

    func pause(gid: String) async throws {
        _ = try await call(method: "aria2.pause", params: [gid])
    }

    func pauseAll() async throws {
        _ = try await call(method: "aria2.pauseAll")
    }

    func forcePause(gid: String) async throws {
        _ = try await call(method: "aria2.forcePause", params: [gid])
    }

    func unpause(gid: String) async throws {
        _ = try await call(method: "aria2.unpause", params: [gid])
    }

    func unpauseAll() async throws {
        _ = try await call(method: "aria2.unpauseAll")
    }

    func removeDownloadResult(gid: String) async throws {
        _ = try await call(method: "aria2.removeDownloadResult", params: [gid])
    }

    func purgeDownloadResult() async throws {
        _ = try await call(method: "aria2.purgeDownloadResult")
    }

    // MARK: - Status Queries

    func tellStatus(gid: String) async throws -> DownloadTask {
        let result = try await call(method: "aria2.tellStatus", params: [gid])
        guard let dict = result as? [String: Any] else {
            throw Aria2Error.invalidResponse
        }
        return parseTask(from: dict)
    }

    func tellActive() async throws -> [DownloadTask] {
        let result = try await call(method: "aria2.tellActive")
        guard let array = result as? [[String: Any]] else {
            throw Aria2Error.invalidResponse
        }
        return array.map { parseTask(from: $0) }
    }

    func tellWaiting(offset: Int, num: Int) async throws -> [DownloadTask] {
        let result = try await call(method: "aria2.tellWaiting", params: [offset, num])
        guard let array = result as? [[String: Any]] else {
            throw Aria2Error.invalidResponse
        }
        return array.map { parseTask(from: $0) }
    }

    func tellStopped(offset: Int, num: Int) async throws -> [DownloadTask] {
        let result = try await call(method: "aria2.tellStopped", params: [offset, num])
        guard let array = result as? [[String: Any]] else {
            throw Aria2Error.invalidResponse
        }
        return array.map { parseTask(from: $0) }
    }

    func getGlobalStat() async throws -> GlobalStats {
        let result = try await call(method: "aria2.getGlobalStat")
        guard let dict = result as? [String: Any] else {
            throw Aria2Error.invalidResponse
        }
        return GlobalStats(
            downloadSpeed: Int64(dict["downloadSpeed"] as? String ?? "0") ?? 0,
            uploadSpeed: Int64(dict["uploadSpeed"] as? String ?? "0") ?? 0,
            numActive: Int(dict["numActive"] as? String ?? "0") ?? 0,
            numWaiting: Int(dict["numWaiting"] as? String ?? "0") ?? 0,
            numStopped: Int(dict["numStopped"] as? String ?? "0") ?? 0
        )
    }

    func getVersion() async throws -> String {
        let result = try await call(method: "aria2.getVersion")
        guard let dict = result as? [String: Any],
              let version = dict["version"] as? String else {
            throw Aria2Error.invalidResponse
        }
        return version
    }

    func checkAuth() async throws -> Bool {
        _ = try await getVersion()
        return true
    }

    func shutdown(force: Bool = false) async throws {
        let method = force ? "aria2.forceShutdown" : "aria2.shutdown"
        _ = try await call(method: method)
    }

    // MARK: - Parsing

    private func parseTask(from dict: [String: Any]) -> DownloadTask {
        let gid = dict["gid"] as? String ?? ""

        let status = dict["status"] as? String ?? "unknown"

        // Helper to parse string or number
        func parseInt64(_ key: String) -> Int64 {
            if let string = dict[key] as? String {
                return Int64(string) ?? 0
            } else if let number = dict[key] as? NSNumber {
                return number.int64Value
            }
            return 0
        }

        func parseInt(_ key: String) -> Int {
            if let string = dict[key] as? String {
                return Int(string) ?? 0
            } else if let number = dict[key] as? NSNumber {
                return number.intValue
            }
            return 0
        }

        // DEBUG: Print raw dictionary for first active task to debug "0 progress"
        if dict["status"] as? String == "active" {
            print("DEBUG: Active Task Dictionary: \(dict)")
        }

        let totalLength = parseInt64("totalLength")
        let completedLength = parseInt64("completedLength")
        let downloadSpeed = parseInt64("downloadSpeed")
        let uploadSpeed = parseInt64("uploadSpeed")
        let connections = parseInt("connections")
        let numSeeders = parseInt("numSeeders")
        let numPieces = parseInt("numPieces")
        let infoHash = dict["infoHash"] as? String
        let dir = dict["dir"] as? String ?? ""
        let errorMessage = dict["errorMessage"] as? String

        // Parse files
        var files: [TaskFile] = []
        if let filesArray = dict["files"] as? [[String: Any]] {
            files = filesArray.enumerated().map { index, fileDict in

                func parseFileInt64(_ dict: [String: Any], _ key: String) -> Int64 {
                    if let string = dict[key] as? String {
                        return Int64(string) ?? 0
                    } else if let number = dict[key] as? NSNumber {
                        return number.int64Value
                    }
                    return 0
                }

                return TaskFile(
                    index: index,
                    path: fileDict["path"] as? String ?? "",
                    length: parseFileInt64(fileDict, "length"),
                    completedLength: parseFileInt64(fileDict, "completedLength"),
                    selected: (fileDict["selected"] as? String) == "true",
                    uris: (fileDict["uris"] as? [[String: Any]])?.compactMap {
                        $0["uri"] as? String
                    } ?? []
                )
            }
        }

        // Get name from first file or bittorrent info
        var name = "Unknown"
        if let btInfo = dict["bittorrent"] as? [String: Any],
            let info = btInfo["info"] as? [String: Any],
            let btName = info["name"] as? String
        {
            name = btName
        } else if let firstFile = files.first, !firstFile.path.isEmpty {
            name = (firstFile.path as NSString).lastPathComponent
        } else if let firstFile = files.first, let firstUri = firstFile.uris.first {
            // Fallback to URI filename
            if let url = URL(string: firstUri) {
                let lastComponent = url.lastPathComponent
                if !lastComponent.isEmpty {
                    name = lastComponent
                }
            }
        }

        // Parse peers
        let peers: [TaskPeer] = []
        // Peers require separate call to aria2.getPeers

        // Parse trackers
        let trackers: [TaskTracker] = []
        // Trackers can be parsed from bittorrent.announceList

        return DownloadTask(
            id: gid,
            name: name,
            uri: files.first?.uris.first ?? "",
            dir: dir,
            status: status,
            totalLength: totalLength,
            completedLength: completedLength,
            downloadSpeed: downloadSpeed,
            uploadSpeed: uploadSpeed,
            connections: connections,
            numSeeders: numSeeders,
            numPieces: numPieces,
            infoHash: infoHash,
            files: files,
            peers: peers,
            trackers: trackers,
            addedAt: Date(),  // Would need to track this separately
            errorMessage: errorMessage,
            bitfield: dict["bitfield"] as? String
        )
    }
}

// MARK: - Types

struct GlobalStats {
    let downloadSpeed: Int64
    let uploadSpeed: Int64
    let numActive: Int
    let numWaiting: Int
    let numStopped: Int
}

enum Aria2Error: LocalizedError {
    case invalidURL
    case connectionFailed
    case invalidRequest
    case invalidResponse
    case rpcError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid RPC URL"
        case .connectionFailed:
            return "Failed to connect to aria2"
        case .invalidRequest:
            return "Invalid request"
        case .invalidResponse:
            return "Invalid response from aria2"
        case .rpcError(let message):
            return message
        }
    }
}
