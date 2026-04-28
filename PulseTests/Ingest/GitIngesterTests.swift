import XCTest
@testable import Pulse

final class GitIngesterTests: XCTestCase {

    // MARK: - Helpers

    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let base = FileManager.default.temporaryDirectory
        tempDir = base.appendingPathComponent("GitIngesterTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir, FileManager.default.fileExists(atPath: tempDir.path) {
            try? FileManager.default.removeItem(at: tempDir)
        }
        tempDir = nil
        try super.tearDownWithError()
    }

    /// Run `cmd` via `/bin/sh -c` inside `dir`. Throws if non-zero exit.
    private func runShell(_ cmd: String, in dir: URL) throws {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = ["-c", cmd]
        p.currentDirectoryURL = dir
        p.standardOutput = Pipe()
        p.standardError = Pipe()
        try p.run()
        p.waitUntilExit()
        if p.terminationStatus != 0 {
            throw NSError(domain: "shell", code: Int(p.terminationStatus),
                          userInfo: [NSLocalizedDescriptionKey: "shell command failed: \(cmd)"])
        }
    }

    /// Initialise a deterministic git repo in `dir` (no commits).
    private func gitInit(in dir: URL) throws {
        try runShell("git init -q -b main", in: dir)
        try runShell("git config user.email test@test.com", in: dir)
        try runShell("git config user.name test", in: dir)
        try runShell("git config commit.gpgsign false", in: dir)
    }

    /// Create a commit with subject `subject` (creates a fresh file each time).
    private func commit(_ subject: String, in dir: URL) throws {
        // Use a UUID to guarantee the file path is unique per commit.
        let f = "f-\(UUID().uuidString).txt"
        // Escape single quotes in subject defensively.
        let escapedSubject = subject.replacingOccurrences(of: "'", with: "'\\''")
        try runShell("touch \(f) && git add \(f) && git commit -q -m '\(escapedSubject)'", in: dir)
    }

    private func makeSource(path: URL) -> Source {
        Source(kind: .gitLog, path: path, label: path.lastPathComponent)
    }

    // MARK: - 1. Two feat commits → 2 cards, both .done with [dirname, "feat"] tags

    func testFetchOnTempRepoWithFeatCommits() async throws {
        try gitInit(in: tempDir)
        try commit("feat: x", in: tempDir)
        try commit("feat: y", in: tempDir)

        let ingester = GitIngester(enabledTypes: ["feat"])
        let cards = try await ingester.fetch(source: makeSource(path: tempDir))

        XCTAssertEqual(cards.count, 2, "two feat commits → 2 cards; got \(cards.count)")
        let dirName = tempDir.lastPathComponent
        for card in cards {
            XCTAssertEqual(card.status, .done, "git commits emit .done cards")
            XCTAssertTrue(card.tags.contains(dirName),
                          "tags should contain repo dir name '\(dirName)'; got \(card.tags)")
            XCTAssertTrue(card.tags.contains("feat"),
                          "tags should contain commit type 'feat'; got \(card.tags)")
        }
    }

    // MARK: - 2. Recommended preset filters out docs/chore

    func testFetchFiltersOutDocsByDefault() async throws {
        try gitInit(in: tempDir)
        try commit("feat: a", in: tempDir)
        try commit("docs: b", in: tempDir)
        try commit("chore: c", in: tempDir)

        let ingester = GitIngester(enabledTypes: ["feat", "fix", "refactor", "perf"])
        let cards = try await ingester.fetch(source: makeSource(path: tempDir))

        XCTAssertEqual(cards.count, 1, "recommended preset keeps only feat; got \(cards.count)")
        XCTAssertTrue(cards[0].tags.contains("feat"))
        XCTAssertEqual(cards[0].title, "a")
    }

    // MARK: - 3. .all preset accepts all 10 types

    func testFetchAcceptsAllTypesWhenEnabled() async throws {
        try gitInit(in: tempDir)
        try commit("feat: a", in: tempDir)
        try commit("docs: b", in: tempDir)
        try commit("chore: c", in: tempDir)

        let ingester = GitIngester(enabledTypes: GitFilterPreset.all.enabledTypes)
        let cards = try await ingester.fetch(source: makeSource(path: tempDir))

        XCTAssertEqual(cards.count, 3, ".all preset keeps all three; got \(cards.count)")
    }

    // MARK: - 4. Non-git directory throws .failed(_, stderr:)

    func testFetchOnNonGitDirectoryThrows() async {
        let ingester = GitIngester(enabledTypes: ["feat"])
        do {
            _ = try await ingester.fetch(source: makeSource(path: tempDir))
            XCTFail("expected fetch to throw on non-git dir")
        } catch let err as GitLogError {
            switch err {
            case .failed(let code, let stderr):
                XCTAssertNotEqual(code, 0, "expected non-zero exit code")
                XCTAssertTrue(stderr.lowercased().contains("not a git repository"),
                              "stderr should mention 'not a git repository'; got: \(stderr)")
            case .gitNotFound:
                XCTFail("expected .failed but got .gitNotFound")
            }
        } catch {
            XCTFail("expected GitLogError, got \(error)")
        }
    }

    // MARK: - 5. Empty repo (init only, no commits) → []

    func testFetchOnEmptyRepoReturnsEmpty() async throws {
        try gitInit(in: tempDir)

        let ingester = GitIngester(enabledTypes: ["feat"])
        let cards = try await ingester.fetch(source: makeSource(path: tempDir))

        XCTAssertEqual(cards, [], "no commits → no cards")
    }

    // MARK: - 6. repoLabel (tag) comes from path.lastPathComponent

    func testRepoLabelComesFromDirName() async throws {
        // Build a nested path whose last component has a recognisable name.
        let nested = tempDir.appendingPathComponent("my-special-repo")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try gitInit(in: nested)
        try commit("feat: x", in: nested)

        let ingester = GitIngester(enabledTypes: ["feat"])
        let cards = try await ingester.fetch(source: makeSource(path: nested))

        XCTAssertEqual(cards.count, 1)
        XCTAssertTrue(cards[0].tags.contains("my-special-repo"),
                      "tags should contain dir name 'my-special-repo'; got \(cards[0].tags)")
    }
}
