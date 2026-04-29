import Foundation

extension CardStore {
    enum Priority {
        case urgent
        case high
        case normal
    }

    /// Detect priority from the card's leading emoji marker OR a synthetic tag
    /// derived from its enclosing section heading.
    ///
    /// Two layouts are supported because real-world pulse.md files use both:
    /// * Hook line format: `- [ ] 🔴 (YYYY-MM-DD) {內容}` — emoji lands at
    ///   the start of `Card.title` after date stripping (`hasPrefix` catches it).
    /// * Section heading format: `### 🔴 URGENT / P0` followed by bullets
    ///   without per-line emoji — `MultiStrategyMarkdownParser.normalize`
    ///   injects `priority-urgent` / `priority-high` tags from the heading.
    ///
    /// Inferred at query time so the cache schema (version 1) stays stable.
    static func priority(of card: Card) -> Priority {
        if card.title.hasPrefix("🔴") || card.tags.contains("priority-urgent") {
            return .urgent
        }
        if card.title.hasPrefix("🟡") || card.tags.contains("priority-high") {
            return .high
        }
        return .normal
    }

    // MARK: - Static helpers (operate on any [Card])

    /// Pure filter that takes any `[Card]` so the Overview tab can pass
    /// `cardStore.cards + quickTodoStore.cards()` without going through
    /// the instance API.
    static func filterCards(_ cards: [Card], status: Status, priority: Priority? = nil) -> [Card] {
        cards.filter { c in
            guard c.status == status else { return false }
            if let p = priority { return Self.priority(of: c) == p }
            return true
        }
    }

    /// Done cards completed within the half-open window `(hoursAgoLower, hoursAgoUpper]`,
    /// newest first. Defaults match the previous `doneCardsLast(hours:)` shape:
    /// `cardsCompletedWithin(cards, hoursAgoLower: 24)` returns done within 24h.
    ///
    /// `(lower, upper]` is half-open on the older end so that adjacent windows
    /// (e.g., last 24h vs last 7d-but-not-last-24h) do NOT double-count a card
    /// completed exactly at the boundary. The newer end `upper` is inclusive
    /// so "now" itself is reachable.
    static func cardsCompletedWithin(
        _ cards: [Card],
        hoursAgoLower: Int,
        hoursAgoUpper: Int = 0,
        now: Date = Date()
    ) -> [Card] {
        let upperBound = now.addingTimeInterval(-Double(hoursAgoUpper) * 3600)
        let lowerBound = now.addingTimeInterval(-Double(hoursAgoLower) * 3600)
        return cards
            .filter { c in
                guard c.status == .done, let d = c.completedAt else { return false }
                return d > lowerBound && d <= upperBound
            }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    /// Digest counts derived from any `[Card]`. Used directly by `OverviewView`
    /// (which combines cardStore + quickTodoStore) and by the `digestSummary`
    /// instance wrapper below (which uses `self.cards`).
    static func digest(_ cards: [Card], now: Date = Date()) -> (doneToday: Int, outstanding: Int, projectsWithOutstanding: Int) {
        let calendar = Calendar.current
        let doneToday = cards.filter { c in
            guard c.status == .done, let d = c.completedAt else { return false }
            return calendar.isDate(d, inSameDayAs: now)
        }.count
        let outstandingCards = cards.filter { $0.status == .todo }
        let projectsWithOutstanding = Set(outstandingCards.map { $0.sourceId }).count
        return (doneToday, outstandingCards.count, projectsWithOutstanding)
    }

    // MARK: - Instance convenience wrappers

    /// Filter cards across all sources by status and (optionally) priority.
    /// Backs the Overview tab's URGENT / HIGH outstanding sections.
    func cardsAcrossProjects(status: Status, priority: Priority? = nil) -> [Card] {
        Self.filterCards(cards, status: status, priority: priority)
    }

    /// Cards completed within the last `hours` hours, newest first.
    ///
    /// Inclusive at the older boundary (preserves v0.3 ship-day semantics).
    /// For chained non-overlapping windows (last 24h vs last 7d-but-not-24h)
    /// use the static `cardsCompletedWithin(_:hoursAgoLower:hoursAgoUpper:)`
    /// directly which is half-open and avoids double counting.
    func doneCardsLast(hours: Int, now: Date = Date()) -> [Card] {
        let cutoff = now.addingTimeInterval(-Double(hours) * 3600)
        return cards
            .filter { $0.status == .done && ($0.completedAt ?? .distantPast) >= cutoff }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    /// Cross-project digest counts. Used by `DigestLineView` to compose the
    /// "今天完成 N 件　outstanding M 件　X 個專案有東西未完成" summary line.
    func digestSummary(now: Date = Date()) -> (doneToday: Int, outstanding: Int, projectsWithOutstanding: Int) {
        Self.digest(cards, now: now)
    }
}
