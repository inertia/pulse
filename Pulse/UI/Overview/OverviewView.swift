import SwiftUI

/// Cross-project digest tab. Sits at the leftmost position of `ProjectTabBar`
/// and is selected by default on app launch.
///
/// Composes (top to bottom):
/// 1. `DigestLineView` — one-sentence summary
/// 2. `🔴 URGENT outstanding` — todos with title prefix 🔴, across all projects
/// 3. `🟡 HIGH outstanding`   — todos with title prefix 🟡
/// 4. `完成 last 24h`          — done cards (git commit + pulse.md `[x]`) sorted by completedAt desc
/// 5. `完成 last 7d`           — collapsed by default; older done cards within the last week
struct OverviewView: View {
    @ObservedObject var cardStore: CardStore
    @ObservedObject var quickTodoStore: QuickTodoStore
    let sourceStore: SourceStore
    let onCardTap: (Card) -> Void

    @State private var showLastWeek = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                DigestLineView(summary: digestSummary)

                if !urgentCards.isEmpty {
                    OverviewSection(
                        title: "🔴 URGENT outstanding",
                        accent: Brand.amber,
                        count: urgentCards.count
                    ) {
                        ForEach(urgentCards) { card in
                            row(for: card, dot: Brand.amber)
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
                            row(for: card, dot: Brand.amberDeep)
                        }
                    }
                }

                let recent = doneIn(hoursMin: 0, hoursMax: 24)
                if !recent.isEmpty {
                    OverviewSection(
                        title: "完成 last 24h",
                        accent: .secondary,
                        count: recent.count
                    ) {
                        ForEach(recent) { card in
                            row(for: card, dot: .green)
                        }
                    }
                }

                let week = doneIn(hoursMin: 24, hoursMax: 24 * 7)
                if !week.isEmpty {
                    OverviewSection(
                        title: "完成 last 7d",
                        accent: .secondary,
                        count: week.count,
                        collapsible: true,
                        isExpanded: $showLastWeek
                    ) {
                        ForEach(week) { card in
                            row(for: card, dot: .gray)
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

    @ViewBuilder
    private func row(for card: Card, dot: Color) -> some View {
        CardChipView(
            card: card,
            projectLabel: labelFor(sourceId: card.sourceId),
            dotColor: dot,
            agentBadge: agentLabel(for: card.sourceId),
            onTap: { onCardTap(card) }
        )
    }

    // MARK: - Combined cards (cardStore + quickTodoStore virtual project)

    private var allCards: [Card] {
        cardStore.cards + quickTodoStore.cards()
    }

    // MARK: - Aggregates

    private var digestSummary: (doneToday: Int, outstanding: Int, projectsWithOutstanding: Int) {
        let calendar = Calendar.current
        let now = Date()
        let cards = allCards
        let doneToday = cards.filter { c in
            guard c.status == .done, let d = c.completedAt else { return false }
            return calendar.isDate(d, inSameDayAs: now)
        }.count
        let outstanding = cards.filter { $0.status == .todo }
        let projects = Set(outstanding.map { $0.sourceId }).count
        return (doneToday, outstanding.count, projects)
    }

    private var urgentCards: [Card] {
        allCards
            .filter { $0.status == .todo && CardStore.priority(of: $0) == .urgent }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }

    private var highCards: [Card] {
        allCards
            .filter { $0.status == .todo && CardStore.priority(of: $0) == .high }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }

    /// Done cards completed between `hoursMin` (exclusive of newer than upper) and
    /// `hoursMax` (inclusive of older bound) hours ago. Sorted newest-first.
    private func doneIn(hoursMin: Int, hoursMax: Int) -> [Card] {
        let now = Date()
        let upper = now.addingTimeInterval(-Double(hoursMin) * 3600)
        let lower = now.addingTimeInterval(-Double(hoursMax) * 3600)
        return allCards
            .filter { c in
                guard c.status == .done, let d = c.completedAt else { return false }
                return d <= upper && d >= lower
            }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    private var isAllEmpty: Bool {
        urgentCards.isEmpty && highCards.isEmpty
            && doneIn(hoursMin: 0, hoursMax: 24).isEmpty
            && doneIn(hoursMin: 24, hoursMax: 24 * 7).isEmpty
    }

    // MARK: - Source resolution

    private func labelFor(sourceId: UUID) -> String {
        if sourceId == QuickTodoConstants.sourceId { return QuickTodoConstants.label }
        let sources = sourceStore.load()
        return sources.first(where: { $0.id == sourceId })?.label ?? "Unknown"
    }

    private func agentLabel(for sourceId: UUID) -> String? {
        if sourceId == QuickTodoConstants.sourceId { return "quick" }
        let sources = sourceStore.load()
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
