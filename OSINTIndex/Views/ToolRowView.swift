import SwiftUI

struct ToolRowView: View {
    let tool: OsintTool
    let isFavorite: Bool
    let onToggleFavorite: () -> Void

    var body: some View {
        HStack {
            Link(destination: tool.url) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tool.name)
                        .font(.body)
                        .lineLimit(2)
                    Text(tool.url.host ?? tool.url.absoluteString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            Button(action: onToggleFavorite) {
                Image(systemName: isFavorite ? "star.fill" : "star")
                    .foregroundStyle(isFavorite ? .yellow : .secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
    }
}
