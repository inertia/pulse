import XCTest
@testable import Pulse

final class CheckboxStrategyTests: XCTestCase {

    private let dummyURL = URL(fileURLWithPath: "/tmp/notes.md")

    // MARK: - Status parsing

    func testTodoCheckbox() {
        let strategy = CheckboxStrategy()
        let items = strategy.parse(lines: ["- [ ] foo"], sourcePath: dummyURL)

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].status, .todo)
        XCTAssertEqual(items[0].title, "foo")
        XCTAssertEqual(items[0].lineNumber, 1)
    }

    func testDoneCheckboxLowercase() {
        let strategy = CheckboxStrategy()
        let items = strategy.parse(lines: ["- [x] bar"], sourcePath: dummyURL)

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].status, .done)
        XCTAssertEqual(items[0].title, "bar")
    }

    func testDoneCheckboxUppercase() {
        let strategy = CheckboxStrategy()
        let items = strategy.parse(lines: ["- [X] BAR"], sourcePath: dummyURL)

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].status, .done)
        XCTAssertEqual(items[0].title, "BAR")
    }

    // MARK: - Skipping non-checkbox lines

    func testNoCheckboxIsSkipped() {
        let strategy = CheckboxStrategy()

        let regular = strategy.parse(lines: ["- regular bullet"], sourcePath: dummyURL)
        XCTAssertEqual(regular, [])

        let plain = strategy.parse(lines: ["plain text"], sourcePath: dummyURL)
        XCTAssertEqual(plain, [])
    }

    // MARK: - Section heading tracking

    func testSectionHeadingTracked() {
        let strategy = CheckboxStrategy()
        let lines = [
            "## To Do",
            "- [ ] first",
            "## Done",
            "- [x] second"
        ]
        let items = strategy.parse(lines: lines, sourcePath: dummyURL)

        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].title, "first")
        XCTAssertEqual(items[0].sectionHeading, "To Do")
        XCTAssertEqual(items[0].lineNumber, 2)
        XCTAssertEqual(items[1].title, "second")
        XCTAssertEqual(items[1].sectionHeading, "Done")
        XCTAssertEqual(items[1].lineNumber, 4)
    }

    // MARK: - Sub-bullet body

    func testSubBulletBecomesBody() {
        let strategy = CheckboxStrategy()
        let lines = [
            "- [ ] main task",
            "  - sub-detail line 1",
            "  - sub-detail line 2"
        ]
        let items = strategy.parse(lines: lines, sourcePath: dummyURL)

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].title, "main task")
        XCTAssertEqual(items[0].body, "- sub-detail line 1\n- sub-detail line 2")
    }

    // MARK: - Edge cases

    func testEmptyInputReturnsEmpty() {
        let strategy = CheckboxStrategy()
        let items = strategy.parse(lines: [], sourcePath: dummyURL)

        XCTAssertEqual(items, [])
    }

    func testFieldsPopulatedByParserAreEmptyHere() {
        let strategy = CheckboxStrategy()
        let items = strategy.parse(
            lines: ["- [ ] task with @2026-05-01 #urgent #work"],
            sourcePath: dummyURL
        )

        XCTAssertEqual(items.count, 1)
        // Strategy must NOT normalize: dates / tags stay in title; composition fields stay empty.
        XCTAssertNil(items[0].dueDate)
        XCTAssertNil(items[0].completedAt)
        XCTAssertTrue(items[0].tags.isEmpty)
        XCTAssertEqual(
            items[0].title,
            "task with @2026-05-01 #urgent #work",
            "strategy must preserve raw title — normalization happens in parser composition (Task 14)"
        )
    }
}
