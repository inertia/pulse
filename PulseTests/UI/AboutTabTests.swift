import XCTest
import SwiftUI
@testable import Pulse

final class AboutTabTests: XCTestCase {

    // Smoke test: verify the view constructs without crashing.
    // buildKind logic uses #if compile-time directives (not runtime testable).
    // Bundle.main lookup + Link runtime behavior requires UI eyeball verification.

    func testAboutTabConstructs() {
        let view = AboutTab()
        XCTAssertNotNil(view.body)
    }
}
