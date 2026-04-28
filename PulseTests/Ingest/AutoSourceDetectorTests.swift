import XCTest
@testable import Pulse

final class AutoSourceDetectorTests: XCTestCase {

    // MARK: - Tempdir helpers

    /// Create a unique tempdir; caller builds whatever tree it needs inside.
    private func makeTempDir() throws -> URL {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("PulseTests-AutoSourceDetector-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Build a directory tree from a layout list.
    /// - Entries ending in `/` are created as directories.
    /// - Entries without trailing `/` are created as files (with stub content);
    ///   any missing parent directories are created automatically.
    private func makeProjectStructure(in root: URL, layout: [String]) throws {
        let fm = FileManager.default
        for relativePath in layout {
            let fullPath = root.appendingPathComponent(relativePath)
            if relativePath.hasSuffix("/") {
                try fm.createDirectory(at: fullPath, withIntermediateDirectories: true)
            } else {
                try fm.createDirectory(at: fullPath.deletingLastPathComponent(),
                                       withIntermediateDirectories: true)
                try "stub content".write(to: fullPath, atomically: true, encoding: .utf8)
            }
        }
    }

    // MARK: - 1. Root-level detection (depth 1)

    func testFindsClaudeMdAtRootLevel() async throws {
        let tempdir = try makeTempDir()
        try makeProjectStructure(in: tempdir, layout: [
            "proj-a/CLAUDE.md",
            "proj-b/AGENTS.md",
            "proj-c/random.txt",
        ])
        let detector = AutoSourceDetector(roots: [tempdir], depth: 1)
        let results = await detector.scan()

        XCTAssertEqual(results.count, 2)
        let names = Set(results.map { $0.dir.lastPathComponent })
        XCTAssertEqual(names, ["proj-a", "proj-b"])

        let projA = results.first { $0.dir.lastPathComponent == "proj-a" }
        XCTAssertEqual(projA?.detectedFiles, [.claudeMd])
        let projB = results.first { $0.dir.lastPathComponent == "proj-b" }
        XCTAssertEqual(projB?.detectedFiles, [.agentsMd])
    }

    // MARK: - 2. Multiple files in same dir

    func testFindsMultipleFilesInSameDir() async throws {
        let tempdir = try makeTempDir()
        try makeProjectStructure(in: tempdir, layout: [
            "proj/CLAUDE.md",
            "proj/AGENTS.md",
            "proj/GEMINI.md",
        ])
        let detector = AutoSourceDetector(roots: [tempdir], depth: 1)
        let results = await detector.scan()

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.detectedFiles, [.claudeMd, .agentsMd, .geminiMd])
    }

    // MARK: - 3. Nested at depth 2

    func testNestedAtDepth2() async throws {
        let tempdir = try makeTempDir()
        try makeProjectStructure(in: tempdir, layout: [
            "work/proj-a/CLAUDE.md",
        ])
        let detector = AutoSourceDetector(roots: [tempdir], depth: 2)
        let results = await detector.scan()

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.dir.lastPathComponent, "proj-a")
        XCTAssertEqual(results.first?.detectedFiles, [.claudeMd])
    }

    // MARK: - 4. Beyond depth limit

    func testNotFoundBeyondDepth() async throws {
        let tempdir = try makeTempDir()
        try makeProjectStructure(in: tempdir, layout: [
            "a/b/c/CLAUDE.md", // depth 3 from tempdir
        ])
        let detector = AutoSourceDetector(roots: [tempdir], depth: 2)
        let results = await detector.scan()

        XCTAssertEqual(results.count, 0)
    }

    // MARK: - 5. Skip node_modules

    func testSkipsNodeModules() async throws {
        let tempdir = try makeTempDir()
        try makeProjectStructure(in: tempdir, layout: [
            "proj/node_modules/some-lib/CLAUDE.md",
            "proj/CLAUDE.md",
        ])
        let detector = AutoSourceDetector(roots: [tempdir], depth: 3)
        let results = await detector.scan()

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.dir.lastPathComponent, "proj")
    }

    // MARK: - 6. Skip .git directory

    func testSkipsDotGit() async throws {
        let tempdir = try makeTempDir()
        try makeProjectStructure(in: tempdir, layout: [
            "proj/.git/CLAUDE.md",
            "proj/CLAUDE.md",
        ])
        let detector = AutoSourceDetector(roots: [tempdir], depth: 3)
        let results = await detector.scan()

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.dir.lastPathComponent, "proj")
    }

    // MARK: - 7. isGitRepo true

    func testIsGitRepoTrue() async throws {
        let tempdir = try makeTempDir()
        try makeProjectStructure(in: tempdir, layout: [
            "proj/CLAUDE.md",
            "proj/.git/HEAD",
        ])
        let detector = AutoSourceDetector(roots: [tempdir], depth: 1)
        let results = await detector.scan()

        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results.first?.isGitRepo == true)
    }

    // MARK: - 8. isGitRepo false

    func testIsGitRepoFalse() async throws {
        let tempdir = try makeTempDir()
        try makeProjectStructure(in: tempdir, layout: [
            "proj/CLAUDE.md",
        ])
        let detector = AutoSourceDetector(roots: [tempdir], depth: 1)
        let results = await detector.scan()

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.isGitRepo, false)
    }

    // MARK: - 9. Empty roots

    func testEmptyRootsReturnsEmpty() async throws {
        let detector = AutoSourceDetector(roots: [], depth: 2)
        let results = await detector.scan()
        XCTAssertEqual(results, [])
    }

    // MARK: - 10. Non-existent root

    func testNonExistentRootIgnored() async throws {
        let bogus = URL(fileURLWithPath: "/nonexistent/path/xyz-\(UUID().uuidString)")
        let detector = AutoSourceDetector(roots: [bogus], depth: 2)
        let results = await detector.scan()
        XCTAssertEqual(results, [])
    }

    // MARK: - 11. Symlink dedup

    func testDedupesSameProjectViaSymlink() async throws {
        let tempdir = try makeTempDir()
        try makeProjectStructure(in: tempdir, layout: [
            "real/proj/CLAUDE.md",
        ])
        let realDir = tempdir.appendingPathComponent("real")
        let linkDir = tempdir.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(at: linkDir, withDestinationURL: realDir)

        let detector = AutoSourceDetector(roots: [realDir, linkDir], depth: 2)
        let results = await detector.scan()

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.dir.lastPathComponent, "proj")
    }
}
