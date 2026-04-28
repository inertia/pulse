import SwiftUI

enum CardFilter: String, CaseIterable, Identifiable {
    case all, todo, done
    var id: String { rawValue }
}

struct PopoverContentView: View {
    @ObservedObject var scheduler: RefreshScheduler
    @ObservedObject var cardStore: CardStore
    @ObservedObject var quickTodoStore: QuickTodoStore
    let sourceStore: SourceStore
    let onSettingsTap: () -> Void

    @State private var selectedLabel: String?
    @State private var showDone = false

    var body: some View {
        VStack(spacing: 0) {
            PopoverHeaderView(
                onSettings: onSettingsTap,
                onRefresh: { Task { await scheduler.forceRefresh() } }
            )
            content
            PopoverFooterView(
                stats: stats,
                lastRefreshAt: scheduler.lastRefreshAt,
                isLoading: scheduler.isLoading
            )
        }
        .frame(width: 400, height: 600)
        .onAppear { ensureSelection() }
        .onChange(of: groupLabels) { _, _ in ensureSelection() }
    }

    @ViewBuilder
    private var content: some View {
        if scheduler.isLoading && cardStore.cards.isEmpty && quickTodoStore.todos.isEmpty {
            LoadingPlaceholderView(progress: scheduler.loadingProgress)
        } else if grouped.isEmpty {
            EmptyStateView(onSettingsTap: onSettingsTap)
            composer
        } else {
            VStack(spacing: 0) {
                ProjectTabBar(groups: grouped, selectedLabel: $selectedLabel)
                Divider().opacity(0.3)
                projectBody
                composer
            }
        }
    }

    private var composer: some View {
        QuickTodoComposer(
            store: quickTodoStore,
            projects: projectTargets,
            onProjectWrite: handleProjectWrite
        )
    }

    /// Distinct project targets for quick-write (one per project label that has at least one source).
    /// Project dir is the parent dir of any markdown source; for git-only projects the dir itself.
    private var projectTargets: [QuickTodoComposer.ProjectTarget] {
        let sources = sourceStore.load()
        var seen = Set<String>()
        var out: [QuickTodoComposer.ProjectTarget] = []
        for source in sources where source.enabled {
            if seen.contains(source.label) { continue }
            let dir: URL
            switch source.kind {
            case .gitLog:
                dir = source.path                          // git source path is repo dir
            case .claudeMd, .agentsMd, .geminiMd:
                dir = source.path.deletingLastPathComponent()  // markdown is file inside dir
            }
            out.append(.init(label: source.label, projectDir: dir))
            seen.insert(source.label)
        }
        return out
    }

    /// After PulseQuickWriter writes to a project's PULSE_QUICK.md, register it
    /// as a source if not already, and trigger refresh so it appears in popover.
    private func handleProjectWrite(_ url: URL) {
        var sources = sourceStore.load()
        let projectDir = url.deletingLastPathComponent()
        let label = sources.first(where: {
            ($0.kind == .gitLog && $0.path == projectDir)
                || $0.path.deletingLastPathComponent() == projectDir
        })?.label ?? projectDir.lastPathComponent

        if !sources.contains(where: { $0.path == url }) {
            let new = Source(kind: .claudeMd, path: url, label: label, enabled: true)
            sources.append(new)
            try? sourceStore.save(sources)
        }
        Task {
            if let s = sources.first(where: { $0.path == url }) {
                await scheduler.refresh(s)
            } else {
                await scheduler.forceRefresh()
            }
            selectedLabel = label    // jump to that project's tab
        }
    }

