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
}
