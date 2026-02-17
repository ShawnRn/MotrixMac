import Foundation
import SwiftUI

/// Core models for the MotrixMac application

/// Represents a download task from aria2
struct DownloadTask: Identifiable, Equatable, Codable, Sendable {
    let id: String  // GID from aria2
    var name: String
    var uri: String
    var dir: String
    var status: String
    var totalLength: Int64
    var completedLength: Int64
    var downloadSpeed: Int64
    var uploadSpeed: Int64
    var connections: Int
    var numSeeders: Int
    var numPieces: Int
    var infoHash: String?
    var files: [TaskFile]
    var peers: [TaskPeer]
    var trackers: [TaskTracker]
    var addedAt: Date
    var completedAt: Date? // [NEW] Track completion time for auto-delete
    var errorMessage: String?
    var bitfield: String?
    var downloadSpeedHistory: [Int64] = []
    
    // Transformed property for UI sorting
    var isFileMissing: Bool = false

    // Pre-calculated strings for UI performance (Scheme A)
    // Excluded from Codable via CodingKeys
    var formattedDownloadSpeed: String = ""
    var formattedSizeText: String = ""
    var formattedETA: String = ""
    var formattedStatusText: String = ""
    var formattedStatusLine: String = ""

    enum CodingKeys: String, CodingKey {
        case id, name, uri, dir, status, totalLength, completedLength
        case downloadSpeed, uploadSpeed, connections, numSeeders, numPieces
        case infoHash, files, peers, trackers, addedAt, completedAt, errorMessage, bitfield
        case downloadSpeedHistory
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        uri = try container.decode(String.self, forKey: .uri)
        dir = try container.decode(String.self, forKey: .dir)
        status = try container.decode(String.self, forKey: .status)
        totalLength = try container.decode(Int64.self, forKey: .totalLength)
        completedLength = try container.decode(Int64.self, forKey: .completedLength)
        downloadSpeed = try container.decode(Int64.self, forKey: .downloadSpeed)
        uploadSpeed = try container.decode(Int64.self, forKey: .uploadSpeed)
        connections = try container.decode(Int.self, forKey: .connections)
        numSeeders = try container.decode(Int.self, forKey: .numSeeders)
        numPieces = try container.decode(Int.self, forKey: .numPieces)
        infoHash = try container.decodeIfPresent(String.self, forKey: .infoHash)
        files = try container.decode([TaskFile].self, forKey: .files)
        peers = (try? container.decode([TaskPeer].self, forKey: .peers)) ?? []
        trackers = (try? container.decode([TaskTracker].self, forKey: .trackers)) ?? []
        addedAt = try container.decode(Date.self, forKey: .addedAt)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        errorMessage = try container.decodeIfPresent(String.self, forKey: .errorMessage)
        bitfield = try container.decodeIfPresent(String.self, forKey: .bitfield)
        downloadSpeedHistory = (try? container.decode([Int64].self, forKey: .downloadSpeedHistory)) ?? []
        
        // Initialize non-persisted properties
        isFileMissing = false
        formattedDownloadSpeed = ""
        formattedSizeText = ""
        formattedETA = ""
        formattedStatusText = ""
        formattedStatusLine = ""
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(uri, forKey: .uri)
        try container.encode(dir, forKey: .dir)
        try container.encode(status, forKey: .status)
        try container.encode(totalLength, forKey: .totalLength)
        try container.encode(completedLength, forKey: .completedLength)
        try container.encode(downloadSpeed, forKey: .downloadSpeed)
        try container.encode(uploadSpeed, forKey: .uploadSpeed)
        try container.encode(connections, forKey: .connections)
        try container.encode(numSeeders, forKey: .numSeeders)
        try container.encode(numPieces, forKey: .numPieces)
        try container.encodeIfPresent(infoHash, forKey: .infoHash)
        try container.encode(files, forKey: .files)
        try container.encode(peers, forKey: .peers)
        try container.encode(trackers, forKey: .trackers)
        try container.encode(addedAt, forKey: .addedAt)
        try container.encodeIfPresent(completedAt, forKey: .completedAt)
        try container.encodeIfPresent(errorMessage, forKey: .errorMessage)
        try container.encodeIfPresent(bitfield, forKey: .bitfield)
        try container.encode(downloadSpeedHistory, forKey: .downloadSpeedHistory)
    }
    
