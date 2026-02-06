import Foundation
import Combine

actor TrackerService {
    static let shared = TrackerService()
    
    // Default sources from Motrix reference
    private let defaultSources = [
        "https://cdn.jsdelivr.net/gh/ngosang/trackerslist/trackers_best_ip.txt",
        "https://cdn.jsdelivr.net/gh/ngosang/trackerslist/trackers_best.txt"
    ]
    
    private let userDefaults = UserDefaults.standard
    private let session = URLSession.shared
    
    func fetchTrackers() async -> [String] {
        // UI saves as comma-separated string, not array
        let sourcesString = userDefaults.string(forKey: "trackerSource")
        var sources: [String] = []
        
        if let str = sourcesString, !str.isEmpty {
            sources = str.components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                // Map filenames to full URLs (matching logic in PreferencesView)
                .map { source -> String in
                    if source.hasPrefix("http") { return source }
                    return "https://raw.githubusercontent.com/ngosang/trackerslist/master/\(source)"
                }
        }
        
        // 2. Add custom URLs from user settings
        let customUrlsString = userDefaults.string(forKey: "customTrackerURLs") ?? ""
        let customUrls = customUrlsString.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && $0.hasPrefix("http") }
        
        // Combine all sources
        let sourcesToUse = (sources.isEmpty ? defaultSources : sources) + customUrls
        
        var allTrackers: Set<String> = []
        
        await withTaskGroup(of: [String].self) { group in
            for urlString in sourcesToUse {
                guard let url = URL(string: urlString) else { continue }
                group.addTask {
                    return await self.fetchTrackers(from: url)
                }
            }
            
            for await trackers in group {
                for tracker in trackers {
                    allTrackers.insert(tracker)
                }
            }
        }
        
        let sortedTrackers = allTrackers.sorted()
        
        // [Persistence] Save to cachedAutoTrackers for DownloadManager to use in Engine configuration
        let trackersString = sortedTrackers.joined(separator: ",")
        userDefaults.set(trackersString, forKey: "cachedAutoTrackers")
        userDefaults.set(Date().timeIntervalSince1970, forKey: "lastTrackerUpdate")
        userDefaults.synchronize()
        
        return sortedTrackers
    }
    
    private func fetchTrackers(from url: URL) async -> [String] {
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 30
            request.cachePolicy = .reloadIgnoringLocalCacheData
            
            let (data, _) = try await session.data(for: request)
            guard let content = String(data: data, encoding: .utf8) else {
                return []
            }
            
            let lines = content.components(separatedBy: .newlines)
            let result = lines.map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { line in
                    !line.isEmpty &&
                    !line.hasPrefix("#") &&
                    (line.hasPrefix("http") || line.hasPrefix("wss")) && // [Strict] UDP/DHT trackers NOT supported
                    !line.contains("127.0.0.1") &&
                    !line.contains("localhost")
                }
            
            return result
        } catch {
            print("TrackerService: Failed to fetch from \(url) - \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - Auto Update Logic
    
    private var updateTask: Task<Void, Never>?
    
    func startAutoUpdate() {
        stopAutoUpdate()
        
        updateTask = Task {
            while !Task.isCancelled {
                let isEnabled = userDefaults.bool(forKey: "autoSyncTracker")
                if isEnabled {
                    let lastUpdate = userDefaults.double(forKey: "lastTrackerUpdate")
                    let interval = getUpdateInterval()
                    
                    if Date().timeIntervalSince1970 - lastUpdate > interval {
                        print("TrackerService: Starting scheduled tracker update...")
                        _ = await fetchTrackers()
                        
                        // Notify DownloadManager to hot-restart engine if trackers changed
                        // For simplicity, we assume change and just let engine handle it next time it creates config
                        // or we could post a notification.
                        NotificationCenter.default.post(name: NSNotification.Name("TrackersDidUpdate"), object: nil)
                    }
                }
                
                // Check every hour
                try? await Task.sleep(for: .seconds(3600))
            }
        }
    }
    
    func stopAutoUpdate() {
        updateTask?.cancel()
        updateTask = nil
    }
    
    private func getUpdateInterval() -> TimeInterval {
        let intervalStr = userDefaults.string(forKey: "trackerUpdateInterval") ?? "daily"
        switch intervalStr {
        case "12h": return 12 * 3600
        case "daily": return 24 * 3600
        case "weekly": return 7 * 24 * 3600
        case "monthly": return 30 * 24 * 3600
        default: return 24 * 3600
        }
    }
}
