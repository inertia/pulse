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

    @State private var selectedLabel: String? = ProjectTabBar.overviewLabel
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
                ProjectTabBar(
                    groups: grouped,
                    selectedLabel: $selectedLabel,
                    overviewBadgeCount: overviewBadgeCount
                )
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

    /// After PulseQuickWriter writes to a project's pulse.md, register the
    /// file as a source, ensure CLAUDE.md has the hook section, and trigger
    /// refresh so the new todo appears.
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
        // Ensure CLAUDE.md hook (idempotent; no-op if file missing or already hooked).
        let claudeURL = CLAUDEMdHookWriter.claudeMdURL(for: projectDir)
        try? CLAUDEMdHookWriter.ensureHook(in: claudeURL)

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
        if selectedLabel == ProjectTabBar.overviewLabel {
            OverviewView(
                cardStore: cardStore,
                quickTodoStore: quickTodoStore,
                sourceStore: sourceStore,
                onCardTap: handleOverviewCardTap
            )
        } else if let group = selectedGroup {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        let todos = group.cards.filter { $0.status == .todo }
                        let dones = group.cards.filter { $0.status == .done }

                        if todos.isEmpty {
                            Text(L.emptyNoTodos)
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
                            Button {
                                withAnimation(.easeInOut(duration: 0.18)) { showDone.toggle() }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "chevron.right")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                        .rotationEffect(.degrees(showDone ? 90 : 0))
                                    Text(L.doneDisclosure(dones.count))
                                        .font(.system(.caption, weight: .medium))
                                        .foregroundStyle(.secondary)
                                    Spacer(minLength: 0)
                                }
                                .padding(.vertical, 6)
                                .padding(.horizontal, 4)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .id("done-disclosure")

                            if showDone {
                                VStack(spacing: 6) {
                                    ForEach(dones.prefix(20)) { card in
                                        CardRowView(card: card, onTap: { tap(card, in: group) })
                                    }
                                }
                                .padding(.top, 4)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
                .onChange(of: showDone) { _, newValue in
                    // When user expands done disclosure, the newly-revealed
                    // rows can land below the popover viewport and look like
                    // the click did nothing. Anchor the disclosure header to
                    // the top of the viewport on expand so revealed content
                    // fills below it.
                    if newValue {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            proxy.scrollTo("done-disclosure", anchor: .top)
                        }
                    }
                }
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

    /// Overview-tab tap handler: card is not bound to a single ProjectGroup
    /// so we resolve the source from sourceStore directly.
    private func handleOverviewCardTap(_ card: Card) {
        if card.sourceId == QuickTodoConstants.sourceId {
            if let uuid = UUID(uuidString: card.id) {
                quickTodoStore.toggle(uuid)
            }
            return
        }
        if let source = sourceStore.load().first(where: { $0.id == card.sourceId }) {
            OpenSourceRef.open(card: card, source: source)
        }
    }

    private var overviewBadgeCount: Int {
        grouped.reduce(0) { sum, group in
            sum + group.cards.filter { $0.status == .todo }.count
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
        // Overview is a sentinel that always exists — never invalidate it.
        if selectedLabel == ProjectTabBar.overviewLabel { return }
        if let label = selectedLabel, grouped.contains(where: { $0.label == label }) {
            return
        }
        // Selected project disappeared (source removed) or initial state with no
        // selection — fall back to Overview rather than auto-jumping into a project.
        selectedLabel = ProjectTabBar.overviewLabel
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
