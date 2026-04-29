import AppKit
import SwiftUI

/// Modal window invoked from `SettingsView` → SourcesTab → "Rescan Desktop"
/// (Q4). Re-runs `AutoSourceDetector`, filters out projects whose dir is already
/// tracked in `sources.json`, and offers the remaining as adds via the same
/// `OnboardingScanResultsView` UI used at first-run onboarding.
@MainActor
final class RescanWindowController: NSWindowController {
    private let onComplete: ([DetectedProject], Set<URL>) -> Void

    init(
        existingDirs: Set<String>,
        onComplete: @escaping ([DetectedProject], Set<URL>) -> Void
    ) {
        self.onComplete = onComplete

        let view = RescanView(existingDirs: existingDirs) { projects, selectedDirs in
            onComplete(projects, selectedDirs)
        }
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable]
        window.title = L.settingsRescanWindowTitle
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

/// Two-phase view: scanning → results. Skips the welcome step that
/// `OnboardingView` shows on first-run; rescan is invoked deliberately by an
/// already-onboarded user so welcome would be noise.
struct RescanView: View {
    let existingDirs: Set<String>
    let onComplete: ([DetectedProject], Set<URL>) -> Void

    enum Phase: Equatable {
        case scanning
        case results([DetectedProject])
    }

    @State private var phase: Phase = .scanning
    @State private var selectedDirs: Set<URL> = []

    var body: some View {
        switch phase {
        case .scanning:
            VStack(spacing: 12) {
                ProgressView()
                Text(L.onboardingScanning)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .frame(width: 520, height: 520)
            .task { await runScan() }

        case .results(let projects):
            OnboardingScanResultsView(
                projects: projects,
                selectedDirs: selectedDirs,
                onToggle: { dir in
                    if selectedDirs.contains(dir) { selectedDirs.remove(dir) }
                    else { selectedDirs.insert(dir) }
                },
                onComplete: { onComplete(projects, selectedDirs) }
            )
        }
    }

    private func runScan() async {
        let detected = await AutoSourceDetector().scan()
        // Drop dirs already tracked anywhere in sources.json so the user only
        // sees genuinely new additions. Existing entries are managed via the
        // Sources tab toggle / delete row UI. Compare via `.path` string so
        // trailing-slash variation between URL constructors doesn't cause
        // false negatives.
        let new = detected.filter { !existingDirs.contains($0.dir.path) }
        await MainActor.run { phase = .results(new) }
    }
}
