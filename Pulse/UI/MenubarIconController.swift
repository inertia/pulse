import AppKit
import SwiftUI

@MainActor
final class MenubarIconController {
    private let statusItem: NSStatusItem
    let popover: NSPopover

    init(rootView: AnyView) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        popover = NSPopover()
        popover.behavior = .transient   // 失焦自動關
        popover.animates = true
        popover.contentSize = NSSize(width: 400, height: 600)
        popover.contentViewController = NSHostingController(rootView: rootView)

        if let button = statusItem.button {
            let image = NSImage(named: "MenuBarIcon")
                ?? NSImage(systemSymbolName: "waveform.path.ecg",
                           accessibilityDescription: "Pulse")
            image?.isTemplate = true   // 自動配深淺色 menubar
            button.image = image
            button.target = self
            button.action = #selector(togglePopover)
        }
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)   // 啟用 app 才能收 keyboard events
        }
    }

    /// Replace the popover's root view (used after Task 25 wires the real PopoverContentView).
    func updateRootView(_ rootView: AnyView) {
        popover.contentViewController = NSHostingController(rootView: rootView)
    }
}
