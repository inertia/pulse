import XCTest
@testable import Pulse

final class ConventionalCommitsParserTests: XCTestCase {

    // MARK: - Helpers

    /// Build raw `git log` output from (sha, dateStr, subject, body) tuples.
    /// Fields separated by tab, records by U+001E.
    private func makeStdout(_ records: [(sha: String, date: String, subject: String, body: String)]) -> String {
        records
            .map { "\($0.sha)\t\($0.date)\t\($0.subject)\t\($0.body)" }
            .joined(separator: "\u{1e}")
            + "\u{1e}"
    }

    private static let sourceId = UUID()
    private static let allTypes: Set<String> = [
        "feat", "fix", "refactor", "perf", "chore",
        "docs", "build", "ci", "style", "test",
    ]
    private static let codeTypes: Set<String> = ["feat", "fix", "refactor", "perf"]

    // MARK: - 1. Basic feat commit parsed

    func testParsesFeatCommit() {
        let stdout = makeStdout([
            ("abc1234", "2026-04-25T10:00:00+08:00", "feat(rename): file rename", ""),
        ])
        let cards = ConventionalCommitsParser.parse(
            stdout: stdout,
            sourceId: Self.sourceId,
            repoLabel: "my-repo",
            enabledTypes: ["feat"]
        )

        XCTAssertEqual(cards.count, 1)
        let card = cards[0]
        XCTAssertEqual(card.id, "abc1234")
        XCTAssertEqual(card.title, "file rename")
        XCTAssertEqual(card.status, .done)
        XCTAssertEqual(card.sourceRef, "abc1234")
        XCTAssertEqual(card.tags, ["my-repo", "feat"])

        // 2026-04-25T10:00:00+08:00 → 2026-04-25T02:00:00Z
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime]
        XCTAssertEqual(card.completedAt, fmt.date(from: "2026-04-25T02:00:00Z"))
    }

    // MARK: - 2. enabledTypes filters out docs/chore by default

    func testFiltersDocsAndChoreByDefault() {
        let stdout = makeStdout([
            ("a", "2026-04-25T10:00:00+08:00", "feat: real work", ""),
            ("b", "2026-04-24T10:00:00+08:00", "docs: tweak readme", ""),
            ("c", "2026-04-23T10:00:00+08:00", "chore: bump dep", ""),
        ])
        let cards = ConventionalCommitsParser.parse(
            stdout: stdout,
            sourceId: Self.sourceId,
            repoLabel: "r",
            enabledTypes: Self.codeTypes
        )

        XCTAssertEqual(cards.count, 1)
        XCTAssertEqual(cards[0].id, "a")
        XCTAssertEqual(cards[0].title, "real work")
    }

    // MARK: - 3. Non-conventional message dropped

    func testNonConventionalCommitsDropped() {
        let stdout = makeStdout([
            ("ghi9012", "2026-04-23T15:00:00+08:00", "random non-conventional message", ""),
        ])
        let cards = ConventionalCommitsParser.parse(
            stdout: stdout,
            sourceId: Self.sourceId,
            repoLabel: "r",
            enabledTypes: Self.allTypes
        )
        XCTAssertEqual(cards, [])
    }

    // MARK: - 4. Empty input

    func testEmptyInputReturnsEmpty() {
        let cards = ConventionalCommitsParser.parse(
            stdout: "",
            sourceId: Self.sourceId,
            repoLabel: "r",
            enabledTypes: Self.allTypes
        )
        XCTAssertEqual(cards, [])
    }

    // MARK: - 5. Whitespace-only input

    func testWhitespaceOnlyInputReturnsEmpty() {
        let cards = ConventionalCommitsParser.parse(
            stdout: "\n\n",
            sourceId: Self.sourceId,
            repoLabel: "r",
            enabledTypes: Self.allTypes
        )
        XCTAssertEqual(cards, [])
    }

    // MARK: - 6. Scope captured but title excludes scope

    func testCommitWithScopeParsed() {
        let stdout = makeStdout([
            ("sha1", "2026-04-25T10:00:00+08:00", "feat(scope-name): subject", ""),
        ])
        let cards = ConventionalCommitsParser.parse(
            stdout: stdout,
            sourceId: Self.sourceId,
            repoLabel: "r",
            enabledTypes: ["feat"]
        )
        XCTAssertEqual(cards.count, 1)
        XCTAssertEqual(cards[0].title, "subject")
    }

    // MARK: - 7. Body preserved when non-empty

    func testCommitWithBodyPreserved() {
        let stdout = makeStdout([
            ("sha1", "2026-04-25T10:00:00+08:00", "feat: x", "this is the body explanation"),
        ])
        let cards = ConventionalCommitsParser.parse(
            stdout: stdout,
            sourceId: Self.sourceId,
            repoLabel: "r",
            enabledTypes: ["feat"]
        )
        XCTAssertEqual(cards.count, 1)
        XCTAssertEqual(cards[0].body, "this is the body explanation")
    }

    // MARK: - 8. Empty body → nil

    func testCommitWithoutBodyHasNilBody() {
        let stdout = makeStdout([
            ("sha1", "2026-04-25T10:00:00+08:00", "feat: x", ""),
        ])
        let cards = ConventionalCommitsParser.parse(
            stdout: stdout,
            sourceId: Self.sourceId,
            repoLabel: "r",
            enabledTypes: ["feat"]
        )
        XCTAssertEqual(cards.count, 1)
        XCTAssertNil(cards[0].body)
    }

    // MARK: - 9. Empty repoLabel drops from tags

    func testRepoLabelEmptyDropsFromTags() {
        let stdout = makeStdout([
            ("sha1", "2026-04-25T10:00:00+08:00", "feat: x", ""),
        ])
        let cards = ConventionalCommitsParser.parse(
            stdout: stdout,
            sourceId: Self.sourceId,
            repoLabel: "",
            enabledTypes: ["feat"]
        )
        XCTAssertEqual(cards.count, 1)
        XCTAssertEqual(cards[0].tags, ["feat"])
    }

    // MARK: - 10. All ten types accepted

    func testAllTenTypesAccepted() {
        let types = ["feat", "fix", "refactor", "perf", "chore",
                     "docs", "build", "ci", "style", "test"]
        let records = types.enumerated().map { (idx, t) in
            (sha: "sha\(idx)",
             date: "2026-04-25T10:00:00+08:00",
             subject: "\(t): subject for \(t)",
             body: "")
        }
        let stdout = makeStdout(records)
        let cards = ConventionalCommitsParser.parse(
            stdout: stdout,
            sourceId: Self.sourceId,
            repoLabel: "r",
            enabledTypes: Self.allTypes
        )
        XCTAssertEqual(cards.count, 10)

        // Verify each type appears once in the resulting tags
        let typesFromTags = cards.compactMap { $0.tags.last }.sorted()
        XCTAssertEqual(typesFromTags, types.sorted())
    }
}
