import XCTest
@testable import Pulse

final class EmojiCheckmarkStrategyTests: XCTestCase {

    private let dummyURL = URL(fileURLWithPath: "/tmp/notes.md")

    // MARK: - Status parsing

    func testCheckmarkParsedAsDone() {
        let strategy = EmojiCheckmarkStrategy()
        let items = strategy.parse(lines: ["- ✅ R2 圖片搬遷"], sourcePath: dummyURL)

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].status, .done)
        XCTAssertEqual(items[0].title, "R2 圖片搬遷")
        XCTAssertEqual(items[0].lineNumber, 1)
    }

    // MARK: - Skipped markers (in-progress / cancelled)

    func testHourglassSkipped() {
        let strategy = EmojiCheckmarkStrategy()
        let items = strategy.parse(lines: ["- ⏳ in progress"], sourcePath: dummyURL)

        XCTAssertEqual(items, [])
    }

    func testCrossSkipped() {
        let strategy = EmojiCheckmarkStrategy()
        let items = strategy.parse(lines: ["- ❌ cancelled"], sourcePath: dummyURL)

        XCTAssertEqual(items, [])
    }

    // MARK: - Skipping non-matching lines

    func testRegularBulletSkipped() {
        let strategy = EmojiCheckmarkStrategy()
        let items = strategy.parse(lines: ["- regular text"], sourcePath: dummyURL)

        XCTAssertEqual(items, [])
    }

    func testCheckboxStyleNotMatched() {
        // This strategy is emoji-only; checkbox lines belong to CheckboxStrategy.
        let strategy = EmojiCheckmarkStrategy()
        let items = strategy.parse(lines: ["- [x] checkbox style"], sourcePath: dummyURL)

        XCTAssertEqual(items, [])
    }

    // MARK: - Section heading tracking

    func testSectionHeadingTracked() {
        let strategy = EmojiCheckmarkStrategy()
        let lines = [
            "### Recently Done (2026-04-17)",
            "- ✅ Heterotopia 概念 + aliases",
            "- ✅ Theme-dot hardening",
            "### URGENT",
            "- ⏳ skipped"
        ]
        let items = strategy.parse(lines: lines, sourcePath: dummyURL)

        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].title, "Heterotopia 概念 + aliases")
        XCTAssertEqual(items[0].sectionHeading, "Recently Done (2026-04-17)")
        XCTAssertEqual(items[0].lineNumber, 2)
        XCTAssertEqual(items[1].title, "Theme-dot hardening")
        XCTAssertEqual(items[1].sectionHeading, "Recently Done (2026-04-17)")
        XCTAssertEqual(items[1].lineNumber, 3)
    }

    // MARK: - Heterotopias-fixture-like raw title preservation

    func testHeterotopiasFixtureLikeContent() {
        let strategy = EmojiCheckmarkStrategy()
        let lines = [
            "### Recently Done (2026-04-17)",
            "- ✅ **Heterotopia 概念 + aliases** — 新 dim concept(空間) + 6 條 alias",
            "- ✅ **Theme-dot hardening** — `type=button` + `preventDefault/stopPropagation`",
            "- ✅ **Archive theme typography** — Noto Serif TC weight 500"
        ]
        let items = strategy.parse(lines: lines, sourcePath: dummyURL)

        XCTAssertEqual(items.count, 3)
        XCTAssertEqual(
            items[0].title,
            "**Heterotopia 概念 + aliases** — 新 dim concept(空間) + 6 條 alias",
            "raw title must preserve **bold**, em-dash, parentheticals — Task 14 normalizes"
        )
        XCTAssertEqual(
            items[1].title,
            "**Theme-dot hardening** — `type=button` + `preventDefault/stopPropagation`"
        )
        XCTAssertEqual(
            items[2].title,
            "**Archive theme typography** — Noto Serif TC weight 500"
        )
        for item in items {
            XCTAssertEqual(item.status, .done)
            XCTAssertEqual(item.sectionHeading, "Recently Done (2026-04-17)")
        }
    }

    // MARK: - Sub-bullet body

    func testSubBulletBecomesBody() {
        let strategy = EmojiCheckmarkStrategy()
        let lines = [
            "- ✅ main task",
            "  - sub-detail line 1",
            "  - sub-detail line 2"
        ]
        let items = strategy.parse(lines: lines, sourcePath: dummyURL)

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].title, "main task")
        XCTAssertEqual(items[0].body, "- sub-detail line 1\n- sub-detail line 2")
    }
}
