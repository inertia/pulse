import SwiftUI

struct PopoverFooterView: View {
    let stats: PopoverStats
    let lastRefreshAt: Date?
    let isLoading: Bool

    var body: some View {
        HStack {
            if isLoading {
                Text(L.footerScanning)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text(L.footerStats(projects: stats.projects, todos: stats.todos,
                                   dones: stats.dones, timeAgo: timeAgoText))
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
        guard let last = lastRefreshAt else { return L.footerNeverRefreshed }
        let elapsed = Date().timeIntervalSince(last)
        if elapsed < 60 { return L.footerJustRefreshed }
        if elapsed < 3600 { return L.footerMinAgo(Int(elapsed / 60)) }
        return L.footerHourAgo(Int(elapsed / 3600))
    }
}
