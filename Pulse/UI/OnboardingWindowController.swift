import AppKit
import SwiftUI

@MainActor
final class OnboardingWindowController: NSWindowController {
    private let onComplete: ([DetectedProject], Set<URL>) -> Void

    init(onComplete: @escaping ([DetectedProject], Set<URL>) -> Void) {
        self.onComplete = onComplete

        let view = OnboardingView { projects, selectedDirs in
            onComplete(projects, selectedDirs)
        }
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable]
        window.title = "Pulse · 設定"
        window.setContentSize(NSSize(width: 520, height: 520))
        window.center()
        window.isReleasedWhenClosed = false

        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    func show() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    override func close() {
        window?.close()
    }
}
