import XCTest
import SwiftUI
@testable import Pulse

final class FiltersTabTests: XCTestCase {

    // Smoke test: verify FiltersTab constructs without crashing.
    // Picker runtime behavior (selection change, .inline radio rendering)
    // requires UI eyeball verification.

    @MainActor
    func testFiltersTabConstructs() {
        let suiteName = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let settings = Pulse.Settings(defaults: defaults)
        let view = FiltersTab(settings: settings)
        XCTAssertNotNil(view.body)
    }
}
