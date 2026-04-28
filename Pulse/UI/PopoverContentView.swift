import SwiftUI

enum CardFilter: String, CaseIterable, Identifiable {
    case all, todo, done
    var id: String { rawValue }
    var label: String {
        switch self {
        case .all: return "全部"
        case .todo: return "待辦"
        case .done: return "已完成"
        }
    }
}

struct PopoverContentView: View {
    @ObservedObject var scheduler: RefreshScheduler
    @ObservedObject var cardStore: CardStore
    let sourceStore: SourceStore
    let onSettingsTap: () -> Void

    @State private var filter: CardFilter = .all

    var body: some View {
        VStack(spacing: 0) {
            PopoverHeaderView(
                onSettings: onSettingsTap,
                onRefresh: { Task { await scheduler.forceRefresh() } }
            )
            FilterBar(filter: $filter)
            content
            PopoverFooterView(
                stats: stats,
                lastRefreshAt: scheduler.lastRefreshAt,
                isLoading: scheduler.isLoading
            )
        }
        .frame(width: 400, height: 600)
    }

    @ViewBuilder
    private var content: some View {
        if scheduler.isLoading && cardStore.cards.isEmpty {
            LoadingPlaceholderView(progress: scheduler.loadingProgress)
        } else if cardStore.cards.isEmpty {
            EmptyStateView(onSettingsTap: onSettingsTap)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(grouped) { group in
                        // Task 26 will replace this placeholder with ProjectGroupView.
                        Text("\(group.label) — \(group.cards.count) cards")
                            .padding(.horizontal, 12)
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }

    private var grouped: [ProjectGroup] {
        Self.computeGroups(
            cards: cardStore.cards,
            sources: sourceStore.load(),
            filter: filter
        )
    }

    private var stats: PopoverStats {
        Self.computeStats(cards: cardStore.cards, sources: sourceStore.load())
    }
}

extension PopoverContentView {
    /// Filter + group cards. Sorts: todo first, then done by completedAt desc; groups by source label, sorted alphabetically.
    static func computeGroups(cards: [Card], sources: [Source], filter: CardFilter) -> [ProjectGroup] {
        let labelById = Dictionary(uniqueKeysWithValues: sources.map { ($0.id, $0.label) })

        let filtered = cards.filter { card in
            switch filter {
            case .all:  return true
            case .todo: return card.status == .todo
            case .done: return card.status == .done
            }
        }

        let byLabel = Dictionary(grouping: filtered) { card in
            labelById[card.sourceId] ?? "Unknown"
        }

        return byLabel
            .map { (label, cards) in
                let sorted = cards.sorted { lhs, rhs in
                    if lhs.status != rhs.status { return lhs.status == .todo }
                    return (lhs.completedAt ?? .distantPast) > (rhs.completedAt ?? .distantPast)
                }
                let groupSources = sources.filter { labelById[$0.id] == label }
                return ProjectGroup(label: label, sources: groupSources, cards: sorted)
            }
            .sorted { $0.label < $1.label }
    }

    /// Compute stats: distinct project labels (cards with known source), total todos, total dones.
    static func computeStats(cards: [Card], sources: [Source]) -> PopoverStats {
        let labelById = Dictionary(uniqueKeysWithValues: sources.map { ($0.id, $0.label) })
        let labels = Set(cards.compactMap { labelById[$0.sourceId] })
        return PopoverStats(
            projects: labels.count,
            todos: cards.filter { $0.status == .todo }.count,
            dones: cards.filter { $0.status == .done }.count
        )
    }
}
