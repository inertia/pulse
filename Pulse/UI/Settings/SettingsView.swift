import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            SourcesTab()
                .tabItem { Label("Sources", systemImage: "list.bullet") }
            Text("FiltersTab placeholder (Task 29)")
                .tabItem { Label("Filters", systemImage: "line.horizontal.3.decrease") }
            Text("AboutTab placeholder (Task 30)")
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 600, height: 460)
    }
}
