import XCTest
@testable import Pulse

final class ProjectGroupViewTests: XCTestCase {

    // MARK: - Helpers

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProjectGroupViewTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func makeView(sources: [Source]) -> ProjectGroupView {
        let group = ProjectGroup(label: "test", sources: sources, cards: [])
        return ProjectGroupView(group: group, onCardTap: { _ in })
    }

    // MARK: - isMissing

    func testIsMissingFalseWhenAllPathsExist() throws {
        let tempDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let mdPath = tempDir.appendingPathComponent("claude.md")
        try Data("# hi".utf8).write(to: mdPath)

        let source = Source(kind: .claudeMd, path: mdPath, label: "t", enabled: true)
        let view = makeView(sources: [source])

        XCTAssertFalse(view.isMissing)
    }

    func testIsMissingTrueWhenMarkdownPathMissing() {
        let source = Source(
            kind: .claudeMd,
            path: URL(fileURLWithPath: "/nonexistent/foo.md"),
            label: "t",
            enabled: true
        )
        let view = makeView(sources: [source])

        XCTAssertTrue(view.isMissing)
    }

    func testIsMissingFalseWhenSourceIsDisabled() {
        let source = Source(
            kind: .claudeMd,
            path: URL(fileURLWithPath: "/nonexistent/foo.md"),
            label: "t",
            enabled: false
        )
        let view = makeView(sources: [source])

        XCTAssertFalse(view.isMissing)
    }

    func testIsMissingTrueWhenGitLogDirHasNoDotGit() throws {
        let tempDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let source = Source(kind: .gitLog, path: tempDir, label: "t", enabled: true)
        let view = makeView(sources: [source])

        XCTAssertTrue(view.isMissing)
    }

    func testIsMissingFalseWhenGitLogDirHasDotGit() throws {
        let tempDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let gitDir = tempDir.appendingPathComponent(".git")
        try FileManager.default.createDirectory(at: gitDir, withIntermediateDirectories: true)

        let source = Source(kind: .gitLog, path: tempDir, label: "t", enabled: true)
        let view = makeView(sources: [source])

        XCTAssertFalse(view.isMissing)
    }

    func testIsMissingTrueIfAnyEnabledSourceMissing() throws {
        let tempDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let validPath = tempDir.appendingPathComponent("claude.md")
        try Data("# hi".utf8).write(to: validPath)

        let validSource = Source(kind: .claudeMd, path: validPath, label: "t1", enabled: true)
        let missingSource = Source(
            kind: .claudeMd,
            path: URL(fileURLWithPath: "/nonexistent/bar.md"),
            label: "t2",
            enabled: true
        )
        let view = makeView(sources: [validSource, missingSource])

        XCTAssertTrue(view.isMissing)
    }

    func testIsMissingFalseWhenNoSources() {
        let view = makeView(sources: [])

        XCTAssertFalse(view.isMissing)
    }
}
