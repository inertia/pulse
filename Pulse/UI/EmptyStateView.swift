import SwiftUI

struct EmptyStateView: View {
    let onSettingsTap: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("尚未設定任何 source")
                .font(.headline)
            Text("打開設定加入 CLAUDE.md / AGENTS.md / GEMINI.md 或 git 倉庫路徑。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Button("打開設定") { onSettingsTap() }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
