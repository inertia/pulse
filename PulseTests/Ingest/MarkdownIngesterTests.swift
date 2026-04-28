import XCTest
@testable import Pulse

final class MarkdownIngesterTests: XCTestCase {

    // MARK: - Tempdir helper

    /// Create a unique tempdir; caller writes whatever it needs inside.
    private func makeTempDir() throws -> URL {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("PulseTests-MarkdownIngester-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func writeFile(_ content: String, named name: String, in dir: URL) throws -> URL {
        let url = dir.appendingPathComponent(name)
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // Standard fixture: 2 todos under ## To Do, 1 done under ## Done = 3 cards.
    private static let sampleMarkdown = """
    ## To Do

    - [ ] task1
    - [ ] task2

    ## Done

    - [x] done1
    """

    // MARK: - 1. Existing markdown file → cards

    func testFetchOnExistingMarkdownFile() async throws {
        let dir = try makeTempDir()
        let path = try writeFile(Self.sampleMarkdown, named: "CLAUDE.md", in: dir)
        let source = Source(kind: .claudeMd, path: path, label: "test")

        let ingester = MarkdownIngester()
        let cards = try await ingester.fetch(source: source)

        XCTAssertEqual(cards.count, 3, "2 todos + 1 done = 3 cards")
        XCTAssertEqual(cards.filter { $0.status == .todo }.count, 2)
        XCTAssertEqual(cards.filter { $0.status == .done }.count, 1)
    }

    // MARK: - 2. Missing file → [] (no throw)

    func testFetchOnMissingFileReturnsEmpty() async throws {
        let dir = try makeTempDir()
        let missingPath = dir.appendingPathComponent("does-not-exist.md")
        let source = Source(kind: .claudeMd, path: missingPath, label: "missing")

        let ingester = MarkdownIngester()
        let cards = try await ingester.fetch(source: source)

        XCTAssertEqual(cards, [], "missing path must return [] gracefully, not throw")
    }

    // MARK: - 3. AGENTS.md kind — same parser, same result

    func testFetchHandlesAgentsMd() async throws {
        let dir = try makeTempDir()
        let path = try writeFile(Self.sampleMarkdown, named: "AGENTS.md", in: dir)
        let source = Source(kind: .agentsMd, path: path, label: "agents")

        let cards = try await MarkdownIngester().fetch(source: source)

        XCTAssertEqual(cards.count, 3, "agentsMd kind uses same parser; 3 cards")
    }

    // MARK: - 4. GEMINI.md kind — same parser, same result

    func testFetchHandlesGeminiMd() async throws {
        let dir = try makeTempDir()
        let path = try writeFile(Self.sampleMarkdown, named: "GEMINI.md", in: dir)
        let source = Source(kind: .geminiMd, path: path, label: "gemini")

        let cards = try await MarkdownIngester().fetch(source: source)

        XCTAssertEqual(cards.count, 3, "geminiMd kind uses same parser; 3 cards")
    }

    // MARK: - 5. Source.id propagated to every Card

    func testFetchPreservesSourceId() async throws {
        let dir = try makeTempDir()
        let path = try writeFile(Self.sampleMarkdown, named: "CLAUDE.md", in: dir)
        let fixedId = UUID()
        let source = Source(id: fixedId, kind: .claudeMd, path: path, label: "preserve-id")

        let cards = try await MarkdownIngester().fetch(source: source)

        XCTAssertFalse(cards.isEmpty)
        for card in cards {
            XCTAssertEqual(card.sourceId, fixedId, "every card must carry source.id")
        }
    }

    // MARK: - 6. Empty file → [] (no throw)

    func testFetchEmptyFileReturnsEmpty() async throws {
        let dir = try makeTempDir()
        let path = try writeFile("", named: "CLAUDE.md", in: dir)
        let source = Source(kind: .claudeMd, path: path, label: "empty")

        let cards = try await MarkdownIngester().fetch(source: source)

        XCTAssertEqual(cards, [], "empty file → no cards, no throw")
    }
}
