import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menubarController: MenubarIconController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)   // 雙保險：LSUIElement + accessory
        let placeholder = AnyView(
            Text("Pulse v0.1 — popover placeholder")
                .padding()
        )
        menubarController = MenubarIconController(rootView: placeholder)
    }
}
