import XCTest
@testable import Pulse

final class NumberedSectionStrategyTests: XCTestCase {

    private let dummyURL = URL(fileURLWithPath: "/tmp/notes.md")

    // MARK: - Todo collection inside trigger sections

    func testNumberedTodoInUrgentSection() {
        let strategy = NumberedSectionStrategy()
        let lines = [
            "### URGENT",
            "1. **P0-1 Curation drift** — bilingual schema gap.",
            "2. **HIGH RISK migration** — needs schema reset."
        ]
        let items = strategy.parse(lines: lines, sourcePath: dummyURL)

        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].status, .todo)
        XCTAssertEqual(items[0].title, "P0-1 Curation drift")
        XCTAssertEqual(items[0].body, "bilingual schema gap.")
        XCTAssertEqual(items[0].sectionHeading, "URGENT")
        XCTAssertEqual(items[0].lineNumber, 2)
        XCTAssertEqual(items[1].status, .todo)
        XCTAssertEqual(items[1].title, "HIGH RISK migration")
        XCTAssertEqual(items[1].body, "needs schema reset.")
        XCTAssertEqual(items[1].sectionHeading, "URGENT")
        XCTAssertEqual(items[1].lineNumber, 3)
    }

    // MARK: - Done collection inside Recently Done section

    func testNumberedDoneInRecentlyDoneSection() {
        let strategy = NumberedSectionStrategy()
        let lines = [
            "### Recently Done (2026-04-17)",
            "1. **Heterotopia 概念 + aliases** — 新 dim concept",
            "2. **Theme-dot hardening** — 防誤觸"
        ]
        let items = strategy.parse(lines: lines, sourcePath: dummyURL)

        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].status, .done)
        XCTAssertEqual(items[0].title, "Heterotopia 概念 + aliases")
        XCTAssertEqual(items[0].body, "新 dim concept")
        XCTAssertEqual(items[0].sectionHeading, "Recently Done (2026-04-17)")
        XCTAssertEqual(items[1].status, .done)
        XCTAssertEqual(items[1].title, "Theme-dot hardening")
        XCTAssertEqual(items[1].body, "防誤觸")
        XCTAssertEqual(items[1].sectionHeading, "Recently Done (2026-04-17)")
    }

    // MARK: - Case-insensitive heading match

    func testCaseInsensitiveKeywordMatch() {
        let strategy = NumberedSectionStrategy()
        let lines = [
            "## planned work",
            "1. **lowercase heading** still triggers"
        ]
        let items = strategy.parse(lines: lines, sourcePath: dummyURL)

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].status, .todo)
        XCTAssertEqual(items[0].title, "lowercase heading")
        XCTAssertEqual(items[0].body, "still triggers")
        XCTAssertEqual(items[0].sectionHeading, "planned work")
    }

    // MARK: - Heading without keyword is ignored

    func testHeadingWithoutKeywordIgnored() {
        let strategy = NumberedSectionStrategy()
        let lines = [
            "## Random section",
            "1. **not collected** — 因為 heading 無關鍵字",
            "2. **also not collected**"
        ]
        let items = strategy.parse(lines: lines, sourcePath: dummyURL)

        XCTAssertEqual(items, [])
    }

    // MARK: - Plain numbered (no bold)

    func testPlainNumberedNoBoldTitle() {
        let strategy = NumberedSectionStrategy()
        let lines = [
            "### TODO",
            "1. plain numbered item without bold"
        ]
        let items = strategy.parse(lines: lines, sourcePath: dummyURL)

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].status, .todo)
        XCTAssertEqual(items[0].title, "plain numbered item without bold")
        XCTAssertNil(items[0].body)
    }

    // MARK: - Bold-only with continuation body

    func testBoldOnlyNoSeparator() {
        let strategy = NumberedSectionStrategy()
        let lines = [
            "### URGENT",
            "1. **bold title only**",
            "   continuation indented body line",
            "   another body line"
        ]
        let items = strategy.parse(lines: lines, sourcePath: dummyURL)

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].title, "bold title only")
        XCTAssertEqual(items[0].body, "continuation indented body line\nanother body line")
    }

    // MARK: - Bold + separator + indented body

    func testBoldWithSeparatorAndIndentedBody() {
        let strategy = NumberedSectionStrategy()
        let lines = [
            "### URGENT",
            "1. **bold title** — inline body part",
            "   indented continuation"
        ]
        let items = strategy.parse(lines: lines, sourcePath: dummyURL)

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].title, "bold title")
        XCTAssertNotNil(items[0].body)
        let body = items[0].body ?? ""
        XCTAssertTrue(body.contains("inline body part"), "body should contain inline part: \(body)")
        XCTAssertTrue(body.contains("indented continuation"), "body should contain indented continuation: \(body)")
        XCTAssertEqual(items[0].body, "inline body part\nindented continuation")
    }

    // MARK: - Heterotopias-fixture-like content (sanity check)

    func testHeterotopiasFixtureLikeContent() {
        let strategy = NumberedSectionStrategy()
        let lines = [
            "### URGENT(schema coherence — 2026-04-22 audit follow-up)",
            "",
            "0. **P0-1 Curation + Books bilingual schema drift**(~3 hrs;Design 待討論,不可直接動手)",
            "   前台 `/curation/[slug]`、`CurationTabs`、`/academic/book/[slug]` 讀 `ex.venue` / `book.description` 永遠 `undefined`",
            "",
            "### HIGH",
            "1. **Homepage hero 再推進** — 04-14 的 cold-start / hero moment 已上"
        ]
        let items = strategy.parse(lines: lines, sourcePath: dummyURL)

        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].status, .todo)
        XCTAssertEqual(items[0].title, "P0-1 Curation + Books bilingual schema drift")
        XCTAssertEqual(items[1].status, .todo)
        XCTAssertEqual(items[1].title, "Homepage hero 再推進")
    }

    // MARK: - Section transition stops collection

    func testSectionTransitionStopsCollection() {
        let strategy = NumberedSectionStrategy()
        let lines = [
            "### URGENT",
            "1. **collected todo** — body",
            "## Random section",
            "2. **not collected** — heading changed away from trigger"
        ]
        let items = strategy.parse(lines: lines, sourcePath: dummyURL)

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].title, "collected todo")
        XCTAssertEqual(items[0].body, "body")
    }

    // MARK: - Empty input

    func testEmptyInputReturnsEmpty() {
        let strategy = NumberedSectionStrategy()
        let items = strategy.parse(lines: [], sourcePath: dummyURL)

        XCTAssertEqual(items, [])
    }
}
