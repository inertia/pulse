import SwiftUI

struct AboutTab: View {
    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "x.y.z"
    }

    private var buildKind: String {
        #if INTERNAL_BUILD
        return "Internal build"
        #else
        return "Public build"
        #endif
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 48))
                .foregroundStyle(.tint)

            Text("Pulse")
                .font(.title)
                .fontWeight(.semibold)

            VStack(spacing: 4) {
                Text("v\(version)")
                    .font(.body)
                Text(buildKind)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider().padding(.horizontal, 60)

            VStack(spacing: 8) {
                Text(L.settingsAboutTagline)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Link("github.com/inertia/pulse",
                     destination: URL(string: "https://github.com/inertia/pulse")!)
                    .font(.caption)

                Text(L.settingsLicense)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("© 2026 Huang Sun-Quan")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
