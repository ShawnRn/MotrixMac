import Foundation
import MaxMindDB // 保留你正确的库名

@Observable
final class GeoIPService {
    static let shared = GeoIPService()
    
    // 你的库使用的类名确实是 GeoIP2
    private var reader: GeoIP2?
    
    private init() {
        if let path = Bundle.main.path(forResource: "Country", ofType: "mmdb") {
            // 初始化可能抛出异常，这里捕获一下
            do {
                reader = try GeoIP2(databasePath: path)
                print("GeoIPService: Successfully loaded Country.mmdb")
            } catch {
                print("GeoIPService: Failed to initialize reader: \(error)")
            }
        } else {
            print("GeoIPService: Country.mmdb not found in Bundle")
        }
    }
    
    func lookup(ip: String) -> String? {
        guard let reader = reader else { return nil }
        
        // 核心修复点：
        // 这个库的 lookup(ip) 返回的是 [String: Any]? (字典)
        // 所以不能写 result.country.isoCode，必须像解析 JSON 一样解包字典
        if let result = try? reader.lookup(ip: ip) {
            
            // 1. 取出 "country" 字典 (需从 .data 属性获取)
            if let country = result.data["country"] as? [String: Any],
               // 2. 取出 "iso_code" 字符串
               let isoCode = country["iso_code"] as? String {
                return isoCode
            }
        }
        
        return nil
    }
    
    func flag(for ip: String) -> String {
        guard let isoCode = lookup(ip: ip) else { return "🌐" }
        return isoCode.toFlag()
    }
}

// 你的扩展是完全正确的
extension String {
    func toFlag() -> String {
        let base: UInt32 = 127397
        var s = ""
        for v in self.unicodeScalars {
            s.unicodeScalars.append(UnicodeScalar(base + v.value)!)
        }
        return s
    }
}
