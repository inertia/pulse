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
    private var watchers: [UUID: FileWatcher] = [:]

    init(sourceStore: SourceStore = SourceStore(),
         cardStore: CardStore,
         parser: MultiStrategyMarkdownParser = MultiStrategyMarkdownParser(),
         settings: Settings) {
        self.sourceStore = sourceStore
        self.cardStore = cardStore
        self.parser = parser
        self.settings = settings
    }

    /// Called on app launch. Runs initial refresh, installs per-source FSEvent
    /// watchers (markdown files + each git repo's `.git/logs/HEAD`), and starts
    /// a 1-hour backstop timer. Most refreshes happen via FSEvents within ~1.5s
    /// of a file change; the hourly timer is just defence against edge cases
    /// (network filesystems, missed events, sources added but watcher install failed).
    func start() async {
        await forceRefresh()
        installWatchers()
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60 * 60 * 1_000_000_000)   // 1 hour
                if Task.isCancelled { break }
                await self?.forceRefresh()
            }
        }
    }

    /// Stop the periodic timer + tear down FSEvent watchers.
    func stop() {
        timerTask?.cancel()
        timerTask = nil
        teardownWatchers()
    }

    /// Refresh all enabled sources. Updates isLoading + loadingProgress. Also
    /// re-installs FSEvent watchers so newly-added sources start being tracked
    /// without an app restart.
    func forceRefresh() async {
        let sources = sourceStore.load().filter { $0.enabled }
        guard !sources.isEmpty else {
            lastRefreshAt = Date()
            installWatchers()
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

        // Re-install watchers in case the source list changed (rescan / add /
        // remove) since last call. Cheap operation — watchers are kernel objects.
        installWatchers()
    }

    // MARK: - FSEvent watchers

    /// (Re)install one FileWatcher per enabled source. Existing watchers are
    /// torn down first, so this is idempotent and safe to call from any path
    /// that mutates the source list.
    ///
    /// Watch targets:
    /// * `claudeMd` / `agentsMd` / `geminiMd`: the markdown file itself
    ///   (FileWatcher monitors its parent dir under the hood, so atomic-rename
    ///   editors are handled).
    /// * `gitLog`: the repo's `.git/logs/HEAD`, which appends a line on every
    ///   commit / merge / reset on HEAD. More reliable than `.git/HEAD`
    ///   (which only changes on branch switch) and `.git/refs/heads/<branch>`
    ///   (which requires knowing the current branch name and fails on detached
    ///   HEAD). If the file doesn't exist (uncommitted repo) the watcher is
    ///   created against the parent dir anyway and will fire when the file
    ///   first appears.
    /// Incremental: tear down only watchers whose source disappeared, install
    /// only watchers for newly-added sources. Existing FSEventStreams are left
    /// intact across refreshes — important under ad-hoc signing where
    /// recreating streams on `~/Desktop` subdirectories can re-trigger TCC
    /// permission prompts.
    private func installWatchers() {
        let sources = sourceStore.load().filter { $0.enabled }
        let currentIds = Set(sources.map { $0.id })

        for removedId in Set(watchers.keys).subtracting(currentIds) {
            watchers[removedId]?.stop()
            watchers.removeValue(forKey: removedId)
        }

        for source in sources where watchers[source.id] == nil {
            let watchURL: URL
            switch source.kind {
            case .claudeMd, .agentsMd, .geminiMd:
                watchURL = source.path
            case .gitLog:
                watchURL = source.path
                    .appendingPathComponent(".git")
                    .appendingPathComponent("logs")
                    .appendingPathComponent("HEAD")
            }
            let sourceId = source.id
            let watcher = FileWatcher(fileURL: watchURL) { [weak self] in
                Task { @MainActor in
                    guard let self = self else { return }
                    if let s = self.sourceStore.load().first(where: { $0.id == sourceId }) {
                        await self.refresh(s)
                    }
                }
            }
            watcher.start()
            watchers[source.id] = watcher
        }
    }

    private func teardownWatchers() {
        for (_, watcher) in watchers {
            watcher.stop()
        }
        watchers.removeAll()
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
