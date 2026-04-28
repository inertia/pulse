import XCTest
@testable import Pulse

@MainActor
final class OnboardingCompletionTests: XCTestCase {

    func testSelectedProjectGeneratesMarkdownSources() {
        let dir = URL(fileURLWithPath: "/tmp/p1")
        let project = DetectedProject(
            dir: dir,
            detectedFiles: [.claudeMd, .agentsMd],
            lastModified: Date(),
            isGitRepo: false
        )
        let sources = AppDelegate.sourcesFromOnboarding(
            projects: [project],
            selectedDirs: [dir]
        )
        XCTAssertEqual(sources.count, 2)

        let claude = sources.first { $0.kind == .claudeMd }
        XCTAssertNotNil(claude)
        XCTAssertEqual(claude?.path, dir.appendingPathComponent("CLAUDE.md"))
        XCTAssertEqual(claude?.label, "p1")
        XCTAssertEqual(claude?.enabled, true)

        let agents = sources.first { $0.kind == .agentsMd }
        XCTAssertNotNil(agents)
        XCTAssertEqual(agents?.path, dir.appendingPathComponent("AGENTS.md"))
        XCTAssertEqual(agents?.label, "p1")
        XCTAssertEqual(agents?.enabled, true)
    }

    func testSelectedProjectWithGitAlsoGeneratesGitSource() {
        let dir = URL(fileURLWithPath: "/tmp/p2")
        let project = DetectedProject(
            dir: dir,
            detectedFiles: [.claudeMd],
            lastModified: Date(),
            isGitRepo: true
        )
        let sources = AppDelegate.sourcesFromOnboarding(
            projects: [project],
            selectedDirs: [dir]
        )
        XCTAssertEqual(sources.count, 2)

        let claude = sources.first { $0.kind == .claudeMd }
        XCTAssertEqual(claude?.path, dir.appendingPathComponent("CLAUDE.md"))

        let gitLog = sources.first { $0.kind == .gitLog }
        XCTAssertNotNil(gitLog)
        // gitLog source uses raw dir, not appended filename
        XCTAssertEqual(gitLog?.path, dir)
        XCTAssertEqual(gitLog?.label, "p2")
        XCTAssertEqual(gitLog?.enabled, true)
    }

    func testUnselectedProjectsAreIgnored() {
        let dir1 = URL(fileURLWithPath: "/tmp/p1")
        let dir2 = URL(fileURLWithPath: "/tmp/p2")
        let project1 = DetectedProject(
            dir: dir1,
            detectedFiles: [.claudeMd],
            lastModified: Date(),
            isGitRepo: false
        )
        let project2 = DetectedProject(
            dir: dir2,
            detectedFiles: [.agentsMd],
            lastModified: Date(),
            isGitRepo: false
        )
        let sources = AppDelegate.sourcesFromOnboarding(
            projects: [project1, project2],
            selectedDirs: [dir1]
        )
        XCTAssertEqual(sources.count, 1)
        XCTAssertEqual(sources.first?.kind, .claudeMd)
        XCTAssertEqual(sources.first?.label, "p1")
    }

    func testEmptySelectionGeneratesEmpty() {
        let project = DetectedProject(
            dir: URL(fileURLWithPath: "/tmp/p1"),
            detectedFiles: [.claudeMd],
            lastModified: Date(),
            isGitRepo: true
        )
        let sources = AppDelegate.sourcesFromOnboarding(
            projects: [project],
            selectedDirs: []
        )
        XCTAssertTrue(sources.isEmpty)
    }

    func testOnboardingWindowControllerInitsWithoutCrash() {
        let controller = OnboardingWindowController { _, _ in }
        XCTAssertNotNil(controller.window)
    }
}
