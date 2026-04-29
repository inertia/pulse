import SwiftUI

/// Compact card representation used inside the Overview tab.
///
/// Layout (left to right): dot indicator (status / priority signal) → project chip
/// (small monospaced pill) → title (single line, ellipsis on overflow) → optional
/// agent badge (git / pulse / claude / agents / gemini / quick) → relative age.
///
/// Differs from `CardRowView`: that one is per-project (no project chip needed,
/// title can wrap to 2 lines). Overview is cross-project so we trade title space
/// for project attribution.
struct CardChipView: View {
    let card: Card
    let projectLabel: String
    let dotColor: Color
    let agentBadge: String?
    let onTap: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 8) {
                Circle()
                    .fill(dotColor)
                    .frame(width: 6, height: 6)
                Text(projectLabel)
                    .font(.system(.caption2, design: .monospaced).weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(Brand.surface2)
                    )
                Text(card.title)
                    .font(.system(.callout, weight: .medium))
                    .foregroundStyle(card.status == .done ? .secondary : .primary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if let agent = agentBadge {
                    Text(agent)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(
                            Capsule().fill(Color.primary.opacity(0.05))
                        )
                }
                if let age = ageLabel {
                    Text(age)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(hover ? Color.primary.opacity(0.06) : Color.primary.opacity(0.025))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.05), lineWidth: 0.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .help(card.body ?? card.title)
    }

    private var ageLabel: String? {
        let date: Date?
        switch card.status {
        case .todo: date = card.dueDate
        case .done: date = card.completedAt
        }
        guard let date else { return nil }
        return Format.formatRelative(date)
    }
}