    @ViewBuilder
    private var projectBody: some View {
        if let group = selectedGroup {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    let todos = group.cards.filter { $0.status == .todo }
                    let dones = group.cards.filter { $0.status == .done }

                    if todos.isEmpty {
                        Text("沒有待辦")
                            .font(.callout)
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 24)
                    } else {
                        ForEach(todos) { card in
                            CardRowView(card: card, onTap: { tap(card, in: group) })
                        }
                    }

                    if !dones.isEmpty {
                        Divider().padding(.vertical, 4)
                        DisclosureGroup(isExpanded: $showDone) {
                            VStack(spacing: 6) {
                                ForEach(dones.prefix(20)) { card in
                                    CardRowView(card: card, onTap: { tap(card, in: group) })
                                }
                            }
                            .padding(.top, 4)
                        } label: {
                            Text("已完成 (\(dones.count))")
                                .font(.system(.caption, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 4)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
        } else {
            EmptyView()
        }
    }

    private func tap(_ card: Card, in group: ProjectGroup) {
        // Quick todos: toggle on tap (no source open).
        if card.sourceId == QuickTodoConstants.sourceId {
            if let uuid = UUID(uuidString: card.id) {
                quickTodoStore.toggle(uuid)
            }
            return
        }
        if let source = group.sources.first(where: { $0.id == card.sourceId }) {
            OpenSourceRef.open(card: card, source: source)
        }
    }

    // MARK: - Group / stat composition

    private var grouped: [ProjectGroup] {
        Self.computeGroups(
            cards: cardStore.cards + quickTodoStore.cards(),
            sources: sourceStore.load(),
            filter: .all
        )
    }

    private var groupLabels: [String] { grouped.map { $0.label } }

    private var selectedGroup: ProjectGroup? {
        if let label = selectedLabel,
           let g = grouped.first(where: { $0.label == label }) { return g }
        return grouped.first
    }

    private var stats: PopoverStats {
        Self.computeStats(
            cards: cardStore.cards + quickTodoStore.cards(),
            sources: sourceStore.load()
        )
    }

    private func ensureSelection() {
        if let label = selectedLabel, grouped.contains(where: { $0.label == label }) {
            return
        }
        // pick the project with the most TODOs, or first available
        let bestLabel = grouped
            .max(by: {
                $0.cards.filter { $0.status == .todo }.count <
                $1.cards.filter { $0.status == .todo }.count
            })?.label
            ?? grouped.first?.label
        selectedLabel = bestLabel
    }
}

extension PopoverContentView {
    /// Group cards by label (project / quick), with todos first then dones-by-completedAt-desc within each group.
    /// QuickTodo virtual project (label "📝 快速記") is forced to first position.
    static func computeGroups(cards: [Card], sources: [Source], filter: CardFilter) -> [ProjectGroup] {
        let labelById: [UUID: String] = {
            var dict = Dictionary(uniqueKeysWithValues: sources.map { ($0.id, $0.label) })
            dict[QuickTodoConstants.sourceId] = QuickTodoConstants.label
            return dict
        }()

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

        let groups = byLabel.map { (label, cards) -> ProjectGroup in
            let sorted = cards.sorted { lhs, rhs in
                if lhs.status != rhs.status { return lhs.status == .todo }
                return (lhs.completedAt ?? .distantPast) > (rhs.completedAt ?? .distantPast)
            }
            let groupSources = sources.filter { labelById[$0.id] == label }
            return ProjectGroup(label: label, sources: groupSources, cards: sorted)
        }

        return groups.sorted { lhs, rhs in
            // Pin Quick to first.
            if lhs.label == QuickTodoConstants.label { return true }
            if rhs.label == QuickTodoConstants.label { return false }
            return lhs.label < rhs.label
        }
    }

    /// Stats: distinct project labels (cards with known source/quick), total todos, total dones.
    static func computeStats(cards: [Card], sources: [Source]) -> PopoverStats {
        var labelById = Dictionary(uniqueKeysWithValues: sources.map { ($0.id, $0.label) })
        labelById[QuickTodoConstants.sourceId] = QuickTodoConstants.label
        let labels = Set(cards.compactMap { labelById[$0.sourceId] })
        return PopoverStats(
            projects: labels.count,
            todos: cards.filter { $0.status == .todo }.count,
            dones: cards.filter { $0.status == .done }.count
        )
    }
}
