import SwiftUI

@MainActor
final class OnboardingState: ObservableObject {
    enum Page: Equatable {
        case welcome
        case scanning
        case results([DetectedProject])
    }

    @Published var page: Page = .welcome
    @Published var selectedDirs: Set<URL> = []

    let detector: AutoSourceDetector

    init(detector: AutoSourceDetector = AutoSourceDetector()) {
        self.detector = detector
    }

    func startScan() async {
        page = .scanning
        let results = await detector.scan()
        // Auto-check projects modified within 90 days (per spec §6.4)
        let ninetyDaysAgo = Date().addingTimeInterval(-90 * 24 * 60 * 60)
        selectedDirs = Set(results.filter { $0.lastModified >= ninetyDaysAgo }.map { $0.dir })
        page = .results(results)
    }

    func toggleSelection(_ dir: URL) {
        if selectedDirs.contains(dir) {
            selectedDirs.remove(dir)
        } else {
            selectedDirs.insert(dir)
        }
    }
}

struct OnboardingView: View {
    @StateObject private var state = OnboardingState()
    let onComplete: ([DetectedProject], Set<URL>) -> Void

    var body: some View {
        switch state.page {
        case .welcome:
            OnboardingWelcomeView(onStartScan: {
                Task { await state.startScan() }
            })
        case .scanning:
            VStack(spacing: 12) {
                ProgressView()
                Text(L.onboardingScanning)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .results(let projects):
            OnboardingScanResultsView(
                projects: projects,
                selectedDirs: state.selectedDirs,
                onToggle: { dir in state.toggleSelection(dir) },
                onComplete: { onComplete(projects, state.selectedDirs) }
            )
        }
    }
}
