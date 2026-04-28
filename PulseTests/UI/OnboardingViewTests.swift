import XCTest
@testable import Pulse

@MainActor
final class OnboardingViewTests: XCTestCase {

    func testOnboardingStateStartsAtWelcome() {
        let state = OnboardingState()
        XCTAssertEqual(state.page, .welcome)
        XCTAssertTrue(state.selectedDirs.isEmpty)
    }

    func testToggleSelectionAdds() {
        let state = OnboardingState()
        let url = URL(fileURLWithPath: "/tmp/foo")
        state.toggleSelection(url)
        XCTAssertTrue(state.selectedDirs.contains(url))
    }

    func testToggleSelectionRemoves() {
        let state = OnboardingState()
        let url = URL(fileURLWithPath: "/tmp/foo")
        state.toggleSelection(url)
        state.toggleSelection(url)
        XCTAssertFalse(state.selectedDirs.contains(url))
    }
}
