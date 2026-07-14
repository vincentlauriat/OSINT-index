# Architecture

Application SwiftUI **à codebase unique partagé** entre deux cibles (macOS + iOS/iPadOS). Les
différences de plateforme sont gérées par des blocs `#if os(macOS)` / `#if os(iOS)`, jamais par
duplication de fichiers.

## Vue d'ensemble

```
                    ┌─────────────────────────┐
                    │      OSINTIndexApp      │  @main — Scene(s)
                    │  (WindowGroup + Settings)│
                    └────────────┬────────────┘
                                 │ .environment(AppSettings)
                    ┌────────────▼────────────┐
                    │      CategoryListView   │  NavigationSplitView
                    │  sidebar catégories ┆ détail outils │
                    └─────┬──────┴──────┬──────┘
                          │             │
              ┌───────────▼──┐   ┌──────▼────────────┐
              │ToolListView  │   │   ToolRowView      │
              │(par catégorie)│  │ (Link/openURL)     │
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
│ → cache disque   │            │  Set<String> ids  │
│ → fallback bundle│            └───────────────────┘
└───────┬─────────┘
        │
┌───────▼──────────────┐
│ Catalog / ToolCategory│  Codable, décodés depuis data/osint-tools.json
│ / OsintTool (Models)  │
└───────────────────────┘
```

## Couches

| Couche | Rôle | Fichiers |
|---|---|---|
| **App** | Points d'entrée, scènes, injection de `AppSettings` | `OSINTIndexApp.swift` |
| **Views** | SwiftUI pur, aucune logique réseau | `Views/*.swift` |
| **ViewModels** | État observable `@MainActor`, orchestration chargement/recherche/favoris | `ViewModels/CatalogViewModel.swift` |
| **Services** | Accès système/réseau réutilisable | `Services/CatalogLoader.swift`, `Services/FavoritesStore.swift`, `Services/Keychain.swift` |
| **Models** | Structures `Codable` du catalogue | `Models/OsintTool.swift`, `Models/ToolCategory.swift`, `Models/Catalog.swift` |
| **Data** | Catalogue source de vérité, versionné dans le repo | `data/osint-tools.json` |
| **Localization** | Réglages persistés + traduction | `Localization/*.swift` |

## Le catalogue : source, cache, fallback

Le fichier `data/osint-tools.json` joue trois rôles avec un seul contenu physique :
1. **Donnée versionnée** dans le repo Git (public, `raw.githubusercontent.com`).
2. **Source** du script d'import (`Scripts/import_osint4all.py`) qui l'a généré initialement.
3. **Fallback bundlé** dans l'app (référencé comme ressource des deux targets dans `project.yml`)
   pour le premier lancement hors-ligne.

Au runtime, `CatalogLoader` résout dans cet ordre :
1. Fetch réseau (`https://raw.githubusercontent.com/vincentlauriat/OSINT-index/main/data/osint-tools.json`,
   timeout ~10 s) → succès : écrit le cache disque (`Application Support/OSINT-index/catalog-cache.json`)
   et sert ce contenu.
2. Échec réseau : sert le cache disque s'il existe.
3. Ni réseau ni cache (premier lancement hors-ligne) : sert la copie bundlée dans l'app.

Refresh au lancement + rafraîchissement manuel (pull-to-refresh / bouton) — pas de polling en
tâche de fond, le catalogue ne change qu'au rythme des commits sur `data/osint-tools.json`.

## Identifiants stables et favoris

- `categories[].id` : slug déterministe du nom de catégorie.
- `tools[].id` : slug composite `catégorie-slug + "-" + slug(nom-outil)`, désambiguïsé par
  suffixe numérique en cas de collision. **L'URL n'est pas la clé** (elle change dans le temps) —
  c'est cet `id` qui sert de clé de persistance des favoris (`FavoritesStore`, `Set<String>`
  d'ids en `UserDefaults`).
- **Contrat de stabilité** : renommer ou recatégoriser un outil dans une édition manuelle future
  change son `id` et perd silencieusement le favori des utilisateurs qui l'avaient marqué —
  compromis accepté vu le volume (~3000 outils), pas de système de migration d'ID.

## Décisions clés

- **Observation** (`@Observable`, Swift 5.9) plutôt que `ObservableObject`. ViewModels `@MainActor`.
- **Favoris** : `UserDefaults`, pas SwiftData — volume et besoin (lecture seule, quelques dizaines
  de favoris) trop simples pour justifier une base locale.
- **Ouverture des liens** : `Link(destination:)`/`openURL` SwiftUI natif, fonctionne sans code
  spécifique par plateforme (navigateur système sur macOS, Safari/app par défaut sur iOS).
- **Build** : projet Xcode **généré** par XcodeGen (`project.yml`) — le `.xcodeproj` n'est pas
  versionné. Régénérer avec `xcodegen generate`.
- **Signature/notarisation macOS** : gérées dans `release.sh` (Developer ID + Hardened Runtime +
  retry timestamp), profil de notarisation trousseau partagé `AppliMacVincentGithub` (au niveau
  du compte Apple Developer, pas par projet).
- **Auto-update macOS** : Sparkle, clé EdDSA dédiée à ce projet (jamais réutilisée d'un autre),
  appcast généré et publié dans les Releases GitHub.
- **iOS** : socle multiplateforme construit dès le début (même `Models`/`Services`/`ViewModels`
  que macOS), mais pas de release/soumission App Store dans les phases initiales — le dataset
  contient des catégories sensibles (fuites de données, registres d'agresseurs sexuels, section
  extrémisme) susceptibles de poser problème en App Review ; décision reportée.

## Licence des données vs licence du code

Le code (ce dépôt) est sous licence MIT. Le contenu de `data/osint-tools.json` a été importé
depuis une source **CC0-1.0** (domaine public) — voir [`NOTICE.md`](NOTICE.md). Les deux licences
sont indépendantes : modifier le code ne change rien au statut de la donnée, et vice-versa.