    // Memberwise initializer (Restored manually since custom init(from:) removes the compiler-generated one)
    nonisolated init(
        id: String,
        name: String,
        uri: String,
        dir: String,
        status: String,
        totalLength: Int64,
        completedLength: Int64,
        downloadSpeed: Int64,
        uploadSpeed: Int64,
        connections: Int,
        numSeeders: Int,
        numPieces: Int,
        infoHash: String? = nil,
        files: [TaskFile] = [],
        peers: [TaskPeer] = [],
        trackers: [TaskTracker] = [],
        addedAt: Date = Date(),
        completedAt: Date? = nil,
        errorMessage: String? = nil,
        bitfield: String? = nil,
        downloadSpeedHistory: [Int64] = []
    ) {
        self.id = id
        self.name = name
        self.uri = uri
        self.dir = dir
        self.status = status
        self.totalLength = totalLength
        self.completedLength = completedLength
        self.downloadSpeed = downloadSpeed
        self.uploadSpeed = uploadSpeed
        self.connections = connections
        self.numSeeders = numSeeders
        self.numPieces = numPieces
        self.infoHash = infoHash
        self.files = files
        self.peers = peers
        self.trackers = trackers
        self.addedAt = addedAt
        self.completedAt = completedAt
        self.errorMessage = errorMessage
        self.bitfield = bitfield
        self.downloadSpeedHistory = downloadSpeedHistory
        
        self.isFileMissing = false
        self.formattedDownloadSpeed = ""
        self.formattedSizeText = ""
        self.formattedETA = ""
        self.formattedStatusText = ""
        self.formattedStatusLine = ""
    }

    // Computed properties
    var progress: Double {
        guard totalLength > 0 else {
            return 0
        }
        return Double(completedLength) / Double(totalLength)
    }

    var isIndeterminate: Bool {
        // 做种中或下载完成时不应该是“不确定进度”的
        if isSeeding || status == "complete" { return false }
        return (status == "active" || status == "waiting") && (totalLength <= 0 || (completedLength <= 0 && status != "paused"))
    }

    var isSeeding: Bool {
        // 做种的定义：BT 任务，状态为活跃，且已完成长度等于总长度（且总长度大于0）
        // 或者 aria2 明确报告 uploadSpeed > 0 且下载已完成
        isTorrent && status == "active" && totalLength > 0 && completedLength >= totalLength
    }

    var statusColor: Color {
        if isSeeding { return .indigo }
        switch status {
        case "error": return .red
        case "paused": return .yellow
        case "waiting": return .orange
        case "active": return .accentColor
        case "complete": return .green
        default: return .secondary
        }
    }

    var isActive: Bool {
        status == "active"
    }

    var isTorrent: Bool {
        infoHash != nil
    }

    var canPause: Bool {
        status == "active"
    }

    var canResume: Bool {
        status == "paused" || status == "waiting" || status == "removed"
    }

    var canCancel: Bool {
        status == "active" || status == "waiting" || status == "paused" || status == "error"
    }

    var effectiveName: String {
        if isTorrent && !files.isEmpty {
            let selectedFiles = files.filter { $0.selected }
            if selectedFiles.count == 1, let file = selectedFiles.first {
                return (file.path as NSString).lastPathComponent
            }
        }
        return name
    }

