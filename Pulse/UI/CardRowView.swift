import SwiftUI

struct CardRowView: View {
    let card: Card
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: card.status == .todo ? "circle" : "checkmark.circle.fill")
                    .foregroundStyle(card.status == .todo ? .primary : .secondary)
                    .font(.caption)
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(card.title)
                        .font(.system(.body))
                        .foregroundStyle(card.status == .done ? .secondary : .primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    if let dateText = dateLabel {
                        Text(dateText)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer()
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(card.body ?? card.title)   // hover tooltip
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
