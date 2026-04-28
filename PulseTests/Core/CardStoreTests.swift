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
}
