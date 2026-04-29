import XCTest
@testable import Pulse

@MainActor
final class OverviewViewTests: XCTestCase {

    /// Lock the public sentinel string so PopoverContentView's `selectedLabel`
    /// init keeps matching the pill's identity. If this changes, both sides need
    /// to update together — the test catches drift.
    func testOverviewLabelSentinelIsStable() {
        XCTAssertEqual(ProjectTabBar.overviewLabel, "Overview",
                       "Overview sentinel string is part of the contract — PopoverContentView.selectedLabel relies on this exact value")
    }
}
