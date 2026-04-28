import XCTest
import CryptoKit
@testable import Pulse

@MainActor
final class ReadOnlyVerificationTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
        try super.tearDownWithError()
    }

    /// Compute SHA256 hex of a file.
    private func sha256(of url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// Mtime as TimeInterval (seconds since 1970).
    private func mtime(of url: URL) throws -> TimeInterval {
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let date = attrs[.modificationDate] as? Date else {
            throw NSError(domain: "ReadOnlyTest", code: 1)
        }
        return date.timeIntervalSince1970
    }

    func testMarkdownIngesterDoesNotModifyFile() async throws {
        let mdURL = tempDir.appendingPathComponent("CLAUDE.md")
        let content = "## To Do\n- [ ] task1\n- [ ] task2\n## Done\n- [x] done1\n"
        try content.write(to: mdURL, atomically: true, encoding: .utf8)

        let shaBefore = try sha256(of: mdURL)
        let mtimeBefore = try mtime(of: mdURL)

        let source = Source(kind: .claudeMd, path: mdURL, label: "test", enabled: true)
        let ingester = MarkdownIngester()
        let cards = try await ingester.fetch(source: source)

        let shaAfter = try sha256(of: mdURL)
        let mtimeAfter = try mtime(of: mdURL)

        XCTAssertEqual(shaBefore, shaAfter, "sha256 changed; ingester wrote to source file")
        XCTAssertEqual(mtimeBefore, mtimeAfter, accuracy: 0.001, "mtime changed; ingester touched source file")
        XCTAssertGreaterThan(cards.count, 0, "sanity check: cards were parsed")
    }

    func testMarkdownIngesterRunsTwiceWithoutModifying() async throws {
        let mdURL = tempDir.appendingPathComponent("CLAUDE.md")
        try "## To Do\n- [ ] task\n".write(to: mdURL, atomically: true, encoding: .utf8)

        let shaBefore = try sha256(of: mdURL)
        let mtimeBefore = try mtime(of: mdURL)

        let source = Source(kind: .claudeMd, path: mdURL, label: "test", enabled: true)
        let ingester = MarkdownIngester()
        _ = try await ingester.fetch(source: source)
        _ = try await ingester.fetch(source: source)
        _ = try await ingester.fetch(source: source)

        let shaAfter = try sha256(of: mdURL)
        let mtimeAfter = try mtime(of: mdURL)

        XCTAssertEqual(shaBefore, shaAfter)
        XCTAssertEqual(mtimeBefore, mtimeAfter, accuracy: 0.001)
    }

    func testGitIngesterDoesNotModifyRepoFiles() async throws {
        // Set up tempdir git repo with one tracked file
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = ["-c", """
            git init -b main && \
            git config user.email test@test.com && \
            git config user.name test && \
            git config commit.gpgsign false && \
            echo "hello" > tracked.txt && \
            git add tracked.txt && \
            git commit -m "feat: add tracked file"
        """]
        p.currentDirectoryURL = tempDir
        try p.run()
        p.waitUntilExit()

        let trackedURL = tempDir.appendingPathComponent("tracked.txt")
        let shaBefore = try sha256(of: trackedURL)
        let mtimeBefore = try mtime(of: trackedURL)

        let source = Source(kind: .gitLog, path: tempDir, label: "test", enabled: true)
        let ingester = GitIngester(enabledTypes: ["feat"])
        let cards = try await ingester.fetch(source: source)

        let shaAfter = try sha256(of: trackedURL)
        let mtimeAfter = try mtime(of: trackedURL)

        XCTAssertEqual(shaBefore, shaAfter, "git ingester modified tracked.txt")
        XCTAssertEqual(mtimeBefore, mtimeAfter, accuracy: 0.001)
        XCTAssertGreaterThan(cards.count, 0, "sanity: feat commit parsed")
    }
}
