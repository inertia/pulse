import SwiftUI

struct CardRowView: View {
    let card: Card
    let onTap: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: card.status == .todo ? "circle" : "checkmark.circle.fill")
                    .foregroundStyle(card.status == .todo ? Color.accentColor : .secondary)
                    .font(.system(size: 14, weight: .regular))
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(card.title)
                        .font(.system(.callout, weight: .medium))
                        .foregroundStyle(card.status == .done ? .secondary : .primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    if let dateText = dateLabel {
                        Text(dateText)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(hover ? Color.primary.opacity(0.06) : Color.primary.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .help(card.body ?? card.title)
    }

    private var dateLabel: String? {
        let date: Date?
        switch card.status {
        case .todo: date = card.dueDate
        case .done: date = card.completedAt
        }
        guard let date else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "M-d"
        return formatter.string(from: date)
    }
}
