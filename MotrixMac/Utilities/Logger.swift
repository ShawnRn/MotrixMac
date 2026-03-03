import Foundation
import os
import SwiftUI
import Combine

enum LogLevel: Int, CaseIterable, Identifiable, CustomStringConvertible {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3
    case off = 4
    
    var id: Int { rawValue }
    
    var description: String {
        switch self {
        case .debug: return "Debug"
        case .info: return "Info"
        case .warning: return "Warning"
        case .error: return "Error"
        case .off: return "Off"
        }
    }
    
    var emoji: String {
        switch self {
        case .debug: return "🐞"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "🚨"
        case .off: return ""
        }
    }
}

final class Logger: ObservableObject {
    static let shared = Logger()
    
    @Published var level: LogLevel {
        didSet {
            UserDefaults.standard.set(level.rawValue, forKey: "LogLevel")
            // 同步设置 Sparkle 的日志级别 (0: 错误, 1: 详细)
            UserDefaults.standard.set(level == .debug ? 1 : 0, forKey: "SULogLevel")
        }
    }
    
    private let logger = os.Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.motrix.mac", category: "General")
    private let logFileURL: URL?
    private let fileHandle: FileHandle?
    private let DateFormatter: DateFormatter
    
    private init() {
        let savedLevel = UserDefaults.standard.integer(forKey: "LogLevel")
        self.level = LogLevel(rawValue: savedLevel) ?? .info
        
        self.DateFormatter = Foundation.DateFormatter()
        self.DateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        
        // Setup file logging
        if let libraryUrl = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first {
            let logDir = libraryUrl.appendingPathComponent("Logs/MotrixMac")
            try? FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)
            
            let fileUrl = logDir.appendingPathComponent("app.log")
            self.logFileURL = fileUrl
            
            if !FileManager.default.fileExists(atPath: fileUrl.path) {
                FileManager.default.createFile(atPath: fileUrl.path, contents: nil)
            }
            
            self.fileHandle = try? FileHandle(forWritingTo: fileUrl)
            self.fileHandle?.seekToEndOfFile()
            
            // 确保启动时 Sparkle 日志级别正确
            UserDefaults.standard.set(self.level == .debug ? 1 : 0, forKey: "SULogLevel")
        } else {
            self.logFileURL = nil
            self.fileHandle = nil
        }
    }
    
    func log(_ message: String, level: LogLevel, file: String = #file, function: String = #function, line: Int = #line) {
        guard level.rawValue >= self.level.rawValue else { return }
        
        let filename = (file as NSString).lastPathComponent
        let fullMessage = "\(level.emoji) [\(filename):\(line)] \(function) > \(message)"
        
        // System Log
        switch level {
        case .debug:
            logger.debug("\(fullMessage, privacy: .public)")
        case .info:
            logger.info("\(fullMessage, privacy: .public)")
        case .warning:
            logger.warning("\(fullMessage, privacy: .public)")
        case .error:
            logger.error("\(fullMessage, privacy: .public)")
        case .off:
            break
        }
        
        // Print for Debug Console
        if level != .off {
            print(fullMessage)
        }
        
        // File Log
        if let fileHandle = fileHandle, level != .off {
            let timestamp = DateFormatter.string(from: Date())
            let logEntry = "[\(timestamp)] \(level.description.uppercased()): \(fullMessage)\n"
            
            if let data = logEntry.data(using: .utf8) {
                try? fileHandle.write(contentsOf: data)
            }
        }
    }
    
    deinit {
        try? fileHandle?.close()
    }
    
    static func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        shared.log(message, level: .debug, file: file, function: function, line: line)
    }
    
    static func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        shared.log(message, level: .info, file: file, function: function, line: line)
    }
    
    static func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        shared.log(message, level: .warning, file: file, function: function, line: line)
    }
    
    static func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        shared.log(message, level: .error, file: file, function: function, line: line)
    }
    
    /// 用于不带前缀的纯文本打印，同样受日志级别控制
    static func rawPrint(_ message: String, level: LogLevel = .debug) {
        if level.rawValue >= shared.level.rawValue {
            print(message)
        }
    }
}
