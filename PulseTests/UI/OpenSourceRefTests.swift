import XCTest
@testable import Pulse

final class OpenSourceRefTests: XCTestCase {

    // MARK: - Helpers

    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let base = FileManager.default.temporaryDirectory
        tempDir = base.appendingPathComponent("OpenSourceRefTests-\(UUID().uuidString)")
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

    /// `git init` with deterministic identity, no signing.
    private func initRepo(in dir: URL) throws {
        try runShell("git init -q -b main", in: dir)
        try runShell("git config user.email test@test.com", in: dir)
        try runShell("git config user.name test", in: dir)
        try runShell("git config commit.gpgsign false", in: dir)
    }

    // MARK: - 1. parseGitHubOrigin: SSH form

    func testParseSshGitHubOrigin() {
        let a = OpenSourceRef.parseGitHubOrigin("git@github.com:owner/repo.git")
        XCTAssertEqual(a?.owner, "owner")
        XCTAssertEqual(a?.repo, "repo")

        let b = OpenSourceRef.parseGitHubOrigin("git@github.com:my-org/my-app")
        XCTAssertEqual(b?.owner, "my-org")
        XCTAssertEqual(b?.repo, "my-app")
    }

    // MARK: - 2. parseGitHubOrigin: HTTPS form

    func testParseHttpsGitHubOrigin() {
        let a = OpenSourceRef.parseGitHubOrigin("https://github.com/owner/repo.git")
        XCTAssertEqual(a?.owner, "owner")
        XCTAssertEqual(a?.repo, "repo")

        let b = OpenSourceRef.parseGitHubOrigin("https://github.com/my-org/my-app")
        XCTAssertEqual(b?.owner, "my-org")
        XCTAssertEqual(b?.repo, "my-app")
    }

    // MARK: - 3. parseGitHubOrigin: non-GitHub returns nil

    func testParseNonGitHubReturnsNil() {
        XCTAssertNil(OpenSourceRef.parseGitHubOrigin("git@gitlab.com:foo/bar.git"))
        XCTAssertNil(OpenSourceRef.parseGitHubOrigin("https://bitbucket.org/foo/bar.git"))
        XCTAssertNil(OpenSourceRef.parseGitHubOrigin("just garbage"))
    }

    // MARK: - 4. parseGitHubOrigin: empty / invalid returns nil

    func testParseEmptyOrInvalidReturnsNil() {
        XCTAssertNil(OpenSourceRef.parseGitHubOrigin(""))
        XCTAssertNil(OpenSourceRef.parseGitHubOrigin("https://github.com/onlyowner"))
        XCTAssertNil(OpenSourceRef.parseGitHubOrigin("https://github.com/owner/"))
    }

    // MARK: - 5. readGitOrigin: temp repo with remote

    func testReadGitOriginInTempRepoWithRemote() throws {
        try initRepo(in: tempDir)
        try runShell("git remote add origin git@github.com:test/repo.git", in: tempDir)

        let origin = OpenSourceRef.readGitOrigin(repoPath: tempDir)
        XCTAssertEqual(origin, "git@github.com:test/repo.git")
    }

    // MARK: - 6. readGitOrigin: no remote → nil

    func testReadGitOriginNoRemoteReturnsNil() throws {
        try initRepo(in: tempDir)

        let origin = OpenSourceRef.readGitOrigin(repoPath: tempDir)
        XCTAssertNil(origin, "expected nil when no origin is configured")
    }

    // MARK: - 7. readGitOrigin: not a git directory → nil

    func testReadGitOriginNotGitDirReturnsNil() {
        // tempDir is created by setUp but no git init
        let origin = OpenSourceRef.readGitOrigin(repoPath: tempDir)
        XCTAssertNil(origin, "expected nil when path is not a git repo")
    }

    // MARK: - 8. githubCommitURL: end-to-end

    func testGithubCommitURLEndToEnd() throws {
        try initRepo(in: tempDir)
        try runShell("git remote add origin git@github.com:test/repo.git", in: tempDir)

        let url = OpenSourceRef.githubCommitURL(repoPath: tempDir, sha: "abc123")
        XCTAssertEqual(url?.absoluteString, "https://github.com/test/repo/commit/abc123")
    }

    // MARK: - 9. githubCommitURL: non-GitHub origin → nil

    func testGithubCommitURLNonGitHubReturnsNil() throws {
        try initRepo(in: tempDir)
        try runShell("git remote add origin git@gitlab.com:test/repo.git", in: tempDir)

        let url = OpenSourceRef.githubCommitURL(repoPath: tempDir, sha: "abc123")
        XCTAssertNil(url, "non-GitHub origin should yield nil URL")
    }
}
