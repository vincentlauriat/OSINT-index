import SwiftUI

struct ContentView: View {
    @Environment(AppSettings.self) private var settings
    @State private var vm = CatalogViewModel()
    @State private var selection: SidebarSelection? = .favorites
    #if os(iOS)
    @State private var showingSettings = false
    #endif

    var body: some View {
        NavigationSplitView {
            CategoryListView(vm: vm, selection: $selection)
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 360)
                #if os(iOS)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                        }
                    }
                }
                #endif
        } detail: {
            detailContent
        }
        .searchable(text: $vm.searchText, placement: .sidebar, prompt: settings.t("search_placeholder"))
        .task { await vm.load() }
        .alert(settings.t("error_title"), isPresented: Binding(
            get: { vm.errorMessageKey != nil },
            set: { if !$0 { vm.errorMessageKey = nil } }
        )) {
            Button(settings.t("ok")) { vm.errorMessageKey = nil }
        } message: {
            Text(vm.errorMessageKey.map(settings.t) ?? "")
        }
        #if os(iOS)
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                SettingsView()
                    .environment(settings)
                    .navigationTitle(settings.t("settings_title"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(settings.t("ok")) { showingSettings = false }
                        }
                    }
            }
        }
        #endif
    }

    @ViewBuilder
    private var detailContent: some View {
        if vm.isSearching {
            ToolListView(vm: vm, title: settings.t("search_results_title"), tools: vm.searchResults)
        } else {
            switch selection {
            case .favorites:
                ToolListView(vm: vm, title: settings.t("favorites_title"), tools: vm.favoriteTools)
            case .category(let id):
                if let category = vm.categories.first(where: { $0.id == id }) {
                    ToolListView(vm: vm, title: category.name, tools: category.tools)
                } else {
                    EmptySelectionView()
                }
            case .none:
                EmptySelectionView()
            }
        }
    }
}
