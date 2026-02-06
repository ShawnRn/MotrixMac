import Foundation

extension String {
    /// Converts a two-letter country code (ISO 3166-1 alpha-2) to a flag emoji.
    var flagEmoji: String {
        let base: UInt32 = 127397
        var s = ""
        for v in self.unicodeScalars {
            s.unicodeScalars.append(UnicodeScalar(base + v.value)!)
        }
        return String(s)
    }
}
