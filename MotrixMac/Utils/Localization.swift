import Foundation
import SwiftUI

class LocalizationManager {
    static let shared = LocalizationManager()
    
    func string(_ key: String, language: String) -> String {
        // Step 1: Try finding in Localizable.xcstrings/strings via Bundle
        // Using String catalog as the single source of truth.
        
        // Normalize language code for .lproj lookup
        var code = language
        if language == "zh-CN" || language == "zh-Hans-CN" { code = "zh-Hans" }
        else if language == "zh-TW" || language == "zh-Hant-TW" || language == "zh-HK" { code = "zh-Hant" }
        
        // Double check standard codes if passed directly
        if language == "zh-Hans" { code = "zh-Hans" }
        if language == "zh-Hant" { code = "zh-Hant" }

        let bundle: Bundle
        if let path = Bundle.main.path(forResource: code, ofType: "lproj"),
           let langBundle = Bundle(path: path) {
            bundle = langBundle
        } else {
            // Fallback to trying the original code if normalized failed
             if let path = Bundle.main.path(forResource: language, ofType: "lproj"),
               let langBundle = Bundle(path: path) {
                bundle = langBundle
            } else {
                bundle = Bundle.main
            }
        }
        
        // NSLocalizedString with a specific bundle allows on-the-fly language switching
        let localizedString = bundle.localizedString(forKey: key, value: nil, table: nil)
        
        // Return translated string if found, otherwise return the key itself
        return localizedString
    }
}

extension String {
    func localized(for language: String) -> String {
        LocalizationManager.shared.string(self, language: language)
    }
}
