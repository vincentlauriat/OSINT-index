import Foundation
import Observation

/// Local-only favorites, keyed by `OsintTool.id` (category-slug + tool-name slug — not the
/// URL, which drifts over time). Renaming/re-categorizing a tool in a future manual edit of
/// data/osint-tools.json changes its id and silently drops any existing favorite for it —
/// an accepted trade-off given the catalog's size.
@Observable
@MainActor
final class FavoritesStore {
    private static let defaultsKey = "favoriteToolIDs"
    private let defaults: UserDefaults

    private(set) var ids: Set<String>

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.array(forKey: Self.defaultsKey) as? [String] ?? []
        ids = Set(stored)
    }

    func isFavorite(_ id: String) -> Bool {
        ids.contains(id)
    }

    func toggle(_ id: String) {
        if ids.contains(id) {
            ids.remove(id)
        } else {
            ids.insert(id)
        }
        defaults.set(Array(ids), forKey: Self.defaultsKey)
    }
}
