import SwiftUI

/// Cross-project digest tab. Sits at the leftmost position of `ProjectTabBar`
/// and is selected by default on app launch.
///
/// Composes (top to bottom):
/// 1. `DigestLineView` — one-sentence summary
/// 2. `🔴 URGENT outstanding` — todos detected via `CardStore.priority(of:)`
/// 3. `🟡 HIGH outstanding`   — same; via title prefix or section-heading-derived tag
/// 4. `完成 last 24h`          — done cards (git commit + pulse.md `[x]`) sorted by completedAt desc
/// 5. `完成 last 7d`           — collapsed by default; cards completed 24h..7d ago (no overlap with 24h)
struct OverviewView: View {
    @ObservedObject var cardStore: CardStore
    @ObservedObject var quickTodoStore: QuickTodoStore
    let sourceStore: SourceStore
    let onCardTap: (Card) -> Void

    @State private var showLastWeek = false

    var body: some View {
        // Cache once per render: combined cards (cardStore + quickTodos) and the
        // sources lookup. Without caching, sourceStore.load() reads disk per row,
        // and `allCards` array concat runs once per derived collection. SwiftUI
        // re-renders body on cardStore @Published mutations, so this scope is
        // the right level of memoization.
        let cards = cardStore.cards + quickTodoStore.cards()
        let sources = sourceStore.load()
        let summary = CardStore.digest(cards)

        let urgentCards = CardStore.filterCards(cards, status: .todo, priority: .urgent)
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
        let highCards = CardStore.filterCards(cards, status: .todo, priority: .high)
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
        let last24h = CardStore.cardsCompletedWithin(cards, hoursAgoLower: 24)
        let last7dExcluding24h = CardStore.cardsCompletedWithin(
            cards, hoursAgoLower: 24 * 7, hoursAgoUpper: 24
        )

        let isAllEmpty = urgentCards.isEmpty && highCards.isEmpty
            && last24h.isEmpty && last7dExcluding24h.isEmpty

        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                DigestLineView(summary: summary)

                if !urgentCards.isEmpty {
                    OverviewSection(
                        title: "🔴 URGENT outstanding",
                        accent: Brand.amber,
                        count: urgentCards.count
                    ) {
                        ForEach(urgentCards) { card in
                            row(for: card, dot: Brand.amber, sources: sources)
                        }
                    }
                }

                if !highCards.isEmpty {
                    OverviewSection(
                        title: "🟡 HIGH outstanding",
                        accent: Brand.amberDeep,
                        count: highCards.count
                    ) {
                        ForEach(highCards) { card in
                            row(for: card, dot: Brand.amberDeep, sources: sources)
                        }
                    }
                }

                if !last24h.isEmpty {
                    OverviewSection(
                        title: "完成 last 24h",
                        accent: .secondary,
                        count: last24h.count
                    ) {
                        ForEach(last24h) { card in
                            row(for: card, dot: .green, sources: sources)
                        }
                    }
                }

                if !last7dExcluding24h.isEmpty {
                    OverviewSection(
                        title: "完成 last 7d",
                        accent: .secondary,
                        count: last7dExcluding24h.count,
                        collapsible: true,
                        isExpanded: $showLastWeek
                    ) {
                        ForEach(last7dExcluding24h) { card in
                            row(for: card, dot: .gray, sources: sources)
                        }
                    }
                }

                if isAllEmpty {
                    Text("沒有 outstanding 也沒有最近完成。")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 24)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
    }

    private func row(for card: Card, dot: Color, sources: [Source]) -> CardChipView {
        CardChipView(
            card: card,
            projectLabel: Self.labelFor(sourceId: card.sourceId, sources: sources),
            dotColor: dot,
            agentBadge: Self.agentLabel(for: card.sourceId, sources: sources),
            onTap: { onCardTap(card) }
        )
    }

    // MARK: - Source resolution (static so views can share without re-loading)

    static func labelFor(sourceId: UUID, sources: [Source]) -> String {
        if sourceId == QuickTodoConstants.sourceId { return QuickTodoConstants.label }
        return sources.first(where: { $0.id == sourceId })?.label ?? "Unknown"
    }

    /// Returns "git" / "pulse" / "claude" / "agents" / "gemini" / "quick" or
    /// `nil` if the source is missing (deleted but not yet swept; the chip
    /// simply omits the agent badge in that case).
    static func agentLabel(for sourceId: UUID, sources: [Source]) -> String? {
        if sourceId == QuickTodoConstants.sourceId { return "quick" }
        guard let s = sources.first(where: { $0.id == sourceId }) else { return nil }
        switch s.kind {
        case .gitLog: return "git"
        case .claudeMd:
            return s.path.lastPathComponent == "pulse.md" ? "pulse" : "claude"
        case .agentsMd: return "agents"
        case .geminiMd: return "gemini"
        }
    }
}
