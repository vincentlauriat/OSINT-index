# Architecture

SwiftUI application with a **single shared codebase** across two targets (macOS + iOS/iPadOS).
Platform differences are handled via `#if os(macOS)` / `#if os(iOS)` blocks, never by
duplicating files.

## Overview

```
                    ┌─────────────────────────┐
                    │      OSINTIndexApp      │  @main — Scene(s)
                    │  (WindowGroup + Settings)│
                    └────────────┬────────────┘
                                 │ .environment(AppSettings)
                    ┌────────────▼────────────┐
                    │      CategoryListView   │  NavigationSplitView
                    │  sidebar categories ┆ tool detail │
                    └─────┬──────┴──────┬──────┘
                          │             │
              ┌───────────▼──┐   ┌──────▼────────────┐
              │ToolListView  │   │   ToolRowView      │
              │(per category)│   │ (Link/openURL)     │
              └───────┬──────┘   └───────────────────┘
                      │ @Bindable
              ┌───────▼──────────┐
              │CatalogViewModel  │  @Observable @MainActor
              │categories/search/│
              │favorites         │
              └───────┬──────────┘
                      │
        ┌─────────────┼─────────────────┐
        │                               │
┌───────▼────────┐            ┌─────────▼────────┐
│ CatalogLoader   │            │  FavoritesStore   │
│ fetch GitHub raw│            │  UserDefaults     │
│ → disk cache     │            │  Set<String> ids  │
│ → bundled fallback│           └───────────────────┘
└───────┬─────────┘
        │
┌───────▼──────────────┐
│ Catalog / ToolCategory│  Codable, decoded from data/osint-tools.json
│ / OsintTool (Models)  │
└───────────────────────┘
```

## Layers

| Layer | Role | Files |
|---|---|---|
| **App** | Entry points, scenes, `AppSettings` injection | `OSINTIndexApp.swift` |
| **Views** | Pure SwiftUI, no networking logic | `Views/*.swift` |
| **ViewModels** | `@MainActor` observable state, load/search/favorites orchestration | `ViewModels/CatalogViewModel.swift` |
| **Services** | Reusable system/network access | `Services/CatalogLoader.swift`, `Services/FavoritesStore.swift`, `Services/Keychain.swift` |
| **Models** | `Codable` structures for the catalog | `Models/OsintTool.swift`, `Models/ToolCategory.swift`, `Models/Catalog.swift` |
| **Data** | Catalog source of truth, versioned in the repo | `data/osint-tools.json` |
| **Localization** | Persisted settings + translation | `Localization/*.swift` |

## The catalog: source, cache, fallback

`data/osint-tools.json` plays three roles with a single physical file:
1. **Versioned data** in the Git repo (public, `raw.githubusercontent.com`).
2. **Source** for the import script (`Scripts/import_osint4all.py`) that generated it initially.
3. **Bundled fallback** in the app (referenced as a resource on both targets in `project.yml`)
   for the first offline launch.

At runtime, `CatalogLoader` resolves in this order:
1. Network fetch (`https://raw.githubusercontent.com/vincentlauriat/OSINT-index/main/data/osint-tools.json`,
   ~10s timeout) → on success: writes the disk cache
   (`Application Support/OSINT-index/catalog-cache.json`) and serves this content.
2. Network failure: serves the disk cache if it exists.
3. Neither network nor cache (first offline launch): serves the bundled copy shipped with the app.

Refresh on launch + manual refresh (pull-to-refresh / button) — no background polling, since the
catalog only changes at the pace of commits to `data/osint-tools.json`.

## Stable identifiers and favorites

- `categories[].id`: deterministic slug of the category name.
- `tools[].id`: composite slug `category-slug + "-" + slug(tool-name)`, disambiguated with a
  numeric suffix on collision. **The URL is not the key** (URLs drift over time) — this `id` is
  what backs favorites persistence (`FavoritesStore`, a `Set<String>` of ids in `UserDefaults`).
- **Stability contract**: renaming or re-categorizing a tool in a future manual edit changes its
  `id` and silently drops the favorite for users who had starred it — an accepted trade-off given
  the volume (~1450 tools); no ID migration system is planned.

## Key decisions

- **Observation** (`@Observable`, Swift 5.9) rather than `ObservableObject`. ViewModels are
  `@MainActor`.
- **Favorites**: `UserDefaults`, not SwiftData — the volume and need (read-only catalog, a few
  dozen favorites) are too simple to justify a local database.
- **Opening links**: native SwiftUI `Link(destination:)`/`openURL`, works without any
  platform-specific code (system browser on macOS, Safari/default app on iOS).
- **Build**: Xcode project **generated** by XcodeGen (`project.yml`) — the `.xcodeproj` is not
  versioned. Regenerate with `xcodegen generate`.
- **macOS signing/notarization**: handled in `release.sh` (Developer ID + Hardened Runtime +
  timestamp retry), shared keychain notarization profile `AppliMacVincentGithub` (tied to the
  Apple Developer account, not per-project).
- **macOS auto-update**: Sparkle, with an EdDSA key dedicated to this project (never reused from
  another one), appcast generated and published on GitHub Releases.
- **iOS**: cross-platform foundation built from day one (same `Models`/`Services`/`ViewModels` as
  macOS), but no release/App Store submission in the initial phases — the dataset contains
  sensitive categories (data breach lookups, sex-offender registries, an extremism section) that
  are likely to be flagged in App Review; that decision is deferred.

## Data license vs. code license

The code (this repo) is MIT-licensed. The content of `data/osint-tools.json` was imported from a
**CC0-1.0** (public domain) source — see [`NOTICE.md`](NOTICE.md). The two licenses are
independent: changing the code doesn't affect the data's status, and vice versa.
