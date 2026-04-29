import XCTest
import SwiftUI
@testable import Pulse

final class SourcesTabTests: XCTestCase {

    // Smoke tests: verify the views construct without crashing.
    // SourcesTab logic is thin glue over SourceStore (already tested in
    // SourceStoreTests). NSOpenPanel + Toggle / Label / List runtime behavior
    // requires UI eyeball verification.

    func testSettingsViewConstructs() {
        let view = SettingsView()
        XCTAssertNotNil(view.body)
    }

    func testSourcesTabConstructs() {
        let view = SourcesTab()
        XCTAssertNotNil(view.body)
    }

    // MARK: - Q4: existingDirs filter for rescan

    /// Markdown sources resolve to their parent dir; gitLog sources are dirs
    /// already. The set is what `RescanWindowController` excludes from new
    /// detected projects so the user only sees genuine adds.
    func testExistingDirs_collectsParentDirsForMarkdown_andDirItselfForGit() {
        let alpha = URL(fileURLWithPath: "/tmp/alpha")
        let beta = URL(fileURLWithPath: "/tmp/beta")

        let sources: [Source] = [
            Source(kind: .claudeMd, path: alpha.appendingPathComponent("CLAUDE.md"),
                   label: "alpha", enabled: true),
            Source(kind: .agentsMd, path: alpha.appendingPathComponent("AGENTS.md"),
                   label: "alpha", enabled: false),
            Source(kind: .gitLog, path: beta, label: "beta", enabled: true),
        ]

        let dirs = SourcesTab.existingDirs(from: sources)

        XCTAssertEqual(dirs, ["/tmp/alpha", "/tmp/beta"],
                       "markdown → parent dir path; gitLog → dir path as-is; both kinds dedup to project root")
    }

    /// Multiple sources sharing the same project dir (CLAUDE.md + git on the
    /// same project) collapse to one entry. Critical: URL.deletingLastPathComponent
    /// adds a trailing slash whereas URL(fileURLWithPath:) does not, so without
    /// canonicalising via `.path` the Set would store both variants and break
    /// dedup.
    func testExistingDirs_dedupsAcrossKinds() {
        let proj = URL(fileURLWithPath: "/tmp/shared")
        let sources: [Source] = [
            Source(kind: .claudeMd, path: proj.appendingPathComponent("CLAUDE.md"),
                   label: "shared", enabled: true),
            Source(kind: .gitLog, path: proj, label: "shared", enabled: true),
        ]
        XCTAssertEqual(SourcesTab.existingDirs(from: sources), ["/tmp/shared"])
    }
}
