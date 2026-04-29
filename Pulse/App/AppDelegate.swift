import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menubarController: MenubarIconController?
    private var scheduler: RefreshScheduler?
    private var cardStore: CardStore?
    private var sourceStore: SourceStore?
    private var settings: Pulse.Settings?
    private var quickTodoStore: QuickTodoStore?
    private var onboardingController: OnboardingWindowController?
    /// Internal so PulseTests can introspect the Settings-window-on-demand
    /// invariant. Don't access from production code outside this class.
    var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)   // 雙保險：LSUIElement + accessory

        let sourceStore = SourceStore()
        let cardStore = CardStore()
        let settings = Pulse.Settings()
        let quickTodoStore = QuickTodoStore()
        quickTodoStore.load()
        let scheduler = RefreshScheduler(
            sourceStore: sourceStore,
            cardStore: cardStore,
            settings: settings
        )

        self.sourceStore = sourceStore
        self.cardStore = cardStore
        self.settings = settings
        self.quickTodoStore = quickTodoStore
        self.scheduler = scheduler

        let rootView = AnyView(
            PopoverContentView(
                scheduler: scheduler,
                cardStore: cardStore,
                quickTodoStore: quickTodoStore,
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

        if settings.firstRunCompleted {
            // Returning user: start scheduler
            Task { await scheduler.start() }
        } else {
            #if INTERNAL_BUILD
            // Internal build first-run: preload 9 personal projects
            let preloaded = HuangSunQuanProjects.materialize()
            try? sourceStore.save(preloaded)
            settings.firstRunCompleted = true
            Task { await scheduler.start() }
            #else
            // First-run public build: show onboarding.
            showOnboarding()
            #endif
        }
    }

    private func showOnboarding() {
        let controller = OnboardingWindowController { [weak self] projects, selectedDirs in
            self?.completeOnboarding(projects: projects, selectedDirs: selectedDirs)
        }
        self.onboardingController = controller
        controller.show()
    }

    private func completeOnboarding(projects: [DetectedProject], selectedDirs: Set<URL>) {
        guard let sourceStore = self.sourceStore,
              let settings = self.settings,
              let scheduler = self.scheduler else { return }

        let newSources = AppDelegate.sourcesFromOnboarding(
            projects: projects,
            selectedDirs: selectedDirs
        )
        try? sourceStore.save(newSources)
        settings.firstRunCompleted = true
        onboardingController?.close()
        onboardingController = nil

        Task { await scheduler.start() }
    }

    /// Internal so PulseTests can drive this directly without simulating
    /// menubar clicks (LSUIElement apps can't be poked via standard Apple
    /// Events). Production callers stay through the popover gear button.
    func openSettings() {
        // Close popover first (transient won't dismiss for same-app focus).
        menubarController?.popover.performClose(nil)

        // LSUIElement (no Dock icon) apps don't reliably auto-route ⌘, /
        // `showSettingsWindow:` to a SwiftUI `Settings { ... }` scene because
        // there's no app menu bar to register the action against. Earlier
        // attempts with `NSApp.sendAction(Selector("showSettingsWindow:"))`
        // closed the popover but never showed a window. Bypass that mechanism
        // and present `SettingsView()` in our own NSHostingController-backed
        // NSWindow. Cache it so reopening reuses the same window instance.
        NSApp.activate(ignoringOtherApps: true)

        if let existing = settingsWindow {
            existing.makeKeyAndOrderFront(nil)
            return
        }
        let hosting = NSHostingController(rootView: SettingsView())
        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.title = L.pulseSettingsWindow
        window.setContentSize(NSSize(width: 560, height: 420))
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        settingsWindow = window
    }

    func applicationWillTerminate(_ notification: Notification) {
        scheduler?.stop()
    }
}

extension AppDelegate {
    /// Convert onboarding selections to sources. Pure function for testability.
    static func sourcesFromOnboarding(
        projects: [DetectedProject],
        selectedDirs: Set<URL>
    ) -> [Source] {
        var newSources: [Source] = []
        for dir in selectedDirs {
            guard let project = projects.first(where: { $0.dir == dir }) else { continue }
            let label = project.dir.lastPathComponent
            for kind in project.detectedFiles {
                let filename: String
                switch kind {
                case .claudeMd: filename = "CLAUDE.md"
                case .agentsMd: filename = "AGENTS.md"
                case .geminiMd: filename = "GEMINI.md"
                case .gitLog:   continue   // shouldn't happen: DetectedProject.detectedFiles only has markdown kinds
                }
                let path = project.dir.appendingPathComponent(filename)
                newSources.append(Source(kind: kind, path: path, label: label, enabled: true))
            }
            if project.isGitRepo {
                newSources.append(Source(kind: .gitLog, path: project.dir, label: label, enabled: true))
            }
        }
        return newSources
    }
}
