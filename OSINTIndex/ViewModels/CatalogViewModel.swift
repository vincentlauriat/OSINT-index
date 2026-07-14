import Foundation
import Observation

@Observable
@MainActor
final class CatalogViewModel {
    private let loader: CatalogLoader
    let favorites: FavoritesStore

    var categories: [ToolCategory] = []
    var searchText: String = ""
    var isLoading = false
    var errorMessageKey: String?
    var lastSource: CatalogSource?

    init(loader: CatalogLoader = CatalogLoader(), favorites: FavoritesStore? = nil) {
        self.loader = loader
        self.favorites = favorites ?? FavoritesStore()
    }

    var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Matches on tool name, or includes a whole category's tools when the category name matches.
    var searchResults: [OsintTool] {
        guard isSearching else { return [] }
        let query = searchText
        return categories.flatMap { category -> [OsintTool] in
            let categoryMatches = category.name.localizedCaseInsensitiveContains(query)
            return category.tools.filter {
                categoryMatches || $0.name.localizedCaseInsensitiveContains(query)
            }
        }
    }

    var favoriteTools: [OsintTool] {
        let favoriteIDs = favorites.ids
        return categories.flatMap { $0.tools }.filter { favoriteIDs.contains($0.id) }
    }

    func load() async {
        isLoading = true
        errorMessageKey = nil
        if let result = await loader.load() {
            categories = result.catalog.categories.sorted { $0.order < $1.order }
            lastSource = result.source
        } else {
            errorMessageKey = "catalog_load_error"
        }
        isLoading = false
    }

    func refresh() async {
        await load()
    }

    func toggleFavorite(_ tool: OsintTool) {
        favorites.toggle(tool.id)
    }
}
