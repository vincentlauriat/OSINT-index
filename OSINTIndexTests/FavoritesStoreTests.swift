import Testing
import Foundation

@MainActor
struct FavoritesStoreTests {
    private func makeStore() -> FavoritesStore {
        let suiteName = "fr.vincentlauriat.osintindex.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        return FavoritesStore(defaults: defaults)
    }

    @Test func startsEmpty() {
        let store = makeStore()
        #expect(store.ids.isEmpty)
        #expect(!store.isFavorite("some-id"))
    }

    @Test func toggleAddsThenRemoves() {
        let store = makeStore()
        store.toggle("category-tool")
        #expect(store.isFavorite("category-tool"))

        store.toggle("category-tool")
        #expect(!store.isFavorite("category-tool"))
    }

    @Test func persistsAcrossInstancesSharingDefaults() {
        let suiteName = "fr.vincentlauriat.osintindex.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!

        let first = FavoritesStore(defaults: defaults)
        first.toggle("category-tool")

        let second = FavoritesStore(defaults: defaults)
        #expect(second.isFavorite("category-tool"))
    }
}
