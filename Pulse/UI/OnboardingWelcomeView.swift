import SwiftUI

struct OnboardingWelcomeView: View {
    let onStartScan: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 56))
                .foregroundStyle(.tint)

            Text(L.onboardingWelcome)
                .font(.title)
                .fontWeight(.semibold)

            Text(L.onboardingTagline)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer().frame(height: 8)

            VStack(alignment: .leading, spacing: 6) {
                Text(L.onboardingScanIntro)
                    .font(.caption)
                ForEach(["~/Desktop", "~/Projects", "~/code", "~/Developer", "~/Documents"], id: \.self) { path in
                    Text(path)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Text(L.onboardingScanSkips)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 8)

            Spacer()

            Button(action: onStartScan) {
                Text(L.onboardingStartButton)
                    .frame(minWidth: 140)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(32)
        .frame(width: 520, height: 480)
    }
}
