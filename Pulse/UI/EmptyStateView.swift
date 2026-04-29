import SwiftUI

struct EmptyStateView: View {
    let onSettingsTap: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text(L.emptyNoSources)
                .font(.headline)
            Text(L.emptyNoSourcesHint)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Button(L.emptyOpenSettings) { onSettingsTap() }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
