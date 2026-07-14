import Foundation

struct ToolCategory: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let order: Int
    let tools: [OsintTool]
}
