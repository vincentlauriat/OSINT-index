import SwiftUI

struct CategoryListView: View {
    @Environment(AppSettings.self) private var settings
    @Bindable var vm: CatalogViewModel
    @Binding var selection: SidebarSelection?

    var body: some View {
        List(selection: $selection) {
            Label(settings.t("favorites_title"), systemImage: "star.fill")
                .tag(SidebarSelection.favorites)

            Section(settings.t("categories_title")) {
                ForEach(vm.categories) { category in
                    Text(category.name)
                        .tag(SidebarSelection.category(category.id))
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle(settings.t("app_name"))
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    Task { await vm.refresh() }
                } label: {
                    if vm.isLoading {
                        ProgressView().scaleEffect(0.65)
                    } else {
                        Label(settings.t("refresh"), systemImage: "arrow.clockwise")
                    }
                }
                .disabled(vm.isLoading)
                .help(settings.t("refresh_help"))
            }
        }
    }
}
