import XCTest
import AppKit
import SwiftUI
@testable import Pulse

@MainActor
final class MenubarIconControllerTests: XCTestCase {
    /// NSStatusItem requires a window server connection. Test bundles run inside
    /// the host app, which usually has one — but if a runner is fully headless
    /// (no NSScreen.main), we skip rather than crash.
    private func skipIfHeadless() throws {
        try XCTSkipUnless(NSScreen.main != nil,
                          "Skipping: no NSScreen.main (headless test runner)")
    }

    func testInitDoesNotCrash() throws {
        try skipIfHeadless()
        let controller = MenubarIconController(rootView: AnyView(EmptyView()))
        XCTAssertNotNil(controller.popover)
    }

    func testPopoverContentSizeIsCorrect() throws {
        try skipIfHeadless()
        let controller = MenubarIconController(rootView: AnyView(EmptyView()))
        XCTAssertEqual(controller.popover.contentSize, NSSize(width: 400, height: 600))
    }

    func testPopoverBehaviorIsTransient() throws {
        try skipIfHeadless()
        let controller = MenubarIconController(rootView: AnyView(EmptyView()))
        XCTAssertEqual(controller.popover.behavior, .transient)
    }

    func testUpdateRootViewReplacesContent() throws {
        try skipIfHeadless()
        let controller = MenubarIconController(rootView: AnyView(Text("A")))
        let firstVC = controller.popover.contentViewController
        XCTAssertNotNil(firstVC)
        XCTAssertTrue(firstVC is NSHostingController<AnyView>)

        controller.updateRootView(AnyView(Text("B")))
        let secondVC = controller.popover.contentViewController
        XCTAssertNotNil(secondVC)
        XCTAssertTrue(secondVC is NSHostingController<AnyView>)
        // The hosting controller instance should have been swapped.
        XCTAssertFalse(firstVC === secondVC)
    }
}
