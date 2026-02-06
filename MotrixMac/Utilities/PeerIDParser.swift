import Foundation

struct PeerIDParser {
    
    /// 将原始 PeerID 转换为可读的客户端名称
    /// 例如: "%2DqB4600%2D..." -> "qBittorrent 4.6.0"
    /// 将原始 PeerID 转换为可读的客户端名称
    /// 例如: "%2DqB4600%2D..." -> "qBittorrent 4.6.0"
    nonisolated static func parse(peerID: String) -> String {
        // 1. URL 解码 (这是解决乱码的关键)
        // Aria2 返回的通常是 percent-encoded 的字符串
        guard let decoded = peerID.removingPercentEncoding else {
            return peerID // 如果解码失败，返回原始值
        }
        
        // 2. 处理 Azureus 风格 (最常见的格式: -XX0000-)
        // 格式: -[Client ID][Version]-
        if decoded.count >= 8 && decoded.hasPrefix("-") {
            let prefix = String(decoded.prefix(3).suffix(2)) // 获取中间两个字母，如 qB
            
            if let clientName = clientCodeMap[prefix] {
                // 尝试提取版本号
                let versionStr = String(decoded.dropFirst(3).prefix(4))
                let formattedVersion = formatVersion(versionStr)
                return "\(clientName) \(formattedVersion)"
            }
        }
        
        // 3. 处理其他特殊客户端
        if decoded.hasPrefix("M") { return "BitTorrent Mainline" }
        if decoded.hasPrefix("Q") { return "Queen Bee" }
        
        // 4. 迅雷 (Xunlei) 经常使用非常怪异的 PeerID，通常以 -XL 开头，或者全是 SD
        if decoded.hasPrefix("-XL") || decoded.contains("Xunlei") {
            return "Xunlei"
        }
        
        // 5. 如果实在识别不出来，为了美观，只显示解码后的前8位，避免满屏乱码
        // 过滤掉不可见字符
        let clean = decoded.filter { char in
            guard let val = char.asciiValue else { return false }
            return val >= 32 && val != 127
        }
        if clean.isEmpty {
            return "[Unknown Client]"
        }
        return clean
    }
    
    // 将 "4600" 格式化为 "4.6.0"
    nonisolated private static func formatVersion(_ raw: String) -> String {
        guard raw.count == 4 else { return raw }
        let chars = Array(raw)
        return "\(chars[0]).\(chars[1]).\(chars[2])"
    }
    
    // 客户端代码映射表
    nonisolated private static let clientCodeMap: [String: String] = [
        "qB": "qBittorrent",
        "TR": "Transmission",
        "UT": "µTorrent",
        "UE": "µTorrent Embedded",
        "UM": "µTorrent Mac",
        "DE": "Deluge",
        "LT": "libtorrent",
        "AZ": "Vuze",
        "BT": "BitTorrent",
        "BB": "BitComet",
        "BC": "BitComet",
        "BF": "BitFlu",
        "BG": "BTG",
        "BR": "BitRocket",
        "BS": "BTSlave",
        "BX": "BittorrentX",
        "CD": "Enhanced CTorrent",
        "CT": "CTorrent",
        "FC": "FileCroc",
        "FT": "FoxTorrent",
        "GR": "GetRight",
        "HN": "Halite",
        "LC": "LeechCraft",
        "LW": "LimeWire",
        "MO": "MonoTorrent",
        "MP": "MooPolice",
        "MR": "Miro",
        "MT": "Moonlight",
        "NX": "NetTransport",
        "PD": "Pando",
        "QD": "QQDownload",
        "RT": "Retriever",
        "RZ": "RezTorrent",
        "SS": "SwarmScope",
        "SZ": "Shareaza",
        "TN": "TorrentDotNET",
        "TS": "TorrentStorm",
        "UL": "uLeecher",
        "WD": "WebTorrent Desktop",
        "WY": "FireTorrent",
        "XL": "Xunlei", // 迅雷
        "XT": "XanTorrent",
        "XX": "Xtorrent",
        "ZT": "ZipTorrent"
    ]
}
