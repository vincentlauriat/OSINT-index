import Foundation

struct Catalog: Codable {
    struct Source: Codable {
        let importedFrom: String
        let importedAt: Date
        let license: String
    }

    let version: Int
    let generatedAt: Date
    let source: Source
    let categories: [ToolCategory]
}