    var fileType: FileType {
        if isTorrent {
            // Intelligent display for multi-file torrents
            if !files.isEmpty {
                let selectedFiles = files.filter { $0.selected }
                
                // If only one file is selected, show its specific type instead of generic folder
                if selectedFiles.count == 1, let file = selectedFiles.first {
                     return FileType.from(filename: file.path)
                }
                
                // If multiple files selected, show folder
                if selectedFiles.count > 1 {
                    return .folder
                }
            }
            
            // Fallback for initial state or empty selection
            return files.count > 1 ? .folder : .torrent
        }
        return FileType.from(filename: name)
    }

    func eta(for language: String) -> String {
        if displayStatus(for: language) == "Connecting...".localized(for: language) { return "--" }
        guard downloadSpeed > 0, totalLength > completedLength else { return "--" }
        let remaining = totalLength - completedLength
        let seconds = remaining / downloadSpeed

        if seconds < 60 {
            return "\(seconds)s"
        } else if seconds < 3600 {
            return "\(seconds / 60)m \(seconds % 60)s"
        } else {
            let hours = seconds / 3600
            let minutes = (seconds % 3600) / 60
            return "\(hours)h \(minutes)m"
        }
    }

    func displayStatus(for language: String) -> String {
        if status == "active" {
            if isSeeding {
                return "做种中".localized(for: language)
            }
            if totalLength == 0 && completedLength == 0 && connections == 0 {
                return "Connecting...".localized(for: language)
            }
            if downloadSpeed == 0 {
                return "等待中".localized(for: language)
            }
            return "下载中".localized(for: language)
        }

        switch status {
        case "active": return "下载中".localized(for: language)
        case "waiting": return "等待中".localized(for: language)
        case "paused": return "已暂停".localized(for: language)
        case "complete": return "已完成".localized(for: language)
        case "error": return "出现错误".localized(for: language)
        case "removed": return "已取消".localized(for: language)
        default: return status.capitalized
        }
    }
}

/// File within a download task
struct TaskFile: Equatable, Codable {
    let index: Int
    let path: String
    let length: Int64
    let completedLength: Int64
    let selected: Bool
    let uris: [String]
}

/// Peer connected to a torrent
struct TaskPeer: Equatable, Codable, Identifiable {
    var id: String { "\(ip):\(port)" }
    let ip: String
    let port: Int
    let client: String // This is the raw peer ID (encoded)
    let downloadSpeed: Int64
    let uploadSpeed: Int64
    let progress: Double
    let seeder: Bool
    let amChoking: Bool   // We are choking this peer (not uploading to them)
    let peerChoking: Bool // Peer is choking us (not uploading to us)
    
    // Computed property for display
    var clientName: String {
        PeerIDParser.parse(peerID: client)
    }
    
    /// Connection status description
    func connectionStatus(for language: String) -> String {
        if seeder {
            return "做种者".localized(for: language)
        } else if amChoking && peerChoking {
            return "阻塞中".localized(for: language)
        } else if amChoking {
            return "等待上传".localized(for: language)
        } else if peerChoking {
            return "等待下载".localized(for: language)
        } else {
            return "传输中".localized(for: language)
        }
    }
}

/// Tracker for a torrent
struct TaskTracker: Equatable, Codable {
    let url: String
    let status: String
    let message: String?
}

/// Task categories for sidebar
enum TaskCategory: String, Identifiable {
    case downloading
    case completed
    case settings
    case about

    var id: String { rawValue }

    func title(for language: String) -> String {
        switch self {
        case .downloading: return "进行中".localized(for: language)
        case .completed: return "已完成".localized(for: language)
        case .settings: return "设置".localized(for: language)
        case .about: return "关于 MotrixMac".localized(for: language)
        }
    }

    var icon: String {
        switch self {
        case .downloading: return "arrow.down.circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .settings: return "gearshape"
        case .about: return "info.circle"
        }
    }

    /// Task categories to display in sidebar (excludes settings and about)
    static var taskCategories: [TaskCategory] {
        [.downloading, .completed]
    }

