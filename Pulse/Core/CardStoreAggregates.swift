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

    /// Filter cards across all sources by status and (optionally) priority.
    /// Backs the Overview tab's URGENT / HIGH outstanding sections.
    func cardsAcrossProjects(status: Status, priority: Priority? = nil) -> [Card] {
        cards.filter { c in
            guard c.status == status else { return false }
            if let p = priority { return Self.priority(of: c) == p }
            return true
        }
    }

    /// Cards completed within the last `hours` hours, newest first.
    /// Cards lacking `completedAt` are skipped (treated as not-recently-done).
    func doneCardsLast(hours: Int, now: Date = Date()) -> [Card] {
        let cutoff = now.addingTimeInterval(-Double(hours) * 3600)
        return cards
            .filter { $0.status == .done && ($0.completedAt ?? .distantPast) >= cutoff }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    /// Cross-project digest counts. Used by `DigestLineView` to compose the
    /// "今天完成 N 件　outstanding M 件　X 個專案有東西未完成" summary line.
    func digestSummary(now: Date = Date()) -> (doneToday: Int, outstanding: Int, projectsWithOutstanding: Int) {
        let calendar = Calendar.current
        let doneToday = cards.filter { c in
            guard c.status == .done, let d = c.completedAt else { return false }
            return calendar.isDate(d, inSameDayAs: now)
        }.count
        let outstandingCards = cards.filter { $0.status == .todo }
        let projectsWithOutstanding = Set(outstandingCards.map { $0.sourceId }).count
        return (doneToday, outstandingCards.count, projectsWithOutstanding)
    }
}
