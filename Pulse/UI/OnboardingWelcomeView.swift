import SwiftUI

struct OnboardingWelcomeView: View {
    let onStartScan: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 56))
                .foregroundStyle(.tint)

            Text("歡迎使用 Pulse")
                .font(.title)
                .fontWeight(.semibold)

            Text("跨專案 todo / done 自動 monitor。")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer().frame(height: 8)

            VStack(alignment: .leading, spacing: 6) {
                Text("我會掃以下路徑（含一層子目錄）找含 CLAUDE.md / AGENTS.md / GEMINI.md 的目錄：")
                    .font(.caption)
                ForEach(["~/Desktop", "~/Projects", "~/code", "~/Developer", "~/Documents"], id: \.self) { path in
                    Text(path)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Text("跳過 node_modules / .git / dist / build 等")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 8)

            Spacer()

            Button(action: onStartScan) {
                Text("開始掃描")
                    .frame(minWidth: 140)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(32)
        .frame(width: 520, height: 480)
    }
}
