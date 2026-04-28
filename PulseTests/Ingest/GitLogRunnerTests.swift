import XCTest
@testable import Pulse

final class GitLogRunnerTests: XCTestCase {

    // MARK: - Helpers

    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let base = FileManager.default.temporaryDirectory
        tempDir = base.appendingPathComponent("GitLogRunnerTests-\(UUID().uuidString)")
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
        // Suppress git's chatter so test output stays readable.
        p.standardOutput = Pipe()
        p.standardError = Pipe()
        try p.run()
        p.waitUntilExit()
        if p.terminationStatus != 0 {
            throw NSError(domain: "shell", code: Int(p.terminationStatus),
                          userInfo: [NSLocalizedDescriptionKey: "shell command failed: \(cmd)"])
        }
    }

    /// Initialise a git repo in `dir` with deterministic identity, then create
    /// `count` commits whose subjects are `feat: commit-N` (1-indexed).
    private func initRepoWithCommits(_ count: Int, in dir: URL) throws {
        try runShell("git init -q -b main", in: dir)
        try runShell("git config user.email test@test.com", in: dir)
        try runShell("git config user.name test", in: dir)
        try runShell("git config commit.gpgsign false", in: dir)
        for i in 1...count {
            try runShell("touch f\(i) && git add f\(i) && git commit -q -m 'feat: commit-\(i)'", in: dir)
        }
    }

    // MARK: - 1. resolveGitPath finds a system git

    func testResolveGitPathFindsSystemGit() {
        let path = GitLogRunner.resolveGitPath()
        XCTAssertNotNil(path, "expected to find a git binary on the test runner")
        if let path {
            XCTAssertTrue(path.hasSuffix("/git"), "resolved path should end in /git, got \(path)")
            XCTAssertTrue(FileManager.default.isExecutableFile(atPath: path),
                          "resolved path should be executable")
        }
    }

    // MARK: - 2. run() on a temp repo with 3 commits returns 3 records

    func testRunOnTempRepoWith3Commits() throws {
        try initRepoWithCommits(3, in: tempDir)

        let stdout = try GitLogRunner.run(at: tempDir)

        // Split on the U+001E record separator and drop empty trailing chunk.
        let records = stdout.components(separatedBy: "\u{1e}").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        XCTAssertEqual(records.count, 3, "expected 3 commit records, got \(records.count); stdout=\(stdout)")

        let shaPattern = try NSRegularExpression(pattern: "^[0-9a-f]{40}\t")
        for rec in records {
            let trimmed = rec.trimmingCharacters(in: .whitespacesAndNewlines)
            let range = NSRange(location: 0, length: (trimmed as NSString).length)
            XCTAssertNotNil(shaPattern.firstMatch(in: trimmed, range: range),
                            "record should start with a 40-hex SHA + tab; got: \(trimmed)")
            XCTAssertTrue(trimmed.contains("\tfeat: commit-"),
                          "record should contain a feat: subject; got: \(trimmed)")
        }
    }

    // MARK: - 3. run() on a non-git directory throws .failed with stderr

    func testRunOnNonGitDirectoryThrows() {
        XCTAssertThrowsError(try GitLogRunner.run(at: tempDir)) { error in
            guard let gitErr = error as? GitLogError else {
                return XCTFail("expected GitLogError, got \(error)")
            }
            switch gitErr {
            case .failed(let code, let stderr):
                XCTAssertNotEqual(code, 0, "expected non-zero exit code")
                XCTAssertTrue(stderr.lowercased().contains("not a git repository"),
                              "stderr should mention 'not a git repository'; got: \(stderr)")
            case .gitNotFound:
                XCTFail("expected .failed but got .gitNotFound")
            }
        }
    }

    // MARK: - 4. limit argument is forwarded to git

    func testRunPassesLimitToGit() throws {
        try initRepoWithCommits(5, in: tempDir)

        let stdout = try GitLogRunner.run(at: tempDir, limit: 2)
        let records = stdout.components(separatedBy: "\u{1e}").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        XCTAssertEqual(records.count, 2, "limit=2 should return exactly 2 records; got \(records.count)")
    }

    // MARK: - 5. candidatePaths constant order is stable

    func testCandidatePathOrdering() {
        XCTAssertEqual(GitLogRunner.candidatePaths,
                       ["/usr/bin/git", "/opt/homebrew/bin/git", "/usr/local/bin/git"],
                       "candidatePaths must stay in system → arm Homebrew → x86 Homebrew order")
    }
}
