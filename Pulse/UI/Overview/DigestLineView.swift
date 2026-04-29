import SwiftUI

/// One-line summary at the top of the Overview tab.
/// Formats `(doneToday, outstanding, projectsWithOutstanding)` into:
/// 「今天完成 N　outstanding M　X 個專案待處理」.
/// Outstanding count is amber-tinted to draw the eye to remaining work.
struct DigestLineView: View {
    let summary: (doneToday: Int, outstanding: Int, projectsWithOutstanding: Int)

    var body: some View {
        HStack(spacing: 0) {
            Text(L.digestDoneTodayPrefix)
                .foregroundStyle(.secondary)
            Text("\(summary.doneToday)")
                .foregroundStyle(.primary)
                .fontWeight(.semibold)
                .monospacedDigit()
            Text(L.digestOutstandingMid)
                .foregroundStyle(.secondary)
            Text("\(summary.outstanding)")
                .foregroundStyle(Brand.amber)
                .fontWeight(.semibold)
                .monospacedDigit()
            Text(L.digestProjectsSeparator)
                .foregroundStyle(.secondary)
            Text("\(summary.projectsWithOutstanding)")
                .foregroundStyle(.primary)
                .fontWeight(.semibold)
                .monospacedDigit()
            Text(L.digestProjectsSuffix)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .font(.system(.caption, weight: .regular))
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Brand.surface2.opacity(0.5))
        )
    }
}
