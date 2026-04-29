import AppKit
import SwiftUI

@MainActor
final class MenubarIconController {
    private let statusItem: NSStatusItem
    let popover: NSPopover

    /// Monitor for clicks outside our app (in other apps / desktop). Set when
    /// popover shows, removed when it closes.
    private var globalClickMonitor: Any?
    /// Monitor for clicks inside our app but outside the popover (e.g., on
    /// the Settings window once it's foregrounded). Necessary because
    /// `addGlobalMonitorForEvents` only catches events delivered to OTHER apps.
    private var localClickMonitor: Any?

    init(rootView: AnyView) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        popover = NSPopover()
        popover.behavior = .transient   // 失焦自動關 — but `.transient` only fires
                                        // when another app steals focus. With our
                                        // own Settings window opening via
                                        // NSApp.activate(), Pulse stays frontmost
                                        // and `.transient` dismiss can fail. The
                                        // global+local monitors below are the
                                        // belt that backs up that suspender.
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
            removeClickOutsideMonitors()
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            installClickOutsideMonitors()
        }
    }

    /// Install both global (other apps / desktop) and local (our app's other
    /// windows) click monitors. Either firing dismisses the popover. Idempotent —
    /// existing monitors are removed first.
    private func installClickOutsideMonitors() {
        removeClickOutsideMonitors()
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            Task { @MainActor in self?.dismissPopover() }
        }
        localClickMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            // Only dismiss if the click is NOT inside the popover itself.
            // SwiftUI handles in-popover clicks via the local responder
            // chain; we don't want to swallow them here. NSPopover hosts
            // its own content window; comparing event.window to that
            // catches the difference.
            if let popoverWindow = self?.popover.contentViewController?.view.window,
               event.window === popoverWindow {
                return event
            }
            Task { @MainActor in self?.dismissPopover() }
            return event
        }
    }

    private func removeClickOutsideMonitors() {
        if let m = globalClickMonitor {
            NSEvent.removeMonitor(m)
            globalClickMonitor = nil
        }
        if let m = localClickMonitor {
            NSEvent.removeMonitor(m)
            localClickMonitor = nil
        }
    }

    private func dismissPopover() {
        if popover.isShown {
            popover.performClose(nil)
        }
        removeClickOutsideMonitors()
    }

    /// Replace the popover's root view (used after Task 25 wires the real PopoverContentView).
    func updateRootView(_ rootView: AnyView) {
        popover.contentViewController = NSHostingController(rootView: rootView)
    }
}
