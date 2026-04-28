import XCTest
@testable import Pulse

final class InternalTests: XCTestCase {

    // MARK: - materialize() shape

    func testMaterializeProducesFiveSourcesPerProject() {
        let sources = HuangSunQuanProjects.materialize()
        let expected = HuangSunQuanProjects.list.count * 5
        XCTAssertEqual(sources.count, expected,
                       "materialize() should produce 5 sources per project (CLAUDE/AGENTS/GEMINI/pulse markdown + 1 gitLog)")
    }

    func testMaterializeMarkdownSourcesPointToCorrectFilenames() {
        let sources = HuangSunQuanProjects.materialize()

        for (i, project) in HuangSunQuanProjects.list.enumerated() {
            let base = i * 5
            guard sources.count >= base + 5 else {
                XCTFail("missing sources for project \(project.label)")
                continue
            }
            let dir = URL(fileURLWithPath: project.path)
            XCTAssertEqual(sources[base].kind, .claudeMd)
            XCTAssertEqual(sources[base].path, dir.appendingPathComponent("CLAUDE.md"))
            XCTAssertEqual(sources[base].label, project.label)

            XCTAssertEqual(sources[base + 1].kind, .agentsMd)
            XCTAssertEqual(sources[base + 1].path, dir.appendingPathComponent("AGENTS.md"))
            XCTAssertEqual(sources[base + 1].label, project.label)

            XCTAssertEqual(sources[base + 2].kind, .geminiMd)
            XCTAssertEqual(sources[base + 2].path, dir.appendingPathComponent("GEMINI.md"))
            XCTAssertEqual(sources[base + 2].label, project.label)

            XCTAssertEqual(sources[base + 3].kind, .claudeMd, "pulse.md uses claudeMd kind (markdown)")
            XCTAssertEqual(sources[base + 3].path, dir.appendingPathComponent("pulse.md"))
            XCTAssertEqual(sources[base + 3].label, project.label)
        }
    }

    func testMaterializeGitSourcePathIsDirNotAppendedFilename() {
        let sources = HuangSunQuanProjects.materialize()

        for (i, project) in HuangSunQuanProjects.list.enumerated() {
            let gitIndex = i * 5 + 4
            guard sources.count > gitIndex else {
                XCTFail("missing gitLog source for project \(project.label)")
                continue
            }
            let dir = URL(fileURLWithPath: project.path)
            XCTAssertEqual(sources[gitIndex].kind, .gitLog)
            XCTAssertEqual(sources[gitIndex].path, dir,
                           "gitLog path should be the project dir itself, not <dir>/.git")
            XCTAssertEqual(sources[gitIndex].label, project.label)
        }
    }

    func testMaterializeEnabledFlagMatchesFileExistence() {
        let fm = FileManager.default
        let sources = HuangSunQuanProjects.materialize()

        for source in sources {
            switch source.kind {
            case .claudeMd, .agentsMd, .geminiMd:
                let exists = fm.fileExists(atPath: source.path.path)
                XCTAssertEqual(source.enabled, exists,
                               "markdown source enabled flag should match file existence at \(source.path.path)")
            case .gitLog:
                let gitDir = source.path.appendingPathComponent(".git")
                let isGit = fm.fileExists(atPath: gitDir.path)
                XCTAssertEqual(source.enabled, isGit,
                               "gitLog source enabled flag should match .git existence at \(gitDir.path)")
            }
        }
    }

    // MARK: - List size by build configuration

    #if INTERNAL_BUILD
    func testListHasNineEntriesInInternalBuild() {
        XCTAssertEqual(HuangSunQuanProjects.list.count, 9)
    }
    #else
    func testListIsEmptyInPublicBuild() {
        XCTAssertEqual(HuangSunQuanProjects.list.count, 0)
    }
    #endif
}
