import Testing
import Foundation

/// Decodes the real bundled `data/osint-tools.json` with the app's actual `Catalog` model.
/// This is the regression guard that would have caught the silent-decode-failure bug found
/// during manual review: a single malformed `URL` in any tool entry fails the *entire* decode,
/// not just that row, since `Codable` on `URL` throws on the first invalid string.
struct CatalogDecodeTests {
    private func loadCatalogData() throws -> Data {
        let url = try #require(Bundle(for: BundleToken.self).url(forResource: "osint-tools", withExtension: "json"))
        return try Data(contentsOf: url)
    }

    @Test func bundledCatalogDecodesSuccessfully() throws {
        let data = try loadCatalogData()
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let catalog = try decoder.decode(Catalog.self, from: data)

        #expect(!catalog.categories.isEmpty)
        let totalTools = catalog.categories.reduce(0) { $0 + $1.tools.count }
        #expect(totalTools > 0)
    }

    @Test func toolIDsHaveNoCollisions() throws {
        let data = try loadCatalogData()
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let catalog = try decoder.decode(Catalog.self, from: data)

        let allIDs = catalog.categories.flatMap { $0.tools.map(\.id) }
        #expect(allIDs.count == Set(allIDs).count, "Duplicate tool id found in data/osint-tools.json")
    }

    @Test func categoryIDsHaveNoCollisions() throws {
        let data = try loadCatalogData()
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let catalog = try decoder.decode(Catalog.self, from: data)

        let categoryIDs = catalog.categories.map(\.id)
        #expect(categoryIDs.count == Set(categoryIDs).count, "Duplicate category id found in data/osint-tools.json")
    }
}

private final class BundleToken {}
