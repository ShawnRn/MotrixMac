import Foundation
import SwiftUI

/// Core models for the MotrixMac application

/// Represents a download task from aria2
struct DownloadTask: Identifiable, Equatable, Codable {
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
        case infoHash, files, peers, trackers, addedAt, errorMessage, bitfield
    }

    // Computed properties
    var progress: Double {
        guard totalLength > 0 else {
            return 0
        }
        return Double(completedLength) / Double(totalLength)
    }

    var isIndeterminate: Bool {
        isActive && totalLength <= 0
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

    var fileType: FileType {
        FileType.from(filename: name)
    }

    var eta: String {
        if displayStatus == "Connecting..." { return "--" }
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

    var displayStatus: String {
        if status == "active" {
            if totalLength == 0 && completedLength == 0 && connections == 0 {
                return "Connecting..."
            }
            if totalLength == 0 && completedLength == 0 && connections > 0 {
                return "Downloading"
            }
        }

        switch status {
        case "active": return "下载中"
        case "waiting": return "等待中"
        case "paused": return "已暂停"
        case "complete": return "已完成"
        case "error": return "出现错误"
        case "removed": return "已取消"
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
struct TaskPeer: Equatable, Codable {
    let ip: String
    let port: Int
    let client: String
    let downloadSpeed: Int64
    let uploadSpeed: Int64
    let seeder: Bool
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

    var title: String {
        switch self {
        case .downloading: return "下载中"
        case .completed: return "已完成"
        case .settings: return "设置"
        case .about: return "关于 MotrixMac"
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
                errorMessage: nil,
                downloadSpeedHistory: []
            ),
        ]
    }
}
