import XCTest
@testable import Pulse

final class SectionHeadingStrategyTests: XCTestCase {

    private let dummyURL = URL(fileURLWithPath: "/tmp/notes.md")

    // MARK: - V1 spec example (canonical fixture from spec §4.1)

    func testV1SpecExample() {
        let strategy = SectionHeadingStrategy()
        let lines = [
            "## To Do",
            "- 重建破報資料庫網站",
            "- admin server 端計畫",
            "",
            "## Done",
            "- 新大眾文藝知識庫架構（2026-02-28）"
        ]
        let items = strategy.parse(lines: lines, sourcePath: dummyURL)

        XCTAssertEqual(items.count, 3)

        XCTAssertEqual(items[0].title, "重建破報資料庫網站")
        XCTAssertEqual(items[0].status, .todo)
        XCTAssertEqual(items[0].sectionHeading, "To Do")
        XCTAssertEqual(items[0].lineNumber, 2)

        XCTAssertEqual(items[1].title, "admin server 端計畫")
        XCTAssertEqual(items[1].status, .todo)
        XCTAssertEqual(items[1].sectionHeading, "To Do")
        XCTAssertEqual(items[1].lineNumber, 3)

        XCTAssertEqual(items[2].title, "新大眾文藝知識庫架構（2026-02-28）")
        XCTAssertEqual(items[2].status, .done)
        XCTAssertEqual(items[2].sectionHeading, "Done")
        XCTAssertEqual(items[2].lineNumber, 6)
    }

    // MARK: - Case-insensitive exact match

    func testCaseInsensitiveExactMatch() {
        let strategy = SectionHeadingStrategy()
        let lines = [
            "## todo",
            "- lowercase heading match",
            "## done",
            "- 已完成 item"
        ]
        let items = strategy.parse(lines: lines, sourcePath: dummyURL)

        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].title, "lowercase heading match")
        XCTAssertEqual(items[0].status, .todo)
        XCTAssertEqual(items[1].title, "已完成 item")
        XCTAssertEqual(items[1].status, .done)
    }

    // MARK: - Non-trigger heading ignored

    func testNonTriggerHeadingIgnored() {
        let strategy = SectionHeadingStrategy()
        let lines = [
            "## Random Section",
            "- not collected",
            "## My Notes",
            "- also not collected"
        ]
        let items = strategy.parse(lines: lines, sourcePath: dummyURL)

        XCTAssertEqual(items, [])
    }

    // MARK: - Orthogonality with other strategies

    func testCheckboxBulletsSkipped() {
        let strategy = SectionHeadingStrategy()
        let lines = [
            "## To Do",
            "- [ ] checkbox style",
            "- plain bullet"
        ]
        let items = strategy.parse(lines: lines, sourcePath: dummyURL)

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].title, "plain bullet")
        XCTAssertEqual(items[0].status, .todo)
    }

    func testEmojiCheckmarkBulletsSkipped() {
        let strategy = SectionHeadingStrategy()
        let lines = [
            "## Done",
            "- ✅ emoji style",
            "- plain done item"
        ]
        let items = strategy.parse(lines: lines, sourcePath: dummyURL)

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].title, "plain done item")
        XCTAssertEqual(items[0].status, .done)
    }

    func testInProgressMarkBulletsSkipped() {
        let strategy = SectionHeadingStrategy()
        let lines = [
            "## Done",
            "- ⏳ in progress",
            "- ❌ cancelled",
            "- plain done item"
        ]
        let items = strategy.parse(lines: lines, sourcePath: dummyURL)

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].title, "plain done item")
        XCTAssertEqual(items[0].status, .done)
    }

    func testNumberedItemsSkipped() {
        let strategy = SectionHeadingStrategy()
        let lines = [
            "## Planned Work",
            "1. **numbered with bold** — body",
            "- plain dash bullet"
        ]
        let items = strategy.parse(lines: lines, sourcePath: dummyURL)

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].title, "plain dash bullet")
        XCTAssertEqual(items[0].status, .todo)
    }

    // MARK: - Sub-bullet body

    func testSubBulletBecomesBody() {
        let strategy = SectionHeadingStrategy()
        let lines = [
            "## To Do",
            "- main task",
            "  - sub-detail line 1",
            "  - sub-detail line 2"
        ]
        let items = strategy.parse(lines: lines, sourcePath: dummyURL)

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].title, "main task")
        XCTAssertEqual(items[0].body, "- sub-detail line 1\n- sub-detail line 2")
    }

    // MARK: - Substring vs full match (NumberedSectionStrategy territory)

    func testSubstringHeadingDoesNotMatch() {
        let strategy = SectionHeadingStrategy()
        let lines = [
            "### URGENT (To Do for next week)",
            "- not collected"
        ]
        let items = strategy.parse(lines: lines, sourcePath: dummyURL)

        XCTAssertEqual(items, [])
    }

    // MARK: - Section transition

    func testSectionTransitionStopsCollection() {
        let strategy = SectionHeadingStrategy()
        let lines = [
            "## To Do",
            "- collected",
            "## Random",
            "- not collected"
        ]
        let items = strategy.parse(lines: lines, sourcePath: dummyURL)

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].title, "collected")
        XCTAssertEqual(items[0].status, .todo)
    }
}
