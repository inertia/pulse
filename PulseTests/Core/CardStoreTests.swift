import XCTest
@testable import Pulse

@MainActor
final class CardStoreTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = FileManager.default
            .temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
    }

    override func tearDownWithError() throws {
        if let tempDir, FileManager.default.fileExists(atPath: tempDir.path) {
            try? FileManager.default.removeItem(at: tempDir)
        }
        tempDir = nil
        try super.tearDownWithError()
    }

    // MARK: - Helpers

    private func makeCard(
        sourceId: UUID,
        path: String,
        heading: String,
        title: String,
        status: Status = .todo
    ) -> Card {
        Card(
            id: Card.makeId(path: path, sectionHeading: heading, normalizedTitle: title),
            sourceId: sourceId,
            title: title,
            body: nil,
            status: status,
            dueDate: nil,
            completedAt: nil,
            sourceRef: "\(path):1",
            tags: []
        )
    }

    // MARK: - 1. Round-trip

    func testLoadRoundTrip() throws {
        let store = CardStore(directoryURL: tempDir)
        let sourceId = UUID()
        let cards = [
            makeCard(sourceId: sourceId, path: "/tmp/a/CLAUDE.md",
                     heading: "## Todo", title: "ship pulse v0.1"),
            makeCard(sourceId: sourceId, path: "/tmp/a/CLAUDE.md",
                     heading: "## Todo", title: "review spec",
                     status: .done)
        ]
        store.replace(forSource: sourceId, with: cards)
        try store.save()

        let fresh = CardStore(directoryURL: tempDir)
        fresh.load()

        XCTAssertEqual(fresh.cards, cards)
    }

    // MARK: - 2. Replace isolates other sources

    func testReplaceForSourceLeavesOtherSourcesAlone() {
        let store = CardStore(directoryURL: tempDir)
        let sourceA = UUID()
        let sourceB = UUID()

        let cardA1 = makeCard(sourceId: sourceA, path: "/a/CLAUDE.md",
                              heading: "## Todo", title: "A1")
        let cardA2 = makeCard(sourceId: sourceA, path: "/a/CLAUDE.md",
                              heading: "## Todo", title: "A2")
        let cardB1 = makeCard(sourceId: sourceB, path: "/b/CLAUDE.md",
                              heading: "## Todo", title: "B1")

        store.replace(forSource: sourceA, with: [cardA1, cardA2])
        store.replace(forSource: sourceB, with: [cardB1])

        let newCardA = makeCard(sourceId: sourceA, path: "/a/CLAUDE.md",
                                heading: "## Todo", title: "A_new")
        store.replace(forSource: sourceA, with: [newCardA])

        XCTAssertEqual(store.cards.filter { $0.sourceId == sourceB }, [cardB1],
                       "sourceB cards must be untouched")
        XCTAssertEqual(store.cards.filter { $0.sourceId == sourceA }, [newCardA],
                       "sourceA cards must be replaced")
    }

    // MARK: - 3. Schema mismatch = cold start

    func testSchemaMismatchTreatedAsColdStart() throws {
        try FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true
        )
        let url = tempDir.appendingPathComponent("cards-cache.json")
        try #"{"version": 999, "cards": []}"#.write(to: url, atomically: true, encoding: .utf8)

        let store = CardStore(directoryURL: tempDir)
        store.load()

        XCTAssertEqual(store.cards, [],
                       "version mismatch must be treated as cold start (empty cards)")
    }

    // MARK: - 4. Corrupt JSON = cold start

    func testCorruptJsonTreatedAsColdStart() throws {
        try FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true
        )
        let url = tempDir.appendingPathComponent("cards-cache.json")
        try "not-json".write(to: url, atomically: true, encoding: .utf8)

        let store = CardStore(directoryURL: tempDir)
        store.load()

        XCTAssertEqual(store.cards, [],
                       "corrupt JSON must be treated as cold start (empty cards)")
    }

    // MARK: - 5. Missing file = empty

    func testMissingFileLoadsEmpty() {
        let store = CardStore(directoryURL: tempDir)
        store.load()
        XCTAssertEqual(store.cards, [])
    }

    // MARK: - 6. Save creates dir + file

    func testSaveCreatesDirectoryAndFile() throws {
        let store = CardStore(directoryURL: tempDir)
        let sourceId = UUID()
        let card = makeCard(sourceId: sourceId, path: "/tmp/CLAUDE.md",
                            heading: "## Todo", title: "first")
        store.replace(forSource: sourceId, with: [card])

        try store.save()

        let expectedURL = tempDir.appendingPathComponent("cards-cache.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: expectedURL.path),
                      "cards-cache.json should exist at \(expectedURL.path)")
    }

    // MARK: - 7. Saved file has version field

    func testSavedFileHasVersionField() throws {
        let store = CardStore(directoryURL: tempDir)
        let sourceId = UUID()
        store.replace(forSource: sourceId, with: [
            makeCard(sourceId: sourceId, path: "/tmp/CLAUDE.md",
                     heading: "## Todo", title: "first")
        ])

        try store.save()

        let url = tempDir.appendingPathComponent("cards-cache.json")
        let raw = try String(contentsOf: url, encoding: .utf8)

        XCTAssertTrue(raw.contains("\"version\" : 1"),
                      "saved JSON must contain `\"version\" : 1` (sortedKeys + prettyPrinted), got:\n\(raw)")
    }

    // MARK: - Aggregates (Q6 Overview tab)

    /// Build a Card with optional completedAt. Distinct from `makeCard` to avoid
    /// signature drift on the existing helper used by the load/save tests.
    private func makeAggregateCard(
        sourceId: UUID,
        title: String,
        status: Status = .todo,
        completedAt: Date? = nil
    ) -> Card {
        Card(
            id: Card.makeId(path: "/x/CLAUDE.md", sectionHeading: "## Todo", normalizedTitle: title),
            sourceId: sourceId,
            title: title,
            body: nil,
            status: status,
            dueDate: nil,
            completedAt: completedAt,
            sourceRef: "/x/CLAUDE.md:1",
            tags: []
        )
    }

    // MARK: - 8. cardsAcrossProjects filter by status

    func testCardsAcrossProjects_filtersByStatus() {
        let store = CardStore(directoryURL: tempDir)
        let s1 = UUID(); let s2 = UUID()
        store.replace(forSource: s1, with: [
            makeAggregateCard(sourceId: s1, title: "todo-A", status: .todo),
            makeAggregateCard(sourceId: s1, title: "done-A", status: .done, completedAt: Date())
        ])
        store.replace(forSource: s2, with: [
            makeAggregateCard(sourceId: s2, title: "todo-B", status: .todo)
        ])

        let todos = store.cardsAcrossProjects(status: .todo)
        let dones = store.cardsAcrossProjects(status: .done)

        XCTAssertEqual(Set(todos.map { $0.title }), ["todo-A", "todo-B"],
                       "todo filter must return all todos across sources")
        XCTAssertEqual(Set(dones.map { $0.title }), ["done-A"],
                       "done filter must return only done cards")
    }

    // MARK: - 9. cardsAcrossProjects filter by priority (🔴 / 🟡 prefix)

    func testCardsAcrossProjects_filtersByPriority() {
        let store = CardStore(directoryURL: tempDir)
        let src = UUID()
        store.replace(forSource: src, with: [
            makeAggregateCard(sourceId: src, title: "🔴 ship pulse v0.3"),
            makeAggregateCard(sourceId: src, title: "🟡 fix tooltip"),
            makeAggregateCard(sourceId: src, title: "regular task"),
            makeAggregateCard(sourceId: src, title: "🔴 second urgent")
        ])

        let urgent = store.cardsAcrossProjects(status: .todo, priority: .urgent)
        let high = store.cardsAcrossProjects(status: .todo, priority: .high)
        let normal = store.cardsAcrossProjects(status: .todo, priority: .normal)

        XCTAssertEqual(urgent.count, 2, "🔴 prefix → urgent (2 cards)")
        XCTAssertTrue(urgent.allSatisfy { $0.title.hasPrefix("🔴") })
        XCTAssertEqual(high.count, 1, "🟡 prefix → high (1 card)")
        XCTAssertEqual(normal.count, 1, "no emoji → normal (1 card)")
    }

    // MARK: - 10. doneCardsLast hour boundary

    func testDoneCardsLast_excludesOlderThanCutoff() {
        let store = CardStore(directoryURL: tempDir)
        let src = UUID()
        let now = Date()
        let inside = now.addingTimeInterval(-23 * 3600)   // 23h ago — within 24h
        let outside = now.addingTimeInterval(-25 * 3600)  // 25h ago — beyond 24h
        store.replace(forSource: src, with: [
            makeAggregateCard(sourceId: src, title: "recent-done",
                              status: .done, completedAt: inside),
            makeAggregateCard(sourceId: src, title: "old-done",
                              status: .done, completedAt: outside)
        ])

        let recent = store.doneCardsLast(hours: 24, now: now)

        XCTAssertEqual(recent.map { $0.title }, ["recent-done"],
                       "doneCardsLast must include cards within cutoff and exclude older ones")
    }

    // MARK: - 11. digestSummary counts

    func testDigestSummary_countsCorrectly() {
        let store = CardStore(directoryURL: tempDir)
        let s1 = UUID(); let s2 = UUID(); let s3 = UUID()
        let now = Date()
        let earlierToday = Calendar.current.startOfDay(for: now).addingTimeInterval(3 * 3600)
        store.replace(forSource: s1, with: [
            makeAggregateCard(sourceId: s1, title: "todo-1"),
            makeAggregateCard(sourceId: s1, title: "done-today",
                              status: .done, completedAt: earlierToday)
        ])
        store.replace(forSource: s2, with: [
            makeAggregateCard(sourceId: s2, title: "todo-2"),
            makeAggregateCard(sourceId: s2, title: "todo-3")
        ])
        // s3 has only a done card — outstanding count for s3 is 0, so it is NOT
        // counted as a "project with outstanding".
        store.replace(forSource: s3, with: [
            makeAggregateCard(sourceId: s3, title: "old-done",
                              status: .done,
                              completedAt: now.addingTimeInterval(-5 * 86400))
        ])

        let digest = store.digestSummary(now: now)

        XCTAssertEqual(digest.doneToday, 1, "only the today-done counts")
        XCTAssertEqual(digest.outstanding, 3, "3 todo cards across s1+s2")
        XCTAssertEqual(digest.projectsWithOutstanding, 2,
                       "s1 and s2 each have ≥1 todo; s3 has none")
    }
}
