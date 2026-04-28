import SwiftUI

struct SettingsView: View {
    @StateObject private var filtersSettings = Pulse.Settings()

    var body: some View {
        TabView {
            SourcesTab()
                .tabItem { Label("Sources", systemImage: "list.bullet") }
            FiltersTab(settings: filtersSettings)
                .tabItem { Label("Filters", systemImage: "line.horizontal.3.decrease") }
            AboutTab()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 600, height: 460)
    }
}