    var aria2Status: [String] {
        switch self {
        case .downloading: return ["active", "waiting", "paused", "error", "removed"]
        case .completed: return ["complete"]
        case .settings: return []
        case .about: return []
        }
    }
}

// MARK: - File Type

enum FileType {
    case video
    case audio
    case image
    case document
    case archive
    case application
    case apk
    case torrent
    case folder
    case other

    var icon: String {
        switch self {
        case .video: return "film"
        case .audio: return "music.note"
        case .image: return "photo"
        case .document: return "doc.text"
        case .archive: return "archivebox"
        case .application: return "app.gift"
        case .apk: return "app.gift"
        case .torrent: return "dot.radiowaves.left.and.right"
        case .folder: return "folder.fill"
        case .other: return "doc"
        }
    }

    var color: Color {
        switch self {
        case .video: return .purple
        case .audio: return .pink
        case .image: return .orange
        case .document: return .blue
        case .archive: return .brown
        case .application: return .indigo
        case .apk: return Color(red: 61/255, green: 220/255, blue: 132/255) // Android Green
        case .torrent: return .indigo
        case .folder: return .blue
        case .other: return .gray
        }
    }

    static func from(filename: String) -> FileType {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "mp4", "mkv", "avi", "mov", "wmv", "flv", "webm", "m4v":
            return .video
        case "mp3", "flac", "wav", "aac", "m4a", "ogg", "wma", "ape":
            return .audio
        case "jpg", "jpeg", "png", "gif", "webp", "heic", "svg", "bmp", "tiff", "icns":
            return .image
        case "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "md":
            return .document
        case "zip", "rar", "7z", "tar", "gz", "bz2", "xz":
            return .archive
        case "dmg", "pkg", "app", "exe", "msi", "deb", "rpm", "iso":
            return .application
        case "apk":
            return .apk
        default:
            return .other
        }
    }
}

// MARK: - Preview Data

extension DownloadTask {
    static var preview: DownloadTask {
        DownloadTask(
            id: "abc123",
            name: "ubuntu-24.04-desktop-amd64.iso",
            uri: "https://releases.ubuntu.com/24.04/ubuntu-24.04-desktop-amd64.iso",
            dir: "/Users/shawn/Downloads",
            status: "active",
            totalLength: 5_368_709_120,
            completedLength: 2_147_483_648,
            downloadSpeed: 15_728_640,
            uploadSpeed: 524_288,
            connections: 16,
            numSeeders: 42,
            numPieces: 2560,
            infoHash: "abc123def456",
            files: [
                TaskFile(
                    index: 1,
                    path: "/Users/shawn/Downloads/ubuntu-24.04-desktop-amd64.iso",
                    length: 5_368_709_120,
                    completedLength: 2_147_483_648,
                    selected: true,
                    uris: ["https://releases.ubuntu.com/24.04/ubuntu-24.04-desktop-amd64.iso"]
                )
            ],
            peers: [],
            trackers: [],
            addedAt: Date(),
            completedAt: nil,
            errorMessage: nil,
            bitfield: "f0f0f0f0f0f0f0f0f0f0", // Sample bitfield
            downloadSpeedHistory: []
        )
    }

    static var previewList: [DownloadTask] {
        [
            preview,
            DownloadTask(
                id: "def456",
                name: "movie-4k-hevc.mkv",
                uri: "https://example.com/movie.mkv",
                dir: "/Users/shawn/Downloads",
                status: "paused",
                totalLength: 8_589_934_592,
                completedLength: 4_294_967_296,
                downloadSpeed: 0,
                uploadSpeed: 0,
                connections: 0,
                numSeeders: 0,
                numPieces: 0,
                infoHash: nil,
                files: [],
                peers: [],
                trackers: [],
                addedAt: Date().addingTimeInterval(-3600),
                completedAt: nil,
                errorMessage: nil,
                downloadSpeedHistory: []
            ),
        ]
    }
}
