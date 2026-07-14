import SwiftUI
#if os(macOS)
import Sparkle
#endif

@main
struct OSINTIndexApp: App {
    @State private var settings = AppSettings()

    #if os(macOS)
    // Prompt-based only: Sparkle may check for updates in the background, but
    // never downloads/installs without the user explicitly confirming via
    // "Check for Updates…" or the update prompt.
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(settings)
                .preferredColorScheme(settings.appearance.colorScheme)
        }
        #if os(macOS)
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 960, height: 640)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .appInfo) {
                Button(settings.t("check_for_updates")) {
                    updaterController.checkForUpdates(nil)
                }
            }
        }
        #endif

        // Réglages via la scène native macOS (⌘,). Sur iOS, les réglages sont
        // présentés en feuille depuis `ContentView` (pas de scène `Settings`).
        #if os(macOS)
        Settings {
            SettingsView()
                .environment(settings)
        }
        #endif
    }
}
