import Foundation

struct LicenseItem: Codable, Identifiable {
    var id: String { name }
    let name: String
    let license: String
    let description: String
    let type: String // "Core", "UI", "Tooling"
}

struct ChangelogItem: Codable, Identifiable {
    var id: String { version }
    let version: String
    let date: String
    let changes: [String]
}
