import SwiftUI

struct ToolListView: View {
    @Environment(AppSettings.self) private var settings
    @Bindable var vm: CatalogViewModel
    let title: String
    let tools: [OsintTool]

    var body: some View {
        List(tools) { tool in
            ToolRowView(
                tool: tool,
                isFavorite: vm.favorites.isFavorite(tool.id),
                onToggleFavorite: { vm.toggleFavorite(tool) }
            )
        }
        .navigationTitle(title)
        .overlay {
            if tools.isEmpty && !vm.isLoading {
                ContentUnavailableView(
                    settings.t("no_tools_title"),
                    systemImage: "tray",
                    description: Text(settings.t("no_tools_desc"))
                )
            }
        }
    }
}
