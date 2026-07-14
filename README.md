# OSINT-index

Un point d'entrée pour faire de l'OSINT (Open Source Intelligence) : des milliers d'outils et
ressources classés par catégorie (recherche de personnes, réseaux sociaux, géolocalisation,
domaines/IP, cryptomonnaies, dark web, registres publics, etc.), sous forme d'index consultable
et recherchable — application **macOS + iOS/iPadOS** en SwiftUI, à codebase partagé.

Le jeu de données vit dans [`data/osint-tools.json`](data/osint-tools.json), versionné dans ce
dépôt et mis à jour au fil du temps. Voir [`NOTICE.md`](NOTICE.md) pour l'origine des données
(import initial CC0 depuis [osint4all](https://github.com/osint4all/osint4all.github.io)).

## Features

| Feature | macOS | iOS/iPadOS |
|---|:---:|:---:|
| Navigation par catégorie (`NavigationSplitView`) | ✅ | ✅ |
| Recherche plein texte (nom + catégorie) | ✅ | ✅ |
| Favoris persistés localement | ✅ | ✅ |
| Rafraîchissement du catalogue depuis GitHub + cache hors-ligne | ✅ | ✅ |
| Mise à jour automatique de l'app (Sparkle) | ✅ | — (App Store, à venir) |

## Build

Prérequis : Xcode 15+, [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```bash
xcodegen generate            # génère OSINTIndex.xcodeproj
open OSINTIndex.xcodeproj    # macOS : scheme OSINTIndex — iOS : scheme OSINTIndexiOS
```

## Mettre à jour le catalogue

```bash
python3 Scripts/import_osint4all.py     # (one-shot) régénère data/osint-tools.json depuis la source CC0
python3 Scripts/check_dead_links.py     # vérifie les liens morts, génère un rapport
```

Au-delà de l'import initial, `data/osint-tools.json` se modifie à la main (ajout/suppression
d'outils, correction de liens) directement dans ce dépôt.

## Release (macOS)

```bash
./Scripts/release.sh 1.0.0   # build → sign → DMG → notarize → staple → appcast Sparkle
```

## Project layout

```
data/
└── osint-tools.json          # catalogue d'outils OSINT (source de vérité)
OSINTIndex/
├── OSINTIndexApp.swift       # @main (+ SPUStandardUpdaterController sur macOS)
├── Models/                   # OsintTool, ToolCategory, Catalog
├── Services/                 # CatalogLoader (fetch+cache+fallback), FavoritesStore
├── ViewModels/                # CatalogViewModel (@Observable)
├── Views/                     # SwiftUI (liste catégories, liste outils, favoris)
├── Localization/               # AppSettings + tables de traduction
└── Assets.xcassets/            # AppIcon
Scripts/
├── import_osint4all.py        # import one-shot du README CC0 osint4all
├── check_dead_links.py        # vérificateur de liens morts (incrémental)
├── release.sh                 # build → sign → DMG → notarize → staple → appcast
├── make-app-icon.swift
└── make-dmg-background.swift
project.yml                    # config XcodeGen
```

## Roadmap

- [x] Bootstrap du projet (squelette SwiftUI macOS + iOS)
- [x] Import initial du catalogue depuis osint4all (CC0)
- [x] Couche data (fetch GitHub raw + cache + fallback bundle)
- [x] UI macOS (liste, recherche, favoris)
- [x] Packaging Sparkle (clé EdDSA dédiée, `release.sh` étendu) — première release réelle en
      attente de la publication du repo GitHub
- [x] Build iOS vérifié (socle uniquement)
- [x] Vérificateur de liens morts
- [ ] Publier le repo GitHub et couper la release `0.1.0`
- [ ] Décision : soumission App Store iOS ou distribution alternative

## Licence

Code : MIT — voir [`LICENSE`](LICENSE).
Données : voir [`NOTICE.md`](NOTICE.md) (import initial CC0).
