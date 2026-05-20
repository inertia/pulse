import Foundation

enum GitFilterPreset: String, Codable {
    case minimal       // feat, fix
    case recommended   // feat/fix/refactor/perf + 日常研究工序（daily/papers/audit/skill）
    case all           // 全部：code type + 日常工序 + 中文 repo 前綴

    /// 標準 conventional commit 十種。
    private static let codeTypes: Set<String> = [
        "feat", "fix", "refactor", "perf",
        "chore", "docs", "build", "ci", "style", "test",
    ]

    /// 黃孫權日常研究工序 type。`add` 太通用故只進 `.all`，不進 `.recommended`。
    private static let workTypes: Set<String> = [
        "daily", "papers", "audit", "skill", "pulse", "wip", "revert",
    ]

    /// 中文 repo 前綴：commit subject 以專案名直接開頭時用。
    private static let repoTypes: Set<String> = [
        "矽盾", "矽盾週報", "新大眾文藝", "中國技術道路", "破週報", "文化與技術三部曲",
    ]

    var enabledTypes: Set<String> {
        switch self {
        case .minimal:
            return ["feat", "fix"]
        case .recommended:
            return ["feat", "fix", "refactor", "perf",
                    "daily", "papers", "audit", "skill"]
        case .all:
            return Self.codeTypes
                .union(Self.workTypes)
                .union(Self.repoTypes)
                .union(["add"])
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
