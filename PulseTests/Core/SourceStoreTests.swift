import XCTest
@testable import Pulse

final class SourceStoreTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = FileManager.default
            .temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
    }

    override func tearDownWithError() throws {
        if let tempDir, FileManager.default.fileExists(atPath: tempDir.path) {
            try? FileManager.default.removeItem(at: tempDir)
        }
        tempDir = nil
        try super.tearDownWithError()
    }

    // MARK: - Empty / missing file

    func testLoadReturnsEmptyWhenFileMissing() {
        let store = SourceStore(directoryURL: tempDir)
        XCTAssertEqual(store.load(), [])
    }

    // MARK: - Save creates dir + file

    func testSaveCreatesDirectoryAndFile() throws {
        let store = SourceStore(directoryURL: tempDir)
        let source = Source(
            kind: .claudeMd,
            path: URL(fileURLWithPath: "/tmp/CLAUDE.md"),
            label: "Test"
        )

        try store.save([source])

        let expectedURL = tempDir.appendingPathComponent("sources.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: expectedURL.path),
                      "sources.json should exist at \(expectedURL.path)")
    }

    // MARK: - Round-trip

    func testRoundTrip() throws {
        let store = SourceStore(directoryURL: tempDir)
        let sources: [Source] = [
            Source(kind: .claudeMd,
                   path: URL(fileURLWithPath: "/tmp/a/CLAUDE.md"),
                   label: "Project A"),
            Source(kind: .agentsMd,
                   path: URL(fileURLWithPath: "/tmp/b/AGENTS.md"),
                   label: "Project B",
                   enabled: false),
            Source(kind: .gitLog,
                   path: URL(fileURLWithPath: "/tmp/c"),
                   label: "Repo C")
        ]

        try store.save(sources)
        let loaded = store.load()

        XCTAssertEqual(loaded, sources)
    }

    // MARK: - Corrupt JSON

    func testCorruptJsonReturnsEmpty() throws {
        try FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true
        )
        let url = tempDir.appendingPathComponent("sources.json")
        try "not-json".write(to: url, atomically: true, encoding: .utf8)

        let store = SourceStore(directoryURL: tempDir)
        XCTAssertEqual(store.load(), [])
    }

    // MARK: - Empty file

    func testEmptyFileReturnsEmpty() throws {
        try FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true
        )
        let url = tempDir.appendingPathComponent("sources.json")
        try Data().write(to: url, options: .atomic)

        let store = SourceStore(directoryURL: tempDir)
        XCTAssertEqual(store.load(), [])
    }
}
