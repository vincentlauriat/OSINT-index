import Foundation

/// Table de traductions bilingue (fr / en). Clé → chaîne. `en` sert de repli.
/// Ajoute des langues en ajoutant une entrée de premier niveau (ex. "zh") et le
/// cas correspondant dans `AppLanguage` / `AppSettings.localeIdentifier`.
enum Strings {
    static let table: [String: [String: String]] = [
        "fr": [
            "app_name": "OSINT-index",

            // Sidebar
            "favorites_title": "Favoris",
            "categories_title": "Catégories",
            "search_placeholder": "Rechercher un outil ou une catégorie…",
            "search_results_title": "Résultats",
            "refresh": "Rafraîchir",
            "refresh_help": "Recharger le catalogue",

            // Liste d'outils
            "no_tools_title": "Aucun outil",
            "no_tools_desc": "Cette catégorie est vide, ou aucun favori n'est encore enregistré.",

            // Sélection vide
            "empty_title": "Sélectionne une catégorie",
            "empty_desc": "Choisis une catégorie dans la barre latérale pour voir ses outils.",

            // Erreurs
            "catalog_load_error": "Impossible de charger le catalogue (réseau, cache et copie embarquée indisponibles).",

            // Réglages
            "settings_title": "Réglages",
            "settings_appearance": "Apparence",
            "appearance_system": "Système",
            "appearance_light": "Clair",
            "appearance_dark": "Sombre",
            "settings_language": "Langue",
            "language_system": "Système",
            "settings_about": "À propos",
            "settings_about_text": "Un point d'entrée pour faire de l'OSINT — données importées depuis osint4all (CC0).",

            // Menu (macOS)
            "check_for_updates": "Rechercher les mises à jour…",

            // Divers
            "ok": "OK",
            "error_title": "Erreur",
        ],
        "en": [
            "app_name": "OSINT-index",

            "favorites_title": "Favorites",
            "categories_title": "Categories",
            "search_placeholder": "Search a tool or category…",
            "search_results_title": "Results",
            "refresh": "Refresh",
            "refresh_help": "Reload the catalog",

            "no_tools_title": "No tools",
            "no_tools_desc": "This category is empty, or no favorites are saved yet.",

            "empty_title": "Select a category",
            "empty_desc": "Pick a category from the sidebar to see its tools.",

            "catalog_load_error": "Couldn't load the catalog (network, cache, and bundled copy all unavailable).",

            "settings_title": "Settings",
            "settings_appearance": "Appearance",
            "appearance_system": "System",
            "appearance_light": "Light",
            "appearance_dark": "Dark",
            "settings_language": "Language",
            "language_system": "System",
            "settings_about": "About",
            "settings_about_text": "An entry point for OSINT — data imported from osint4all (CC0).",

            "check_for_updates": "Check for Updates…",

            "ok": "OK",
            "error_title": "Error",
        ],
    ]
}
