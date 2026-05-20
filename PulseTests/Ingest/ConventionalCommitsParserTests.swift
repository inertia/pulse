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

    // MARK: - 11. 全形冒號（中文「：」）接受

    func testFullwidthColonAccepted() {
        let stdout = makeStdout([
            ("sha-fw", "2026-05-20T10:00:00+08:00", "矽盾週報：archive silicon-daily skill + CLAUDE.md 沉澱", ""),
        ])
        let cards = ConventionalCommitsParser.parse(
            stdout: stdout,
            sourceId: Self.sourceId,
            repoLabel: "矽盾週報",
            enabledTypes: ["矽盾週報"]
        )
        XCTAssertEqual(cards.count, 1)
        XCTAssertEqual(cards[0].title, "archive silicon-daily skill + CLAUDE.md 沉澱")
        XCTAssertEqual(cards[0].tags, ["矽盾週報", "矽盾週報"])
    }

    // MARK: - 12. 日常工序 type（daily / papers / audit / skill / pulse / revert）

    func testWorkflowTypesAccepted() {
        let workTypes = ["daily", "papers", "audit", "skill", "pulse", "revert", "wip"]
        let records = workTypes.enumerated().map { (idx, t) in
            (sha: "wsha\(idx)",
             date: "2026-05-20T10:00:00+08:00",
             subject: "\(t): \(t) subject",
             body: "")
        }
        let stdout = makeStdout(records)
        let cards = ConventionalCommitsParser.parse(
            stdout: stdout,
            sourceId: Self.sourceId,
            repoLabel: "r",
            enabledTypes: Set(workTypes)
        )
        XCTAssertEqual(cards.count, workTypes.count)
        let parsedTypes = cards.compactMap { $0.tags.last }.sorted()
        XCTAssertEqual(parsedTypes, workTypes.sorted())
    }

    // MARK: - 13. 中文 repo 前綴 + 全形冒號 + 無空白

    func testChineseRepoPrefixNoSpaceAfterColon() {
        let stdout = makeStdout([
            ("sha-zh", "2026-05-20T10:00:00+08:00", "新大眾文藝：rag_visibility 默認改 full + 5/18 主檔追補", ""),
        ])
        let cards = ConventionalCommitsParser.parse(
            stdout: stdout,
            sourceId: Self.sourceId,
            repoLabel: "新大眾文藝",
            enabledTypes: ["新大眾文藝"]
        )
        XCTAssertEqual(cards.count, 1)
        XCTAssertEqual(cards[0].title, "rag_visibility 默認改 full + 5/18 主檔追補")
    }

    // MARK: - 14. `recommended` preset 涵蓋 daily/papers/audit/skill

    func testRecommendedPresetIncludesWorkflowTypes() {
        let enabled = GitFilterPreset.recommended.enabledTypes
        XCTAssertTrue(enabled.contains("feat"))
        XCTAssertTrue(enabled.contains("daily"))
        XCTAssertTrue(enabled.contains("papers"))
        XCTAssertTrue(enabled.contains("audit"))
        XCTAssertTrue(enabled.contains("skill"))
        // 中文 repo type 與 add 不進 recommended
        XCTAssertFalse(enabled.contains("add"))
        XCTAssertFalse(enabled.contains("矽盾週報"))
    }

    // MARK: - 15. `all` preset 涵蓋中文 repo 前綴與 add

    func testAllPresetIncludesChineseAndAdd() {
        let enabled = GitFilterPreset.all.enabledTypes
        XCTAssertTrue(enabled.contains("add"))
        XCTAssertTrue(enabled.contains("矽盾週報"))
        XCTAssertTrue(enabled.contains("新大眾文藝"))
        XCTAssertTrue(enabled.contains("中國技術道路"))
        XCTAssertTrue(enabled.contains("破週報"))
        XCTAssertTrue(enabled.contains("文化與技術三部曲"))
    }

    // MARK: - 16. 冒號可省（type 後直接空白也認）

    func testColonOptionalSubjectAccepted() {
        // 「中國技術道路 2026-05-20 日報 ...」此處 type 與標題之間只有空白，無冒號。
        let stdout = makeStdout([
            ("sha-nc", "2026-05-20T10:00:00+08:00", "中國技術道路 2026-05-20 日報 + audit + 知識庫補位", ""),
            ("sha-ad", "2026-05-20T11:00:00+08:00", "add 045 期日報 + audit + 知識庫條目（2026-05-19）", ""),
            ("sha-dl", "2026-05-20T12:00:00+08:00", "daily 5/20 B 區：拿掉無全文對位推薦", ""),
        ])
        let cards = ConventionalCommitsParser.parse(
            stdout: stdout,
            sourceId: Self.sourceId,
            repoLabel: "r",
            enabledTypes: ["中國技術道路", "add", "daily"]
        )
        XCTAssertEqual(cards.count, 3)
        XCTAssertEqual(cards[0].title, "2026-05-20 日報 + audit + 知識庫補位")
        XCTAssertEqual(cards[1].title, "045 期日報 + audit + 知識庫條目（2026-05-19）")
        XCTAssertEqual(cards[2].title, "5/20 B 區：拿掉無全文對位推薦")
    }

    // MARK: - 17. 即便冒號可省，純標題（type 不在白名單）仍不認

    func testPureSubjectStillDropped() {
        let stdout = makeStdout([
            ("sha-px", "2026-05-20T10:00:00+08:00", "A-31 Liang & Zhang 2026 MCS 抖音 AI Avatar 升 A 區", ""),
        ])
        let cards = ConventionalCommitsParser.parse(
            stdout: stdout,
            sourceId: Self.sourceId,
            repoLabel: "r",
            enabledTypes: Self.allTypes
        )
        XCTAssertEqual(cards, [])
    }
}
