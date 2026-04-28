import SwiftUI

struct ProjectGroupView: View {
    let group: ProjectGroup
    let onCardTap: (Card) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(group.label)
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Text("\(group.cards.count)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Color.primary.opacity(0.06)))
                if isMissing {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                    Text("來源遺失")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 6)

            VStack(spacing: 6) {
                ForEach(group.cards) { card in
                    CardRowView(card: card, onTap: { onCardTap(card) })
                }
            }
            .padding(.horizontal, 12)
            .opacity(isMissing ? 0.5 : 1.0)
        }
        .padding(.bottom, 8)
    }

    /// Group is "missing" if any of its enabled markdown sources point to non-existent paths,
    /// or any enabled gitLog source points to a non-git directory.
    var isMissing: Bool {
        let fm = FileManager.default
        for source in group.sources where source.enabled {
            switch source.kind {
            case .claudeMd, .agentsMd, .geminiMd:
                if !fm.fileExists(atPath: source.path.path) { return true }
            case .gitLog:
                let gitDir = source.path.appendingPathComponent(".git")
                if !fm.fileExists(atPath: gitDir.path) { return true }
            }
        }
        return false
    }
}
