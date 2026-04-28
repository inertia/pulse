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
            image?.isTemplate = true   // designer spec：template image，macOS 自動配 light/dark
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
            // 不再 NSApp.activate — 否則 .transient 失焦訊號被吃掉，click-outside 不會 dismiss。
            // popover 本身內部 SwiftUI 元件 focus 自己會處理鍵盤事件。
        }
    }

    /// Replace the popover's root view (used after Task 25 wires the real PopoverContentView).
    func updateRootView(_ rootView: AnyView) {
        popover.contentViewController = NSHostingController(rootView: rootView)
    }
}
