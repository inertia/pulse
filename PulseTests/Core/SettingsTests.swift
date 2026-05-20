import XCTest
@testable import Pulse

@MainActor
final class SettingsTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUpWithError() throws {
        try super.setUpWithError()
        suiteName = "test.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        try super.tearDownWithError()
    }

    // MARK: - Defaults

    func testDefaults() {
        let settings = Settings(defaults: defaults)
        XCTAssertEqual(settings.gitFilterPreset, .recommended)
        XCTAssertEqual(settings.scanDepth, 2)
        XCTAssertFalse(settings.firstRunCompleted)
    }

    // MARK: - Round-trips

    func testGitFilterPresetRoundTrip() {
        let settings = Settings(defaults: defaults)

        settings.gitFilterPreset = .minimal
        XCTAssertEqual(settings.gitFilterPreset, .minimal)

        settings.gitFilterPreset = .all
        XCTAssertEqual(settings.gitFilterPreset, .all)
    }

    func testScanDepthRoundTrip() {
        let settings = Settings(defaults: defaults)
        settings.scanDepth = 3
        XCTAssertEqual(settings.scanDepth, 3)
    }

    func testFirstRunCompletedRoundTrip() {
        let settings = Settings(defaults: defaults)
        settings.firstRunCompleted = true
        XCTAssertTrue(settings.firstRunCompleted)
    }

    // MARK: - GitFilterPreset.enabledTypes

    func testGitFilterPresetEnabledTypesMinimal() {
        XCTAssertEqual(GitFilterPreset.minimal.enabledTypes, ["feat", "fix"])
    }

    func testGitFilterPresetEnabledTypesRecommended() {
        // `recommended` = 原 4 種 code type + 4 種日常研究工序 type
        XCTAssertEqual(
            GitFilterPreset.recommended.enabledTypes,
            ["feat", "fix", "refactor", "perf",
             "daily", "papers", "audit", "skill"]
        )
    }

    func testGitFilterPresetEnabledTypesAll() {
        let all = GitFilterPreset.all.enabledTypes
        // 10 code + 7 work（daily/papers/audit/skill/pulse/wip/revert）
        // + 6 repo（矽盾／矽盾週報／新大眾文藝／中國技術道路／破週報／文化與技術三部曲）
        // + 1 add = 24
        XCTAssertEqual(all.count, 24)
        for type in ["feat", "fix", "refactor", "perf",
                     "chore", "docs", "build", "ci", "style", "test"] {
            XCTAssertTrue(all.contains(type), "all should contain \(type)")
        }
        for type in ["daily", "papers", "audit", "skill",
                     "pulse", "wip", "revert", "add"] {
            XCTAssertTrue(all.contains(type), "all should contain \(type)")
        }
        for type in ["矽盾", "矽盾週報", "新大眾文藝",
                     "中國技術道路", "破週報", "文化與技術三部曲"] {
            XCTAssertTrue(all.contains(type), "all should contain \(type)")
        }
    }

    // MARK: - Graceful fallback

    func testInvalidRawValueFallsBackToRecommended() {
        defaults.set("garbage", forKey: "pulse.git.filterPreset")
        let settings = Settings(defaults: defaults)
        XCTAssertEqual(settings.gitFilterPreset, .recommended)
    }
}
