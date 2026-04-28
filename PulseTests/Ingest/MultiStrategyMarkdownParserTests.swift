import XCTest
@testable import Pulse

final class MultiStrategyMarkdownParserTests: XCTestCase {

    // MARK: - Fixture path helper (uses #file so it works from any machine / CI)

    private static func fixturePath(_ name: String) -> URL {
        URL(fileURLWithPath: #file)
            .deletingLastPathComponent()  // PulseTests/Ingest/
            .deletingLastPathComponent()  // PulseTests/
            .appendingPathComponent("Fixtures")
            .appendingPathComponent(name)
    }

    // MARK: - Tempfile helper

    private func writeTempMarkdown(content: String, name: String = "test.md") throws -> URL {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("PulseTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(name)
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: - 1. Checkbox fixture integration

    func testCheckboxFixtureIntegration() throws {
        let parser = MultiStrategyMarkdownParser()
        let cards = try parser.parse(filePath: Self.fixturePath("checkbox-style.md"), sourceId: UUID())

        let todos = cards.filter { $0.status == .todo }
        let dones = cards.filter { $0.status == .done }

        XCTAssertEqual(todos.count, 3, "expect 3 todo items in ## To Do section")
        XCTAssertEqual(dones.count, 2, "expect 2 done items in ## Done section")
        XCTAssertEqual(cards.count, 5, "Notes section bullets must NOT be collected")

        // Date extraction → dueDate
        let secondTodo = todos.first(where: { $0.title == "Second todo with date" })
        XCTAssertNotNil(secondTodo, "title must be stripped of trailing (2026-05-01)")
        XCTAssertNotNil(secondTodo?.dueDate)
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = TimeZone(identifier: "UTC")
        XCTAssertEqual(secondTodo?.dueDate, fmt.date(from: "2026-05-01"))

        // Tag extraction
        let thirdTodo = todos.first(where: { $0.title.hasPrefix("Third todo with") })
        XCTAssertNotNil(thirdTodo)
        XCTAssertEqual(thirdTodo?.tags, ["urgent", "review"])
        XCTAssertFalse(thirdTodo?.title.contains("#") ?? true, "title must have tags stripped")

        // Done-side date → completedAt
        let secondDone = dones.first(where: { $0.title == "Second done item with date" })
        XCTAssertNotNil(secondDone)
        XCTAssertNotNil(secondDone?.completedAt)
        XCTAssertEqual(secondDone?.completedAt, fmt.date(from: "2026-04-25"))
        XCTAssertNil(secondDone?.dueDate, "done items put date in completedAt, not dueDate")
    }

    // MARK: - 2. Heterotopias fixture integration

    func testHeterotopiasFixtureIntegration() throws {
        let parser = MultiStrategyMarkdownParser()
        let cards = try parser.parse(filePath: Self.fixturePath("heterotopias-sample.md"), sourceId: UUID())

        XCTAssertGreaterThan(cards.count, 5, "fixture should yield more than 5 cards")

        let dones = cards.filter { $0.status == .done }
        XCTAssertGreaterThanOrEqual(dones.count, 5, "Recently Done section has 5 ✅ items")

        // ✅ items live under "Recently Done (2026-04-17)" sectionHeading
        let recentlyDone = dones.filter { $0.sourceRef.contains("heterotopias-sample.md") }
        XCTAssertFalse(recentlyDone.isEmpty)

        // Verify a numbered todo from URGENT or HIGH section exists
        let todos = cards.filter { $0.status == .todo }
        XCTAssertGreaterThanOrEqual(todos.count, 3, "URGENT (1) + HIGH (2) + MEDIUM (2) numbered items")

        // sourceRef format: "filename:lineNumber"
        for card in cards {
            XCTAssertTrue(card.sourceRef.contains("heterotopias-sample.md:"), "sourceRef must include filename:lineNumber")
        }
    }

    // MARK: - 3. Cross-strategy dedup

    func testCrossStrategyDedup() throws {
        // Construct a mock where two strategies emit identical ParsedItems → only 1 card.
        struct EchoStrategy: MarkdownStrategy {
            let item: ParsedItem
            func parse(lines: [String], sourcePath: URL) -> [ParsedItem] { [item] }
        }
        let path = URL(fileURLWithPath: "/tmp/dedup-test.md")
        let item = ParsedItem(
            title: "duplicate task",
            body: nil,
            status: .todo,
            lineNumber: 1,
            sectionHeading: "To Do",
            dueDate: nil,
            completedAt: nil,
            tags: []
        )
        let parser = MultiStrategyMarkdownParser(strategies: [EchoStrategy(item: item), EchoStrategy(item: item)])

        // We need to feed parser real content but the strategies will emit identical items regardless.
        let url = try writeTempMarkdown(content: "irrelevant\n", name: "dedup-test.md")
        let cards = try parser.parse(filePath: url, sourceId: UUID())

        XCTAssertEqual(cards.count, 1, "two strategies emitting identical items must dedup to 1 card")
    }

    // MARK: - 4. Line number drift regression (content-keyed identity)

    func testLineNumberDriftRegression() throws {
        let baseContent = """
        ## To Do

        - [ ] task one
        - [ ] task two

        ## Done

        - [x] task three
        """

        let shiftedContent = "\n\n\n\n\n" + baseContent

        let url1 = try writeTempMarkdown(content: baseContent, name: "drift.md")
        let url2 = try writeTempMarkdown(content: shiftedContent, name: "drift.md")

        let parser = MultiStrategyMarkdownParser()
        let sourceId = UUID()
        let cards1 = try parser.parse(filePath: url1, sourceId: sourceId)
        let cards2 = try parser.parse(filePath: url2, sourceId: sourceId)

        // Note: tempdirs differ → path differs → ids differ across the two URLs.
        // But within each parse, same content → 3 cards. To prove line-shift independence,
        // copy baseContent to same path under both names, but parse twice — once normal,
        // once with leading blank lines — assert SAME card titles AND if path matches,
        // SAME ids. To control for path, write both at the SAME path:
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("PulseTests-drift-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let samePath = dir.appendingPathComponent("drift.md")

        try baseContent.write(to: samePath, atomically: true, encoding: .utf8)
        let cardsA = try parser.parse(filePath: samePath, sourceId: sourceId)

        try shiftedContent.write(to: samePath, atomically: true, encoding: .utf8)
        let cardsB = try parser.parse(filePath: samePath, sourceId: sourceId)

        XCTAssertEqual(cardsA.count, 3)
        XCTAssertEqual(cardsB.count, 3)

        let idsA = Set(cardsA.map { $0.id })
        let idsB = Set(cardsB.map { $0.id })
        XCTAssertEqual(idsA, idsB, "line-number shifts must NOT change content-keyed identity")

        // sanity assertions on the unrelated url1/cards1 path so writeTempMarkdown stays exercised
        XCTAssertEqual(cards1.count, 3)
        XCTAssertEqual(cards2.count, 3)
    }

    // MARK: - 5. Trailing date → dueDate

    func testTrailingDateExtractedAsDueDate() throws {
        let url = try writeTempMarkdown(content: "## To Do\n- [ ] task with date (2026-05-01)\n")
        let cards = try MultiStrategyMarkdownParser().parse(filePath: url, sourceId: UUID())

        XCTAssertEqual(cards.count, 1)
        XCTAssertEqual(cards[0].title, "task with date")
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = TimeZone(identifier: "UTC")
        XCTAssertEqual(cards[0].dueDate, fmt.date(from: "2026-05-01"))
        XCTAssertNil(cards[0].completedAt)
    }

    // MARK: - 6. Trailing date on done → completedAt

    func testTrailingDateExtractedAsCompletedAt() throws {
        let url = try writeTempMarkdown(content: "## Done\n- [x] task (2026-04-25)\n")
        let cards = try MultiStrategyMarkdownParser().parse(filePath: url, sourceId: UUID())

        XCTAssertEqual(cards.count, 1)
        XCTAssertEqual(cards[0].title, "task")
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = TimeZone(identifier: "UTC")
        XCTAssertEqual(cards[0].completedAt, fmt.date(from: "2026-04-25"))
        XCTAssertNil(cards[0].dueDate)
    }

    // MARK: - 7. Fullwidth date brackets

    func testFullwidthDateBracket() throws {
        let url = try writeTempMarkdown(content: "## To Do\n- [ ] task （2026-05-01）\n")
        let cards = try MultiStrategyMarkdownParser().parse(filePath: url, sourceId: UUID())

        XCTAssertEqual(cards.count, 1)
        XCTAssertEqual(cards[0].title, "task")
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = TimeZone(identifier: "UTC")
        XCTAssertEqual(cards[0].dueDate, fmt.date(from: "2026-05-01"))
    }

    // MARK: - 8. Inline tags

    func testInlineTagsExtracted() throws {
        let url = try writeTempMarkdown(content: "## To Do\n- [ ] task with #urgent and #review tags\n")
        let cards = try MultiStrategyMarkdownParser().parse(filePath: url, sourceId: UUID())

        XCTAssertEqual(cards.count, 1)
        XCTAssertEqual(cards[0].tags, ["urgent", "review"])
        XCTAssertFalse(cards[0].title.contains("#"), "tags must be stripped from title")
        XCTAssertTrue(cards[0].title.contains("task with"), "non-tag content must remain")
        XCTAssertTrue(cards[0].title.contains("tags"), "non-tag content must remain")
    }

    // MARK: - 9. No date / no tags → title unchanged

    func testNoDateNoTagsLeavesTitleAsIs() throws {
        let url = try writeTempMarkdown(content: "## To Do\n- [ ] plain task\n")
        let cards = try MultiStrategyMarkdownParser().parse(filePath: url, sourceId: UUID())

        XCTAssertEqual(cards.count, 1)
        XCTAssertEqual(cards[0].title, "plain task")
        XCTAssertNil(cards[0].dueDate)
        XCTAssertNil(cards[0].completedAt)
        XCTAssertTrue(cards[0].tags.isEmpty)
    }

    // MARK: - 10. Normalization happens BEFORE hash

    func testNormalizationHappensBeforeHash() throws {
        // Two files at SAME path, content differs only by trailing date → same normalized title → same id.
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("PulseTests-norm-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let path = dir.appendingPathComponent("norm.md")

        try "## To Do\n- [ ] foo (2026-05-01)\n".write(to: path, atomically: true, encoding: .utf8)
        let cardsWithDate = try MultiStrategyMarkdownParser().parse(filePath: path, sourceId: UUID())

        try "## To Do\n- [ ] foo\n".write(to: path, atomically: true, encoding: .utf8)
        let cardsWithoutDate = try MultiStrategyMarkdownParser().parse(filePath: path, sourceId: UUID())

        XCTAssertEqual(cardsWithDate.count, 1)
        XCTAssertEqual(cardsWithoutDate.count, 1)
        XCTAssertEqual(cardsWithDate[0].id, cardsWithoutDate[0].id,
                       "id must be content-keyed on NORMALIZED title — adding/removing trailing date must NOT change id")
        XCTAssertEqual(cardsWithDate[0].title, "foo")
        XCTAssertEqual(cardsWithoutDate[0].title, "foo")
    }
}
