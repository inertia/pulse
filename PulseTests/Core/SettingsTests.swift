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
        XCTAssertEqual(
            GitFilterPreset.recommended.enabledTypes,
            ["feat", "fix", "refactor", "perf"]
        )
    }

    func testGitFilterPresetEnabledTypesAll() {
        let all = GitFilterPreset.all.enabledTypes
        XCTAssertEqual(all.count, 10)
        for type in ["feat", "fix", "refactor", "perf",
                     "chore", "docs", "build", "ci", "style", "test"] {
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
