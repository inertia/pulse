import SwiftUI

struct ProjectGroupView: View {
    let group: ProjectGroup
    let onCardTap: (Card) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Text("📄")
                Text(group.label)
                    .font(.system(.subheadline).weight(.medium))
                if isMissing {
                    Text("⚠")
                        .foregroundStyle(.orange)
                    Text("來源遺失")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            ForEach(group.cards) { card in
                CardRowView(card: card, onTap: { onCardTap(card) })
            }
            .opacity(isMissing ? 0.5 : 1.0)
        }
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
