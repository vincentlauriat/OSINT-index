# Notice — données tierces

Le code de cette application est distribué sous licence MIT (voir [`LICENSE`](LICENSE)).

Le jeu de données initial (`data/osint-tools.json`) a été importé depuis le dépôt public
[`osint4all/osint4all.github.io`](https://github.com/osint4all/osint4all.github.io),
lui-même une republication de la page de curation
[start.me/p/L1rEYQ/osint4all](https://start.me/p/L1rEYQ/osint4all).

- **Licence de la donnée source** : [CC0 1.0 Universal](https://creativecommons.org/publicdomain/zero/1.0/)
  (domaine public — aucune attribution requise, créditée ici par transparence).
- **Import initial** : voir `data/osint-tools.json` → champ `source.importedAt`.
- **Script d'import** : [`Scripts/import_osint4all.py`](Scripts/import_osint4all.py).

À partir de cet import initial, le fichier `data/osint-tools.json` est maintenu manuellement
dans ce dépôt (ajouts, corrections, suppressions de liens morts) et n'est plus resynchronisé
automatiquement depuis la source ci-dessus.
