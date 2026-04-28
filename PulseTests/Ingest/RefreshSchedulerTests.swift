import Combine
import XCTest
@testable import Pulse

@MainActor
final class RefreshSchedulerTests: XCTestCase {

    // MARK: - Tempdir helpers

    private var tempDirs: [URL] = []
    private var cancellables: Set<AnyCancellable> = []

    override func setUp() async throws {
        try await super.setUp()
        tempDirs = []
        cancellables = []
    }

    override func tearDown() async throws {
        for dir in tempDirs where FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.removeItem(at: dir)
        }
        tempDirs = []
        cancellables.removeAll()
        try await super.tearDown()
    }

    private func makeTempDir(prefix: String = "RefreshSchedulerTests") throws -> URL {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("\(prefix)-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        tempDirs.append(dir)
        return dir
    }

    private func writeFile(_ content: String, named name: String, in dir: URL) throws -> URL {
        let url = dir.appendingPathComponent(name)
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private static let sampleMarkdown = """
    ## To Do

    - [ ] task1
    - [ ] task2

    ## Done

    - [x] done1
    """

    /// Run `cmd` via `/bin/sh -c` inside `dir`. Throws if non-zero exit.
    private func runShell(_ cmd: String, in dir: URL) throws {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = ["-c", cmd]
        p.currentDirectoryURL = dir
        p.standardOutput = Pipe()
        p.standardError = Pipe()
        try p.run()
        p.waitUntilExit()
        if p.terminationStatus != 0 {
            throw NSError(domain: "shell", code: Int(p.terminationStatus),
                          userInfo: [NSLocalizedDescriptionKey: "shell command failed: \(cmd)"])
        }
    }

    private func gitInit(in dir: URL) throws {
        try runShell("git init -q -b main", in: dir)
        try runShell("git config user.email test@test.com", in: dir)
        try runShell("git config user.name test", in: dir)
        try runShell("git config commit.gpgsign false", in: dir)
    }

    private func commit(_ subject: String, in dir: URL) throws {
        let f = "f-\(UUID().uuidString).txt"
        let escapedSubject = subject.replacingOccurrences(of: "'", with: "'\\''")
        try runShell("touch \(f) && git add \(f) && git commit -q -m '\(escapedSubject)'", in: dir)
    }

    /// Build a fully wired RefreshScheduler against ephemeral tempdirs / UserDefaults.
    private func makeScheduler() throws -> (
        scheduler: RefreshScheduler,
        sourceStore: SourceStore,
        cardStore: CardStore,
        settings: Settings,
        storeDir: URL
    ) {
        let storeDir = try makeTempDir(prefix: "RefreshSchedulerTests-store")
        let sourceStore = SourceStore(directoryURL: storeDir)
        let cardStore = CardStore(directoryURL: storeDir)
        let suiteName = "pulse.tests.refresh.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw NSError(domain: "test", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "could not create test UserDefaults"])
        }
        defaults.removePersistentDomain(forName: suiteName)
        let settings = Settings(defaults: defaults)
        let scheduler = RefreshScheduler(
            sourceStore: sourceStore,
            cardStore: cardStore,
            settings: settings
        )
        return (scheduler, sourceStore, cardStore, settings, storeDir)
    }

    // MARK: - 1. Refresh single markdown source

    func testRefreshSingleMarkdownSource() async throws {
        let (scheduler, sourceStore, cardStore, _, _) = try makeScheduler()
        let dir = try makeTempDir()
        let path = try writeFile(Self.sampleMarkdown, named: "CLAUDE.md", in: dir)
        let source = Source(kind: .claudeMd, path: path, label: "test")
        try sourceStore.save([source])

        await scheduler.refresh(source)

        XCTAssertEqual(cardStore.cards.count, 3, "sample markdown yields 3 cards")
        for card in cardStore.cards {
            XCTAssertEqual(card.sourceId, source.id, "all cards must carry source.id")
        }
    }

    // MARK: - 2. forceRefresh with multiple sources

    func testForceRefreshHandlesMultipleSources() async throws {
        let (scheduler, sourceStore, cardStore, _, _) = try makeScheduler()
        let dirA = try makeTempDir()
        let dirB = try makeTempDir()
        let pathA = try writeFile(Self.sampleMarkdown, named: "CLAUDE.md", in: dirA)
        let pathB = try writeFile(Self.sampleMarkdown, named: "AGENTS.md", in: dirB)
        let sourceA = Source(kind: .claudeMd, path: pathA, label: "a")
        let sourceB = Source(kind: .agentsMd, path: pathB, label: "b")
        try sourceStore.save([sourceA, sourceB])

        let beforeRefresh = Date()
        await scheduler.forceRefresh()

        let aCards = cardStore.cards.filter { $0.sourceId == sourceA.id }
        let bCards = cardStore.cards.filter { $0.sourceId == sourceB.id }
        XCTAssertEqual(aCards.count, 3, "sourceA yielded 3 cards")
        XCTAssertEqual(bCards.count, 3, "sourceB yielded 3 cards")
        XCTAssertEqual(cardStore.cards.count, 6, "total = 6 cards across 2 sources")

        let lastRefreshAt = scheduler.lastRefreshAt
        XCTAssertNotNil(lastRefreshAt)
        XCTAssertGreaterThanOrEqual(
            lastRefreshAt!,
            beforeRefresh.addingTimeInterval(-1),
            "lastRefreshAt should be ~now"
        )
    }

    // MARK: - 3. isLoading toggles around forceRefresh

    func testIsLoadingTogglesAroundForceRefresh() async throws {
        let (scheduler, sourceStore, _, _, _) = try makeScheduler()
        let dirA = try makeTempDir()
        let dirB = try makeTempDir()
        let pathA = try writeFile(Self.sampleMarkdown, named: "CLAUDE.md", in: dirA)
        let pathB = try writeFile(Self.sampleMarkdown, named: "AGENTS.md", in: dirB)
        try sourceStore.save([
            Source(kind: .claudeMd, path: pathA, label: "a"),
            Source(kind: .agentsMd, path: pathB, label: "b"),
        ])

        var observedIsLoading: [Bool] = []
        scheduler.$isLoading
            .sink { observedIsLoading.append($0) }
            .store(in: &cancellables)

        XCTAssertFalse(scheduler.isLoading, "initially not loading")
        await scheduler.forceRefresh()
        XCTAssertFalse(scheduler.isLoading, "after refresh, loading is false again")

        XCTAssertTrue(observedIsLoading.contains(true),
                      "isLoading should have been true at some point during refresh; got \(observedIsLoading)")
        XCTAssertEqual(observedIsLoading.last, false,
                       "final value should be false; got \(observedIsLoading)")
    }

    // MARK: - 4. forceRefresh with no sources still updates lastRefreshAt

    func testForceRefreshWithNoSourcesSetsLastRefreshAt() async throws {
        let (scheduler, _, cardStore, _, _) = try makeScheduler()

        XCTAssertNil(scheduler.lastRefreshAt)
        await scheduler.forceRefresh()

        XCTAssertNotNil(scheduler.lastRefreshAt, "even with 0 sources, lastRefreshAt updates")
        XCTAssertEqual(cardStore.cards.count, 0)
        XCTAssertFalse(scheduler.isLoading)
    }

    // MARK: - 5. Disabled source is skipped during forceRefresh

    func testDisabledSourceIsSkipped() async throws {
        let (scheduler, sourceStore, cardStore, _, _) = try makeScheduler()
        let dirA = try makeTempDir()
        let dirB = try makeTempDir()
        let pathA = try writeFile(Self.sampleMarkdown, named: "CLAUDE.md", in: dirA)
        let pathB = try writeFile(Self.sampleMarkdown, named: "AGENTS.md", in: dirB)
        let enabled = Source(kind: .claudeMd, path: pathA, label: "on", enabled: true)
        let disabled = Source(kind: .agentsMd, path: pathB, label: "off", enabled: false)
        try sourceStore.save([enabled, disabled])

        await scheduler.forceRefresh()

        XCTAssertEqual(cardStore.cards.count, 3, "only enabled source contributes cards")
        for card in cardStore.cards {
            XCTAssertEqual(card.sourceId, enabled.id, "only enabled source.id present")
        }
    }

    // MARK: - 6. refresh on a single disabled source does nothing

    func testRefreshOnSingleDisabledSourceDoesNothing() async throws {
        let (scheduler, _, cardStore, _, _) = try makeScheduler()
        let dir = try makeTempDir()
        let path = try writeFile(Self.sampleMarkdown, named: "CLAUDE.md", in: dir)
        let source = Source(kind: .claudeMd, path: path, label: "off", enabled: false)

        await scheduler.refresh(source)

        XCTAssertEqual(cardStore.cards.count, 0, "disabled source should be skipped")
    }

    // MARK: - 7. enabledTypes snapshot picks up new value on next refresh

    func testEnabledTypesSnapshotIsolation() async throws {
        let (scheduler, sourceStore, cardStore, settings, _) = try makeScheduler()
        let repoDir = try makeTempDir()
        try gitInit(in: repoDir)
        try commit("feat: x", in: repoDir)
        try commit("chore: y", in: repoDir)

        let source = Source(kind: .gitLog, path: repoDir, label: repoDir.lastPathComponent)
        try sourceStore.save([source])

        // First refresh under .recommended (excludes chore)
        settings.gitFilterPreset = .recommended
        await scheduler.refresh(source)
        XCTAssertEqual(cardStore.cards.count, 1,
                       ".recommended excludes chore; expected 1 card, got \(cardStore.cards.count)")
        XCTAssertEqual(cardStore.cards.first?.title, "x")

        // Switch to .all and refresh again — new snapshot should pick up chore.
        settings.gitFilterPreset = .all
        await scheduler.refresh(source)
        XCTAssertEqual(cardStore.cards.count, 2,
                       ".all includes chore; expected 2 cards after second refresh, got \(cardStore.cards.count)")
        let titles = Set(cardStore.cards.map { $0.title })
        XCTAssertEqual(titles, ["x", "y"], "second refresh should include both feat + chore titles")
    }

    // MARK: - 8. stop() cancels the timer cleanly

    func testStopCancelsTimer() async throws {
        let (scheduler, _, _, _, _) = try makeScheduler()

        // start() runs an initial refresh + spawns timerTask. The timer's first
        // sleep is 5 minutes, so it will not fire during this test.
        await scheduler.start()
        let firstRefreshAt = scheduler.lastRefreshAt
        XCTAssertNotNil(firstRefreshAt, "start() should run an initial refresh")

        scheduler.stop()
        // After stop, lastRefreshAt should not change just because the timer
        // would have fired — and stop() must not crash. Sample 50ms later.
        try await Task.sleep(nanoseconds: 50 * 1_000_000)
        XCTAssertEqual(scheduler.lastRefreshAt, firstRefreshAt,
                       "stop() must cancel timer; lastRefreshAt should not advance")
    }
}
