import AppKit
import SwiftUI
import XCTest
@testable import Pulse

@MainActor
final class AppDelegateTests: XCTestCase {

    /// `openSettings()` must create and key+order-front an NSWindow that
    /// hosts SettingsView. v0.4 Q4 ship-day fix: SwiftUI Settings scene
    /// (sendAction(showSettingsWindow:)) is unreliable on LSUIElement apps —
    /// no menu bar to register the action against. We bypass it by building
    /// the window directly via NSHostingController. This test locks that
    /// invariant so the next refactor can't quietly fall back to the old
    /// scene-based path.
    func testOpenSettingsCreatesAndShowsWindow() {
        let delegate = AppDelegate()
        XCTAssertNil(delegate.settingsWindow,
                     "fresh delegate should have no Settings window yet")

        delegate.openSettings()

        let window = delegate.settingsWindow
        XCTAssertNotNil(window, "openSettings must create the window")
        XCTAssertEqual(window?.title, L.pulseSettingsWindow,
                       "window title should match the bilingual L.pulseSettingsWindow string")
        XCTAssertNotNil(window?.contentViewController,
                        "window must have an NSHostingController hosting SettingsView")
        XCTAssertTrue(window?.contentViewController is NSHostingController<SettingsView>,
                      "contentViewController should host SettingsView via NSHostingController")
        XCTAssertTrue(window?.isVisible ?? false,
                      "openSettings must call makeKeyAndOrderFront so the window is visible")

        window?.close()
    }

    /// Reopening should reuse the cached window instance, not stack new ones.
    func testOpenSettingsReusesCachedWindow() {
        let delegate = AppDelegate()
        delegate.openSettings()
        let first = delegate.settingsWindow
        XCTAssertNotNil(first)

        delegate.openSettings()
        let second = delegate.settingsWindow

        XCTAssertTrue(first === second,
                      "second openSettings must surface the same window instance, not allocate a new one")

        first?.close()
    }
}
