import Foundation

struct OsintTool: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let url: URL
    let notes: String?
    let addedManually: Bool
}
