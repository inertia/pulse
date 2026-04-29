import Foundation

/// User-facing string table. Compiled per-build via `INTERNAL_BUILD`:
/// * Internal build (`Pulse Internal.app`) → Traditional Chinese (黃孫權 personal)
/// * Public build  (`Pulse.app`)            → English (everyone else)
///
/// Matching strings used by the ingest layer (e.g., section heading keywords
/// like `待辦` / `Done`) live in their own files and stay bilingual regardless
/// of build flag, since user `pulse.md` files may contain either language.
enum L {

    // MARK: - Header

    static let pulseSettingsWindow = bilingual(zh: "Pulse · 設定", en: "Pulse · Settings")

    // MARK: - Onboarding

    static let onboardingWelcome = bilingual(zh: "歡迎使用 Pulse", en: "Welcome to Pulse")
    static let onboardingTagline = bilingual(zh: "跨專案 todo / done 自動 monitor。",
                                             en: "Cross-project todo / done monitor.")
    static let onboardingScanIntro = bilingual(
        zh: "我會掃以下路徑（含一層子目錄）找含 CLAUDE.md / AGENTS.md / GEMINI.md 的目錄：",
        en: "I'll scan the following paths (one level deep) for CLAUDE.md / AGENTS.md / GEMINI.md files:")
    static let onboardingScanSkips = bilingual(zh: "跳過 node_modules / .git / dist / build 等",
                                               en: "Skipping node_modules / .git / dist / build etc.")
    static let onboardingStartButton = bilingual(zh: "開始掃描", en: "Start scanning")
    static let onboardingScanning = bilingual(zh: "掃描中…", en: "Scanning…")
    static let onboardingFinishButton = bilingual(zh: "完成", en: "Done")
    static let onboardingNoMatches = bilingual(zh: "沒有找到符合的專案", en: "No matching projects found")
    static let onboardingNoMatchesHint = bilingual(
        zh: "可手動加路徑（v0.2 將支援），或退出 onboarding。",
        en: "Add a path manually (coming in v0.2), or exit onboarding.")

    static func onboardingFoundCount(_ count: Int) -> String {
        bilingual(zh: "找到 \(count) 個專案", en: "Found \(count) projects")
    }

    // MARK: - Loading / scanning

    static func loadingProgress(done: Int, total: Int) -> String {
        bilingual(zh: "掃描中 \(done) / \(total) 專案",
                  en: "Scanning \(done) / \(total) projects")
    }

    // MARK: - Empty / error states

    static let emptyNoSources = bilingual(zh: "尚未設定任何 source",
                                          en: "No sources configured yet")
    static let emptyNoSourcesHint = bilingual(
        zh: "打開設定加入 CLAUDE.md / AGENTS.md / GEMINI.md 或 git 倉庫路徑。",
        en: "Open settings to add CLAUDE.md / AGENTS.md / GEMINI.md files or a git repository path.")
    static let emptyOpenSettings = bilingual(zh: "打開設定", en: "Open settings")
    static let emptyNoTodos = bilingual(zh: "沒有待辦", en: "No todos")
    static let sourceMissing = bilingual(zh: "來源遺失", en: "Source missing")

    // MARK: - Popover footer

    static let footerScanning = bilingual(zh: "掃描中…", en: "Scanning…")
    static let footerNeverRefreshed = bilingual(zh: "尚未更新", en: "Not refreshed yet")
    static let footerJustRefreshed = bilingual(zh: "剛剛更新", en: "Just refreshed")

    static func footerMinAgo(_ minutes: Int) -> String {
        bilingual(zh: "\(minutes) 分鐘前更新", en: "\(minutes) min ago")
    }

    static func footerHourAgo(_ hours: Int) -> String {
        bilingual(zh: "\(hours) 小時前更新", en: "\(hours) hr ago")
    }

    static func footerStats(projects: Int, todos: Int, dones: Int, timeAgo: String) -> String {
        bilingual(
            zh: "\(projects) 專案 · \(todos) 待辦 · \(dones) 完成 · \(timeAgo)",
            en: "\(projects) projects · \(todos) todos · \(dones) done · \(timeAgo)")
    }

    // MARK: - Done disclosure

    static func doneDisclosure(_ count: Int) -> String {
        bilingual(zh: "已完成 (\(count))", en: "Done (\(count))")
    }

    // MARK: - Project tab bar

    static let overviewLabel = bilingual(zh: "總覽", en: "Overview")

    // MARK: - Overview sections

    static let overviewUrgent = "🔴 URGENT outstanding"     // emoji + English everywhere
    static let overviewHigh = "🟡 HIGH outstanding"
    static let overviewLast24h = bilingual(zh: "完成 last 24h", en: "Done last 24h")
    static let overviewLast7d = bilingual(zh: "完成 last 7d", en: "Done last 7d")
    static let overviewEmpty = bilingual(zh: "沒有 outstanding 也沒有最近完成。",
                                         en: "Nothing outstanding, nothing recent.")

    // MARK: - Digest line (parts of "Done today: N  Outstanding: M  X projects pending")

    static let digestDoneTodayPrefix = bilingual(zh: "今天完成 ", en: "Done today: ")
    static let digestOutstandingMid = bilingual(zh: "　outstanding ", en: "　outstanding ")
    static let digestProjectsSeparator = bilingual(zh: "　", en: "　")
    static let digestProjectsSuffix = bilingual(zh: " 個專案待處理", en: " projects pending")

    // MARK: - Quick-todo composer

    static let quickFieldPlaceholder = bilingual(zh: "快速記一個 todo…",
                                                 en: "Quick-write a todo…")
    static let quickPulseOnly = bilingual(zh: "📝 只記在 Pulse", en: "📝 Pulse only")
    static let quickAddButton = bilingual(zh: "加", en: "Add")
    static let quickWriteToProject = bilingual(zh: "寫進專案", en: "Write to project")
    static let quickHeader = bilingual(zh: "快速記", en: "Quick")

    static func quickWriteFailed(_ value: String) -> String {
        bilingual(zh: "[寫檔失敗] \(value)", en: "[Write failed] \(value)")
    }

    // MARK: - Quick-todo virtual project label (used as ProjectGroup label key)

    static let quickProjectLabel = bilingual(zh: "📝 快速記", en: "📝 Quick")

    // MARK: - Settings

    static let settingsAboutTagline = bilingual(
        zh: "跨專案 todo / done 自動 monitor menubar app。",
        en: "Cross-project todo / done monitor menubar app.")
    static let settingsLicense = bilingual(zh: "MIT 授權", en: "MIT License")

    static let settingsGitFilterSection = bilingual(zh: "Git commits 過濾",
                                                    en: "Git commits filter")
    static let settingsGitFilterPicker = bilingual(zh: "過濾預設", en: "Filter preset")
    static let settingsGitFilterMinimal = bilingual(zh: "Minimal：只收 feat / fix",
                                                    en: "Minimal: feat / fix only")
    static let settingsGitFilterAll = bilingual(zh: "All：全部 conventional commit type",
                                                en: "All: every conventional commit type")
    static let settingsGitFilterFootnote = bilingual(zh: "變更後下次 refresh 才會生效。",
                                                     en: "Takes effect on the next refresh.")

    static let settingsAddMarkdownSource = bilingual(zh: "+ 加 markdown source",
                                                     en: "+ Add markdown source")
    static let settingsAddGitSource = bilingual(zh: "+ 加 git source",
                                                en: "+ Add git source")
}

private func bilingual(zh: String, en: String) -> String {
    #if INTERNAL_BUILD
    return zh
    #else
    return en
    #endif
}
