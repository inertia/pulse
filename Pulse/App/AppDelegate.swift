import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menubarController: MenubarIconController?
    private var scheduler: RefreshScheduler?
    private var cardStore: CardStore?
    private var sourceStore: SourceStore?
    private var settings: Settings?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)   // 雙保險：LSUIElement + accessory

        let sourceStore = SourceStore()
        let cardStore = CardStore()
        let settings = Settings()
        let scheduler = RefreshScheduler(
            sourceStore: sourceStore,
            cardStore: cardStore,
            settings: settings
        )

        self.sourceStore = sourceStore
        self.cardStore = cardStore
        self.settings = settings
        self.scheduler = scheduler

        let rootView = AnyView(
            PopoverContentView(
                scheduler: scheduler,
                cardStore: cardStore,
                sourceStore: sourceStore,
                onSettingsTap: { [weak self] in
                    self?.openSettings()
                }
            )
        )
        let controller = MenubarIconController(rootView: rootView)
        self.menubarController = controller

        // load cached cards on launch
        cardStore.load()
        Task { await scheduler.start() }
    }

    private func openSettings() {
        // Close popover first (transient won't dismiss for same-app focus)
        menubarController?.popover.performClose(nil)
        // Open Settings scene
        if #available(macOS 14, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        scheduler?.stop()
    }
}
