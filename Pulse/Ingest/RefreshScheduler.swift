import Foundation

@MainActor
final class RefreshScheduler: ObservableObject {
    private let sourceStore: SourceStore
    private let cardStore: CardStore
    private let parser: MultiStrategyMarkdownParser
    private let settings: Settings   // 只在 main 讀取做快照，不傳給 ingesters

    @Published var lastRefreshAt: Date?
    @Published var isLoading: Bool = false
    @Published var loadingProgress: (done: Int, total: Int) = (0, 0)

    private var timerTask: Task<Void, Never>?

    init(sourceStore: SourceStore = SourceStore(),
         cardStore: CardStore,
         parser: MultiStrategyMarkdownParser = MultiStrategyMarkdownParser(),
         settings: Settings) {
        self.sourceStore = sourceStore
        self.cardStore = cardStore
        self.parser = parser
        self.settings = settings
    }

    /// Called on app launch. Runs initial refresh + starts 5-min timer.
    func start() async {
        await forceRefresh()
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5 * 60 * 1_000_000_000)   // 5 min
                if Task.isCancelled { break }
                await self?.forceRefresh()
            }
        }
    }

    /// Stop the periodic timer (e.g., on app shutdown / for tests).
    func stop() {
        timerTask?.cancel()
        timerTask = nil
    }

    /// Refresh all enabled sources. Updates isLoading + loadingProgress.
    func forceRefresh() async {
        let sources = sourceStore.load().filter { $0.enabled }
        guard !sources.isEmpty else {
            lastRefreshAt = Date()
            return
        }
        isLoading = true
        loadingProgress = (0, sources.count)
        defer { isLoading = false }

        let enabledTypes = settings.gitFilterPreset.enabledTypes   // snapshot on main

        // TODO(v0.2): parallel limit 4 (sequential for v0.1 — most users <10 sources)
        var done = 0
        for source in sources {
            await refresh(source, enabledTypes: enabledTypes)
            done += 1
            loadingProgress = (done, sources.count)
        }
        lastRefreshAt = Date()
        try? cardStore.save()

        // Sweep aged `- [x] (done YYYY-MM-DD) ...` lines from pulse.md files.
        // pulse.md is registered with kind=.claudeMd in Internal.swift, so
        // distinguish by filename rather than kind.
        let pulseURLs: [URL] = sources
            .filter { $0.path.lastPathComponent == "pulse.md" }
            .map { $0.path }
        PulseFileMaintenance.cleanAgedDoneItems(pulseURLs: pulseURLs)
    }

    /// Refresh a single source (used by FSEvents trigger in Task 24).
    func refresh(_ source: Source) async {
        let enabledTypes = settings.gitFilterPreset.enabledTypes   // snapshot on main
        await refresh(source, enabledTypes: enabledTypes)
        try? cardStore.save()
    }

    /// Internal helper that takes the enabledTypes snapshot.
    private func refresh(_ source: Source, enabledTypes: Set<String>) async {
        guard source.enabled else { return }
        do {
            let cards: [Card]
            switch source.kind {
            case .claudeMd, .agentsMd, .geminiMd:
                let ingester = MarkdownIngester(parser: parser)
                cards = try await ingester.fetch(source: source)
            case .gitLog:
                let ingester = GitIngester(enabledTypes: enabledTypes)
                cards = try await ingester.fetch(source: source)
            }
            cardStore.replace(forSource: source.id, with: cards)
        } catch {
            // Per spec §7: missing path / failed git log = source shows missing,
            // but DON'T crash the scheduler. Leave existing cached cards alone.
        }
    }
}
