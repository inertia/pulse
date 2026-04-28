import SwiftUI

struct FiltersTab: View {
    @ObservedObject var settings: Pulse.Settings

    var body: some View {
        Form {
            Section("Git commits 過濾") {
                Picker("過濾預設", selection: Binding(
                    get: { settings.gitFilterPreset },
                    set: { settings.gitFilterPreset = $0 }
                )) {
                    Text("Minimal：只收 feat / fix").tag(GitFilterPreset.minimal)
                    Text("Recommended：feat / fix / refactor / perf").tag(GitFilterPreset.recommended)
                    Text("All：全部 conventional commit type").tag(GitFilterPreset.all)
                }
                .pickerStyle(.inline)

                Text("變更後下次 refresh 才會生效。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}
