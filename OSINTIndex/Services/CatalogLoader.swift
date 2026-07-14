import Foundation

enum CatalogSource {
    case network, cache, bundle
}

struct CatalogLoadResult {
    let catalog: Catalog
    let source: CatalogSource
}

/// Resolves the OSINT catalog in order: network fetch (GitHub raw) → disk cache →
/// bundled fallback. Refresh only happens on demand (app launch / manual refresh),
/// never via background polling.
final class CatalogLoader {
    private let remoteURL: URL
    private let cacheURL: URL
    private let bundleURL: URL?
    private let session: URLSession

    init(
        remoteURL: URL = URL(string: "https://raw.githubusercontent.com/vincentlauriat/OSINT-index/main/data/osint-tools.json")!,
        session: URLSession = .shared
    ) {
        self.remoteURL = remoteURL
        self.session = session

        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("OSINT-index", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.cacheURL = dir.appendingPathComponent("catalog-cache.json")
        self.bundleURL = Bundle.main.url(forResource: "osint-tools", withExtension: "json")
    }

    func load() async -> CatalogLoadResult? {
        if let result = await fetchFromNetwork() {
            return result
        }
        if let catalog = try? loadCatalog(from: cacheURL) {
            return CatalogLoadResult(catalog: catalog, source: .cache)
        }
        if let bundleURL, let catalog = try? loadCatalog(from: bundleURL) {
            return CatalogLoadResult(catalog: catalog, source: .bundle)
        }
        return nil
    }

    private func fetchFromNetwork() async -> CatalogLoadResult? {
        var request = URLRequest(url: remoteURL)
        request.timeoutInterval = 10
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            let catalog = try decode(data)
            try? data.write(to: cacheURL, options: .atomic)
            return CatalogLoadResult(catalog: catalog, source: .network)
        } catch {
            return nil
        }
    }

    private func loadCatalog(from url: URL) throws -> Catalog {
        try decode(Data(contentsOf: url))
    }

    private func decode(_ data: Data) throws -> Catalog {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Catalog.self, from: data)
    }
}
