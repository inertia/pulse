import SwiftUI

struct PopoverFooterView: View {
    let stats: PopoverStats
    let lastRefreshAt: Date?
    let isLoading: Bool

    var body: some View {
        HStack {
            if isLoading {
                Text("掃描中…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("\(stats.projects) 專案 · \(stats.todos) 待辦 · \(stats.dones) 完成 · \(timeAgoText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var timeAgoText: String {
        guard let last = lastRefreshAt else { return "尚未更新" }
        let elapsed = Date().timeIntervalSince(last)
        if elapsed < 60 { return "剛剛更新" }
        if elapsed < 3600 { return "\(Int(elapsed / 60)) 分鐘前更新" }
        return "\(Int(elapsed / 3600)) 小時前更新"
    }
}
