import XCTest
@testable import Pulse

final class CardTests: XCTestCase {

    // MARK: - makeId stability & determinism

    func testMakeIdStableForSameInputs() {
        let h1 = Card.makeId(
            path: "/tmp/project/CLAUDE.md",
            sectionHeading: "## Todo",
            normalizedTitle: "ship pulse v0.1"
        )
        let h2 = Card.makeId(
            path: "/tmp/project/CLAUDE.md",
            sectionHeading: "## Todo",
            normalizedTitle: "ship pulse v0.1"
        )

        XCTAssertEqual(h1, h2, "same inputs must yield same hash")
    }

    // MARK: - makeId sensitivity to each component

    func testMakeIdDiffersForDifferentPath() {
        let h1 = Card.makeId(
            path: "/tmp/a/CLAUDE.md",
            sectionHeading: "## Todo",
            normalizedTitle: "ship pulse v0.1"
        )
        let h2 = Card.makeId(
            path: "/tmp/b/CLAUDE.md",
            sectionHeading: "## Todo",
            normalizedTitle: "ship pulse v0.1"
        )

        XCTAssertNotEqual(h1, h2, "different path must yield different hash")
    }

    func testMakeIdDiffersForDifferentHeading() {
        let h1 = Card.makeId(
            path: "/tmp/project/CLAUDE.md",
            sectionHeading: "## Todo",
            normalizedTitle: "ship pulse v0.1"
        )
        let h2 = Card.makeId(
            path: "/tmp/project/CLAUDE.md",
            sectionHeading: "## Done",
            normalizedTitle: "ship pulse v0.1"
        )

        XCTAssertNotEqual(h1, h2, "different heading must yield different hash")
    }

    func testMakeIdDiffersForDifferentTitle() {
        let h1 = Card.makeId(
            path: "/tmp/project/CLAUDE.md",
            sectionHeading: "## Todo",
            normalizedTitle: "ship pulse v0.1"
        )
        let h2 = Card.makeId(
            path: "/tmp/project/CLAUDE.md",
            sectionHeading: "## Todo",
            normalizedTitle: "ship pulse v0.2"
        )

        XCTAssertNotEqual(h1, h2, "different title must yield different hash")
    }

    // MARK: - makeId format

    func testMakeIdReturnsExactly16HexChars() {
        let h = Card.makeId(
            path: "/tmp/project/CLAUDE.md",
            sectionHeading: "## Todo",
            normalizedTitle: "ship pulse v0.1"
        )

        XCTAssertEqual(h.count, 16, "hash must be exactly 16 chars")

        let hexPattern = "^[0-9a-f]{16}$"
        let regex = try! NSRegularExpression(pattern: hexPattern)
        let range = NSRange(h.startIndex..<h.endIndex, in: h)
        XCTAssertNotNil(
            regex.firstMatch(in: h, options: [], range: range),
            "hash must be lowercase hex only, got \(h)"
        )
    }

    // MARK: - Regression: lineNumber drift must NOT change identity

    /// Reviewer-driven regression test. The original spec hashed `lineNumber`,
    /// which meant inserting a blank line above a todo would shift every
    /// subsequent card's id and invalidate the cache. This test ensures
    /// `makeId` does NOT consider line position — only content keys.
    func testLineNumberDriftRegression() {
        // Card lives at line 10 in version A of the file.
        let idAtLine10 = Card.makeId(
            path: "/notes/CLAUDE.md",
            sectionHeading: "## Pending",
            normalizedTitle: "review pulse spec"
        )

        // User inserts 5 blank lines above. Same card now lives at line 15.
        // Path, heading, and normalized title are identical.
        let idAtLine15 = Card.makeId(
            path: "/notes/CLAUDE.md",
            sectionHeading: "## Pending",
            normalizedTitle: "review pulse spec"
        )

        XCTAssertEqual(
            idAtLine10, idAtLine15,
            "lineNumber drift must NOT change card identity (only path + heading + normalized title)"
        )
    }

    // MARK: - Card Codable round-trip

    func testCardCodableRoundTrip() throws {
        let due = Date(timeIntervalSince1970: 1_800_000_000) // 2027-01-15-ish
        let completed = Date(timeIntervalSince1970: 1_750_000_000)
        let sourceId = UUID(uuidString: "550E8400-E29B-41D4-A716-446655440000")!

        let original = Card(
            id: Card.makeId(
                path: "/notes/CLAUDE.md",
                sectionHeading: "## Todo",
                normalizedTitle: "ship pulse"
            ),
            sourceId: sourceId,
            title: "ship pulse",
            body: "context goes here\nsecond line",
            status: .done,
            dueDate: due,
            completedAt: completed,
            sourceRef: "/notes/CLAUDE.md:42",
            tags: ["pulse", "core"]
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Card.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.sourceId, original.sourceId)
        XCTAssertEqual(decoded.title, original.title)
        XCTAssertEqual(decoded.body, original.body)
        XCTAssertEqual(decoded.status, original.status)
        XCTAssertEqual(decoded.dueDate, original.dueDate)
        XCTAssertEqual(decoded.completedAt, original.completedAt)
        XCTAssertEqual(decoded.sourceRef, original.sourceRef)
        XCTAssertEqual(decoded.tags, original.tags)
        XCTAssertEqual(decoded, original, "full Equatable round-trip")
    }
}
