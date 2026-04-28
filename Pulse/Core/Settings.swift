import Foundation

enum GitFilterPreset: String, Codable {
    case minimal       // feat, fix
    case recommended   // feat, fix, refactor, perf
    case all           // feat, fix, refactor, perf, chore, docs, build, ci, style, test

    var enabledTypes: Set<String> {
        switch self {
        case .minimal:     return ["feat", "fix"]
        case .recommended: return ["feat", "fix", "refactor", "perf"]
        case .all:         return ["feat", "fix", "refactor", "perf",
                                    "chore", "docs", "build", "ci", "style", "test"]
        }
    }
}

@MainActor
final class Settings: ObservableObject {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    var gitFilterPreset: GitFilterPreset {
        get {
            let raw = defaults.string(forKey: "pulse.git.filterPreset") ?? "recommended"
            return GitFilterPreset(rawValue: raw) ?? .recommended
        }
        set {
            objectWillChange.send()
            defaults.set(newValue.rawValue, forKey: "pulse.git.filterPreset")
        }
    }

    var scanDepth: Int {
        get { defaults.object(forKey: "pulse.scan.depth") as? Int ?? 2 }
        set { objectWillChange.send(); defaults.set(newValue, forKey: "pulse.scan.depth") }
    }

    var firstRunCompleted: Bool {
        get { defaults.bool(forKey: "pulse.firstRunCompleted") }
        set { objectWillChange.send(); defaults.set(newValue, forKey: "pulse.firstRunCompleted") }
    }
}
