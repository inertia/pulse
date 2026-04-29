import SwiftUI

struct FiltersTab: View {
    @ObservedObject var settings: Pulse.Settings

    var body: some View {
        Form {
            Section(L.settingsGitFilterSection) {
                Picker(L.settingsGitFilterPicker, selection: Binding(
                    get: { settings.gitFilterPreset },
                    set: { settings.gitFilterPreset = $0 }
                )) {
                    Text(L.settingsGitFilterMinimal).tag(GitFilterPreset.minimal)
                    Text("Recommended: feat / fix / refactor / perf").tag(GitFilterPreset.recommended)
                    Text(L.settingsGitFilterAll).tag(GitFilterPreset.all)
                }
                .pickerStyle(.inline)

                Text(L.settingsGitFilterFootnote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}
