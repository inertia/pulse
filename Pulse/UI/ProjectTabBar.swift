import SwiftUI

/// Horizontal scrolling pill bar above the popover content. The leftmost pill
/// is the Overview pseudo-tab (sentinel label "Overview", grid icon + total
/// outstanding count); the rest are real ProjectGroups. Tap to switch.
struct ProjectTabBar: View {
    static let overviewLabel = "Overview"

    let groups: [ProjectGroup]
    @Binding var selectedLabel: String?
    let overviewBadgeCount: Int

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                overviewPill
                ForEach(groups) { group in
                    pill(for: group)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    @ViewBuilder
    private var overviewPill: some View {
        let isActive = selectedLabel == Self.overviewLabel
        Button(action: { selectedLabel = Self.overviewLabel }) {
            HStack(spacing: 4) {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 9, weight: .medium))
                Text(L.overviewLabel)
                    .font(.system(.caption, weight: isActive ? .semibold : .medium))
                Text("\(overviewBadgeCount)")
                    .font(.caption2)
                    .monospacedDigit()
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(
                        Capsule().fill(
                            isActive ? Color.white.opacity(0.25) : Color.primary.opacity(0.08)
                        )
                    )
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(
                    isActive ? Color.accentColor : Color.primary.opacity(0.04)
                )
            )
            .foregroundStyle(isActive ? Color.white : Color.primary)
            .overlay(
                Capsule().strokeBorder(
                    isActive ? Color.clear : Color.primary.opacity(0.08),
                    lineWidth: 0.5
                )
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func pill(for group: ProjectGroup) -> some View {
        let isActive = selectedLabel == group.label
        let todoCount = group.cards.filter { $0.status == .todo }.count
        Button(action: { selectedLabel = group.label }) {
            HStack(spacing: 4) {
                Text(group.label)
                    .font(.system(.caption, weight: isActive ? .semibold : .medium))
                Text("\(todoCount)")
                    .font(.caption2)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(
                        Capsule().fill(
                            isActive ? Color.white.opacity(0.25) : Color.primary.opacity(0.08)
                        )
                    )
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(
                    isActive ? Color.accentColor : Color.primary.opacity(0.04)
                )
            )
            .foregroundStyle(isActive ? Color.white : Color.primary)
            .overlay(
                Capsule().strokeBorder(
                    isActive ? Color.clear : Color.primary.opacity(0.08),
                    lineWidth: 0.5
                )
            )
        }
        .buttonStyle(.plain)
    }
}
