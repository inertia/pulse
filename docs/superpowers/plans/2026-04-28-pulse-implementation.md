# Pulse v0.1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship Pulse v0.1 — macOS menubar app that auto-ingests `CLAUDE.md` / `AGENTS.md` / `GEMINI.md` + git log conventional commits across cross-project paths, surfacing todo / done cards in a popover. Personal (`-internal`) build preloads 9 projects, public build runs onboarding to detect sources. Read-only — never writes back.

**Architecture:** SwiftUI content inside NSPopover, anchored to NSStatusItem. `LSUIElement = YES` removes dock icon. Multi-strategy markdown parser (Checkbox / EmojiCheckmark / NumberedSection / SectionHeading) + Conventional-Commits git log parser. xcconfig 切兩個 build target（Internal vs Public）。所有讀寫經 NSFileCoordinator 友善 iCloud daemon（雖然 v0.1 不做 iCloud sync，未來相容）。

**Tech Stack:** Swift 5.9+, SwiftUI 4, AppKit (`NSStatusItem` / `NSPopover` / `NSWindow`), Foundation (`Process` / `FileManager` / `DispatchSource` for FSEvents), XCTest. xcodegen 產生 `Pulse.xcodeproj`，不 commit `.xcodeproj`。

**Spec:** `docs/superpowers/specs/2026-04-28-pulse-design.md`

**macOS deployment target:** macOS 14 (Sonoma)。

---

## Phases at a Glance

| Phase | Milestone | Tasks |
|---|---|---|
| 1 | Repo + Xcode scaffold | 1-4 |
| 2 | Core data model + persistence | 5-9 |
| 3 | MultiStrategy markdown parser | 10-14 |
| 4 | Conventional commits parser | 15-17 |
| 5 | Ingester orchestration | 18-19 |
| 6 | AutoSourceDetector | 20-21 |
| 7 | App scaffold + Menubar | 22 |
| 8 | Refresh scheduler + FSEvents | 23-24 |
| 9 | Popover UI (SwiftUI) | 25-27 |
| 10 | Settings window | 28-30 |
| 11 | Onboarding (通用版) | 31-32 |
| 12 | Internal build flag (個人版) | 33 |
| 13 | Build / ship + G7 verify | 34-37 |

Total: 37 tasks.

---

## Conventions

- 每 task 結束 commit
- Conventional commits message：`feat(scope)`、`fix(scope)`、`refactor(scope)`、`test(scope)`、`chore(scope)`、`docs(scope)`、`build(scope)`、`ci(scope)`
- 自撰段落不用破折號（spec/plan 結構分隔 `---` ok）
- TDD 對所有有 logic 的任務（parser、store、ingester、detector）
- UI 任務 smoke build + 實機 verify（截圖貼到 §Verification Log）
- 對應 spec section 註明 `[Spec §X.Y]`
- 不 commit `.xcodeproj/`、`build/`、`DerivedData/`、`.DS_Store`

---

## Phase 1：Repo + Xcode Scaffold

### Task 1：基本檔案 + .gitignore + README `[Spec §13.5]`

**Files:**
- Create: `.gitignore`, `README.md`, `CLAUDE.md`, `HANDOFF.md`, `LICENSE`

- [ ] `.gitignore` 內容：
```
# Xcode
*.xcodeproj/
build/
DerivedData/
*.xcuserstate
xcuserdata/

# Swift Package Manager
.build/
Package.resolved
.swiftpm/

# macOS
.DS_Store

# Build output
*.dmg
build/

# Local
.env
*.local
```
- [ ] `README.md` 簡短：app 介紹、安裝（dmg from GitHub release）、support `CLAUDE.md` / `AGENTS.md` / `GEMINI.md`
- [ ] `CLAUDE.md`：Pulse 專案的 hint（簡短，給未來 Claude session）
- [ ] `HANDOFF.md`：跨 session handoff（v0.1 開發中狀態）
- [ ] `LICENSE`：MIT
- [ ] commit：`chore: init Pulse repo with .gitignore, README, LICENSE`

### Task 2：xcconfig × 3 + project.yml `[Spec §4.3]`

**Files:**
- Create: `xcconfig/Shared.xcconfig`, `xcconfig/Pulse-Internal.xcconfig`, `xcconfig/Pulse-Public.xcconfig`, `project.yml`

- [ ] `xcconfig/Shared.xcconfig`：
```
MACOSX_DEPLOYMENT_TARGET = 14.0
SWIFT_VERSION = 5.9
ARCHS = arm64 x86_64
ENABLE_USER_SCRIPT_SANDBOXING = NO
ENABLE_HARDENED_RUNTIME = YES
PRODUCT_NAME = Pulse
INFOPLIST_KEY_LSUIElement = YES
INFOPLIST_KEY_LSApplicationCategoryType = public.app-category.developer-tools
INFOPLIST_KEY_NSHighResolutionCapable = YES
```

- [ ] `xcconfig/Pulse-Internal.xcconfig`：
```
#include "Shared.xcconfig"
GCC_PREPROCESSOR_DEFINITIONS = $(inherited) INTERNAL_BUILD=1
SWIFT_ACTIVE_COMPILATION_CONDITIONS = $(inherited) INTERNAL_BUILD
PRODUCT_BUNDLE_IDENTIFIER = com.huangsunquan.pulse.internal
INFOPLIST_KEY_CFBundleDisplayName = Pulse Internal
```

- [ ] `xcconfig/Pulse-Public.xcconfig`：
```
#include "Shared.xcconfig"
PRODUCT_BUNDLE_IDENTIFIER = com.huangsunquan.pulse
INFOPLIST_KEY_CFBundleDisplayName = Pulse
```

- [ ] `project.yml`（xcodegen）：
```yaml
name: Pulse
options:
  bundleIdPrefix: com.huangsunquan
  deploymentTarget:
    macOS: "14.0"
configs:
  Debug-Internal: debug
  Release-Internal: release
  Debug-Public: debug
  Release-Public: release
configFiles:
  Debug-Internal: xcconfig/Pulse-Internal.xcconfig
  Release-Internal: xcconfig/Pulse-Internal.xcconfig
  Debug-Public: xcconfig/Pulse-Public.xcconfig
  Release-Public: xcconfig/Pulse-Public.xcconfig
targets:
  Pulse:
    type: application
    platform: macOS
    sources:
      - path: Pulse
    settings:
      base:
        ENABLE_PREVIEWS: YES
  PulseTests:
    type: bundle.unit-test
    platform: macOS
    sources:
      - path: PulseTests
    dependencies:
      - target: Pulse
schemes:
  Pulse:
    build:
      targets:
        Pulse: all
        PulseTests: [test]
```

- [ ] commit：`build: add xcconfig (Internal/Public/Shared) + project.yml`

### Task 3：PulseApp.swift LSUIElement 骨架 `[Spec §4.1]`

**Files:**
- Create: `Pulse/App/PulseApp.swift`, `Pulse/App/AppDelegate.swift`, `Pulse/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`

- [ ] `Pulse/App/PulseApp.swift`：
```swift
import SwiftUI

@main
struct PulseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }   // ⌘, opens settings window (real impl later)
    }
}
```

- [ ] `Pulse/App/AppDelegate.swift`：
```swift
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)   // 雙保險：LSUIElement + accessory
    }
}
```

- [ ] commit：`feat(app): scaffold PulseApp with LSUIElement (no dock icon)`

### Task 4：xcodegen + smoke build `[Spec §4]`

- [ ] 確認 xcodegen 已裝：`which xcodegen || brew install xcodegen`
- [ ] 跑 `xcodegen generate`
- [ ] 跑 `xcodebuild -project Pulse.xcodeproj -scheme Pulse -configuration Debug-Public build` 確認可編
- [ ] 開 `Pulse.xcodeproj` 在 Xcode 跑 → 確認沒 dock icon、沒 main window（Settings 視窗預設不開啟）
- [ ] `Scripts/run-tests.sh`：
```bash
#!/usr/bin/env bash
set -e
xcodebuild -project Pulse.xcodeproj -scheme Pulse \
  -configuration Debug-Public \
  -destination 'platform=macOS' \
  test
```
- [ ] `chmod +x Scripts/run-tests.sh`
- [ ] commit：`build: bootstrap xcodegen-generated project + run-tests.sh`

---

## Phase 2：Core Data Model + Persistence

### Task 5：Source + SourceKind `[Spec §5.1]`

**Files:**
- Create: `Pulse/Core/Source.swift`, `PulseTests/Core/SourceTests.swift`

- [ ] `Pulse/Core/Source.swift`：
```swift
import Foundation

enum SourceKind: String, Codable, CaseIterable {
    case claudeMd, agentsMd, geminiMd, gitLog
}

struct Source: Identifiable, Codable, Equatable {
    let id: UUID
    let kind: SourceKind
    let path: URL
    let label: String
    let enabled: Bool

    init(id: UUID = UUID(), kind: SourceKind, path: URL, label: String, enabled: Bool = true) {
        self.id = id
        self.kind = kind
        self.path = path
        self.label = label
        self.enabled = enabled
    }
}
```

- [ ] TDD `PulseTests/Core/SourceTests.swift`：round-trip JSON encode/decode、`enabled` default = true
- [ ] 跑 `Scripts/run-tests.sh` 驗 PASS
- [ ] commit：`feat(core): Source model with Codable round-trip`

### Task 6：SourceStore `[Spec §5.1]`

**Files:**
- Create: `Pulse/Core/SourceStore.swift`, `PulseTests/Core/SourceStoreTests.swift`

- [ ] Path 在 `~/Library/Application Support/Pulse/sources.json`
- [ ] API：
```swift
final class SourceStore {
    static let shared = SourceStore()
    private let url: URL
    init(directoryURL: URL? = nil) { ... }   // tempdir-friendly for tests
    func load() -> [Source]
    func save(_ sources: [Source]) throws
}
```
- [ ] 不存在時 `load()` 回 `[]`
- [ ] TDD：tempdir 模擬 load/save、空檔案、毀損 JSON 不 crash
- [ ] commit：`feat(core): SourceStore reads/writes sources.json`

### Task 7：Card + identity hash `[Spec §5.2, §4.8]`

**Files:**
- Create: `Pulse/Core/Card.swift`, `PulseTests/Core/CardTests.swift`

- [ ] `Pulse/Core/Card.swift`：
```swift
import CryptoKit
import Foundation

enum Status: String, Codable { case todo, done }

struct Card: Identifiable, Codable, Equatable {
    let id: String
    let sourceId: UUID
    let title: String           // 已 normalize（去日期、去 #tag、trim）
    let body: String?
    let status: Status
    let dueDate: Date?
    let completedAt: Date?
    let sourceRef: String       // "file.md:42" 或 commit SHA（顯示用，非 identity）
    let tags: [String]

    /// Identity = SHA256(path + sectionHeading + normalizedTitle)。
    /// 不含 lineNumber：避免 user 在檔案上方插一行 → cards id 全變 → cache 失效。
    /// sourceRef 帶 lineNumber 是給 UI 顯示用，不參與 hash。
    static func makeId(path: String, sectionHeading: String, normalizedTitle: String) -> String {
        let joined = [path, sectionHeading, normalizedTitle].joined(separator: "\n")
        let hash = SHA256.hash(data: Data(joined.utf8))
        return String(hash.compactMap { String(format: "%02x", $0) }.joined().prefix(16))
    }
}
```

- [ ] TDD：
  - 相同 (path, heading, title) → 兩次 hash 相同
  - 不同任一參數 → hash 不同
  - **lineNumber drift 回歸測試**：同 path/heading/title 但模擬「行號從 5 變成 7」場景下 makeId 結果一致（因為不含 lineNumber）
  - Codable round-trip
- [ ] commit：`feat(core): Card model + content-keyed identity hash (no lineNumber)`

### Task 8：CardStore (cache + schema versioning) `[Spec §5.2]`

**Files:**
- Create: `Pulse/Core/CardStore.swift`, `PulseTests/Core/CardStoreTests.swift`

- [ ] Path `~/Library/Application Support/Pulse/cards-cache.json`
- [ ] Cache schema：
```swift
struct CardCacheFile: Codable {
    let version: Int            // current = 1
    let cards: [Card]
}

@MainActor
final class CardStore: ObservableObject {
    static let currentVersion = 1
    @Published private(set) var cards: [Card] = []
    private let url: URL

    init(directoryURL: URL? = nil) { /* path = ApplicationSupport/Pulse/cards-cache.json */ }

    func load() {
        // try-catch decode；version mismatch 或 decode fail → cards = []，視為 cold start
        guard let data = try? Data(contentsOf: url) else { cards = []; return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let file = try? decoder.decode(CardCacheFile.self, from: data),
              file.version == Self.currentVersion else {
            cards = []   // cold start，下次 refresh 重建
            return
        }
        cards = file.cards
    }

    func save() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let file = CardCacheFile(version: Self.currentVersion, cards: cards)
        try encoder.encode(file).write(to: url, options: .atomic)
    }

    func replace(forSource sourceId: UUID, with newCards: [Card]) {
        cards = cards.filter { $0.sourceId != sourceId } + newCards
    }
}
```

- [ ] TDD：
  - load/save round-trip
  - `replace(forSource:)` 不影響其他 source 的 cards
  - **schema mismatch 不 crash**：先寫 `version: 999` 的 cache.json → load() 後 cards 為 []，無 throw
  - **毀損 JSON 不 crash**：寫 `not json` → load() 後 cards 為 []
- [ ] commit：`feat(core): CardStore with schema versioning + safe decode`

### Task 9：Settings (UserDefaults injection, no @AppStorage) `[Spec §6.3]`

**Files:**
- Create: `Pulse/Core/Settings.swift`, `PulseTests/Core/SettingsTests.swift`

> 改採 UserDefaults 注入而非 `@AppStorage`：`@AppStorage` 鎖死 `UserDefaults.standard`，無法注入 ephemeral instance 做測試；且只在 SwiftUI `View` body 中行為正確。

- [ ] `Settings.swift`：
```swift
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
```

- [ ] 4 個 strategy toggle 不在 Settings — 預設全 ON 不開放調整（B 簡化方案）
- [ ] 10 個 git type toggle 收成 `gitFilterPreset` 一個欄位
- [ ] TDD：用 `UserDefaults(suiteName: "test.\(UUID())")!` 注入做隔離測試：
  - default：preset = .recommended、scanDepth = 2、firstRunCompleted = false
  - 寫入後讀回一致
  - `gitFilterPreset.enabledTypes` 對 minimal / recommended / all 三種值正確
- [ ] commit：`feat(core): Settings with injected UserDefaults + GitFilterPreset enum`

---

## Phase 3：MultiStrategy Markdown Parser

### Task 10：MarkdownStrategy protocol + CheckboxStrategy `[Spec §4.5]`

**Files:**
- Create: `Pulse/Ingest/MarkdownStrategy.swift`, `Pulse/Ingest/Strategies/CheckboxStrategy.swift`, `PulseTests/Ingest/CheckboxStrategyTests.swift`

- [ ] `MarkdownStrategy.swift`：
```swift
import Foundation

struct ParsedItem: Equatable {
    let title: String
    let body: String?
    let status: Status
    let lineNumber: Int
    let sectionHeading: String   // 所屬 section（為 identity 用）
    let dueDate: Date?
    let completedAt: Date?
    let tags: [String]
}

protocol MarkdownStrategy {
    func parse(lines: [String], sourcePath: URL) -> [ParsedItem]
}
```

- [ ] `CheckboxStrategy.swift`：抓 `^[\s]*-\s+\[([ xX])\]\s+(.+)$`
  - `[ ]` → `.todo`
  - `[x]` / `[X]` → `.done`
  - sectionHeading = 最近的 `## ` 或 `### ` 標題
  - body = 後續縮排 sub-bullets 串接
- [ ] TDD：餵以下測例：
  - 純 todo `- [ ] foo`
  - 純 done `- [x] bar` / `- [X] BAR`
  - sub-bullet 不獨立成 item，當前一條的 body
  - 無 checkbox 完全跳過
  - section heading 變化（從 `## To Do` 跳到 `## Done`）
- [ ] commit：`feat(ingest): CheckboxStrategy for - [ ]/[x] markdown`

### Task 11：EmojiCheckmarkStrategy `[Spec §4.5]`

**Files:**
- Create: `Pulse/Ingest/Strategies/EmojiCheckmarkStrategy.swift`, `PulseTests/Ingest/EmojiCheckmarkStrategyTests.swift`

- [ ] regex `^[\s]*-\s+(✅|⏳|❌)\s*(.+)$`
- [ ] `✅` → `.done`
- [ ] `⏳` / `❌` 跳過（in-progress / cancelled 不收）
- [ ] body / sectionHeading 同 CheckboxStrategy
- [ ] TDD：以 heterotopias `CLAUDE.md` 「### Recently Done」段落做 fixture，至少抓到 `R2 圖片搬遷`、`Theme-dot hardening` 等
- [ ] commit：`feat(ingest): EmojiCheckmarkStrategy for - ✅`

### Task 12：NumberedSectionStrategy `[Spec §4.5]`

**Files:**
- Create: `Pulse/Ingest/Strategies/NumberedSectionStrategy.swift`, `PulseTests/Ingest/NumberedSectionStrategyTests.swift`

- [ ] 觸發條件：當前 sectionHeading 包含 keyword（`URGENT`、`HIGH`、`MEDIUM`、`LOW`、`Planned Work`、`To Do`、`待辦`、`Recently Done`、`Recent Work`、`已完成`）
- [ ] 段內 regex `^[\s]*\d+\.\s+\*\*(.+?)\*\*\s*[—\-:]\s*(.+)$`（編號 + bold title + body）或 `^[\s]*\d+\.\s+(.+)$`（無 bold）
- [ ] heading 含 `Recently Done` / `Recent Work` / `已完成` → `.done`；否則 `.todo`
- [ ] body 包含後續縮排行直到下一 numbered item / heading
- [ ] TDD：餵 heterotopias `### URGENT` / `### HIGH` 段落（spec 範例 `0. **P0-1 schema drift**`），驗抓出 todo + body
- [ ] commit：`feat(ingest): NumberedSectionStrategy for ### URGENT/HIGH numbered items`

### Task 13：SectionHeadingStrategy `[Spec §4.5]`

**Files:**
- Create: `Pulse/Ingest/Strategies/SectionHeadingStrategy.swift`, `PulseTests/Ingest/SectionHeadingStrategyTests.swift`

- [ ] heading match keyword（同 NumberedSection 但更嚴：只認段標題本身為「## To Do」「## Done」「## Planned Work」「## Recently Done」「## Recent Work」「## 待辦」「## 已完成」）
- [ ] 段內 `^[\s]*-\s+(.+)$` 抓所有 dash bullet（前面沒 checkbox / emoji）當為 todo / done（依 heading）
- [ ] TDD：餵 v1 spec §4.1 範例
```
## To Do
- 重建破報資料庫網站
- admin server 端計畫

## Done
- 新大眾文藝知識庫架構（2026-02-28）
```
驗抓出 2 todo + 1 done
- [ ] commit：`feat(ingest): SectionHeadingStrategy for ## To Do/Done blocks`

### Task 14：MultiStrategyMarkdownParser + dedup + 行尾日期/tag `[Spec §4.5, §4.8]`

**Files:**
- Create: `Pulse/Ingest/MultiStrategyMarkdownParser.swift`, `PulseTests/Ingest/MultiStrategyMarkdownParserTests.swift`, `PulseTests/Fixtures/heterotopias-sample.md`, `PulseTests/Fixtures/checkbox-style.md`

- [ ] 主類：
```swift
final class MultiStrategyMarkdownParser {
    private let strategies: [MarkdownStrategy]
    init(strategies: [MarkdownStrategy]) { self.strategies = strategies }
    func parse(filePath: URL, sourceId: UUID) throws -> [Card]
}
```

- [ ] 流程（**順序很重要**：normalize 必須先於 hash）：
  1. 讀檔 → split lines
  2. 每個 strategy 跑一次 → 收 `[ParsedItem]`（含 raw title、lineNumber、sectionHeading）
  3. **normalize title**：
     - 行尾 `（YYYY-MM-DD）` / `(YYYY-MM-DD)` → 抽出設 `dueDate`（todo）/ `completedAt`（done），從 title 移除
     - 行內 `#tag` 抽出加進 `tags`，從 title 移除
     - trim 兩端空白
  4. ParsedItem → Card：
     - `id = Card.makeId(path: path, sectionHeading: heading, normalizedTitle: title)`（**不含 lineNumber**，spec §4.8）
     - `sourceRef = "\(filename):\(lineNumber)"`（顯示用）
  5. 跨 strategy dedup：相同 id 取第一個（衝撞為設計）

- [ ] **Fixture 改用 PulseTests/Fixtures**（不依賴開發者個人 Desktop）：
  - `heterotopias-sample.md`：從 `~/Desktop/new_heterotopias/CLAUDE.md` 抽 `### Recently Done (2026-04-17)` + `### URGENT` 兩段（約 50 行）放進 fixture
  - `checkbox-style.md`：手寫的標準 `## To Do` / `## Done` 含 `- [ ]` / `- [x]` 範例

- [ ] TDD：
  - **integration with fixture**：對 `heterotopias-sample.md` 跑 → 至少 5 個 `- ✅` done cards + 3 個 numbered todos（具體數依 fixture 內容定）
  - **integration with checkbox fixture**：對 `checkbox-style.md` 跑 → cards 數正確
  - **跨 strategy dedup**：構造一條同時被 CheckboxStrategy 跟 SectionHeadingStrategy 抓的 line `## To Do\n- [ ] foo` → 期望 1 卡（不重複）
  - **lineNumber drift 回歸測試**：兩份 fixture 內容一樣但前面塞 N 行空白 → cards 的 id 集合一致（identity 不受 lineNumber 影響）
  - **日期解析**：`- [x] foo (2026-04-25)` → `completedAt = 2026-04-25`，title = "foo"
  - **tag 解析**：`- [ ] foo #urgent #review` → `tags = ["urgent", "review"]`，title = "foo"
  - **normalize 順序**：原 title `bar (2026-04-25) #done` → 同 (path, heading) 下的 hash 跟 `bar (其他變體)` 應**不同**（normalize 後 title 不一樣 = 不同卡），但跟另一份 `bar` 純 title（無日期 tag）的 hash 相同
- [ ] commit：`feat(ingest): MultiStrategyMarkdownParser with normalize-then-hash + fixtures`

---

## Phase 4：Conventional Commits Parser

### Task 15：ConventionalCommitsParser `[Spec §4.6]`

**Files:**
- Create: `Pulse/Ingest/ConventionalCommitsParser.swift`, `PulseTests/Ingest/ConventionalCommitsParserTests.swift`

- [ ] regex `^(feat|fix|refactor|perf|chore|docs|build|ci|style|test)(\([^)]*\))?:\s+(.+)$`
- [ ] Input：raw `git log --pretty=%H%x09%aI%x09%s%x09%b -n 100` 輸出（一條 commit 多行用 `\u{1e}` record sep）
- [ ] Output：`[Card]` with `status = .done`, `completedAt = author date`, `sourceRef = SHA`, `tags = [<repo>, <type>]`
- [ ] 過濾：呼叫者傳 `enabledTypes: Set<String>`（從 Settings）
- [ ] TDD：mock 輸出
```
abc123\t2026-04-25T10:00:00+08:00\tfeat(rename): file + title rename in one action\t
def456\t2026-04-24T08:00:00+08:00\tdocs: add CHANGELOG\t
ghi789\t2026-04-23T15:00:00+08:00\trandom non-conventional message\t
```
驗 enabled `[feat, fix]` → 1 卡（abc123）；enabled `[feat, fix, docs]` → 2 卡
- [ ] commit：`feat(ingest): ConventionalCommitsParser with type filter`

### Task 16：GitLogRunner (Process wrapper) + PATH fallback `[Spec §4.6, §11 risk]`

**Files:**
- Create: `Pulse/Ingest/GitLogRunner.swift`, `PulseTests/Ingest/GitLogRunnerTests.swift`

> **PATH 議題**：GUI app 啟動時的 PATH 不含 `/opt/homebrew/bin` / `/usr/local/bin`，所以 `/usr/bin/env git` 對只裝 Homebrew git 的 user 失敗。直接探測 binary 路徑。

- [ ] 跑：
```swift
struct GitLogRunner {
    /// 找系統可用的 git binary，依序試：Xcode CLT / Homebrew arm64 / Homebrew x86_64
    static func resolveGitPath() -> String? {
        let candidates = [
            "/usr/bin/git",                  // macOS 14+ 系統內建（Xcode CLT 安裝後）
            "/opt/homebrew/bin/git",         // Apple Silicon Homebrew
            "/usr/local/bin/git",            // Intel Homebrew
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    static func run(at dir: URL, limit: Int = 100) throws -> String {
        guard let gitPath = resolveGitPath() else { throw GitLogError.gitNotFound }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: gitPath)
        p.arguments = ["-C", dir.path, "log",
                       "--pretty=%H%x09%aI%x09%s%x09%b%x1e",
                       "-n", String(limit)]
        let pipe = Pipe()
        let errPipe = Pipe()
        p.standardOutput = pipe
        p.standardError = errPipe
        try p.run()
        p.waitUntilExit()
        guard p.terminationStatus == 0 else {
            let err = String(decoding: errPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            throw GitLogError.failed(p.terminationStatus, stderr: err)
        }
        return String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    }
}

enum GitLogError: Error {
    case gitNotFound
    case failed(Int32, stderr: String)
}
```

- [ ] TDD：
  - tempdir `git init` + 3 commits → 跑 → stdout 含 3 個 SHA（用 `resolveGitPath()` 找到的 git）
  - 非 git repo 路徑 → `failed(_, stderr:)` throw（stderr 含 git error message）
  - **resolveGitPath() 優先序**：mock `FileManager.isExecutableFile` 模擬只有 homebrew 路徑存在 → return `/opt/homebrew/bin/git`（用 protocol 注入或單元測 candidate 順序常數）
- [ ] commit：`feat(ingest): GitLogRunner with PATH-aware git resolution`

### Task 17：repo label = repo dir name `[Spec §4.6]`

**Files:**
- Modify: `Pulse/Ingest/ConventionalCommitsParser.swift`（補 `repoLabel` 參數）

- [ ] Parser API：`parse(stdout: String, sourceId: UUID, repoLabel: String, enabledTypes: Set<String>) -> [Card]`
- [ ] tags = `[repoLabel, type]`（例：`["Heterotopias", "feat"]`）
- [ ] TDD：驗 tags 順序 + 內容
- [ ] commit：`feat(ingest): ConventionalCommitsParser tags include repo label`

---

## Phase 5：Ingester Orchestration

### Task 18：Ingester protocol + Markdown impl `[Spec §4.4]`

**Files:**
- Create: `Pulse/Ingest/Ingester.swift`, `Pulse/Ingest/MarkdownIngester.swift`, `PulseTests/Ingest/MarkdownIngesterTests.swift`

- [ ] `Ingester.swift`：
```swift
protocol Ingester {
    func fetch(source: Source) async throws -> [Card]
}
```

- [ ] `MarkdownIngester` 處理 `claudeMd` / `agentsMd` / `geminiMd`（同邏輯，only path 不同）：
```swift
struct MarkdownIngester: Ingester {
    let parser: MultiStrategyMarkdownParser
    func fetch(source: Source) async throws -> [Card] {
        guard FileManager.default.fileExists(atPath: source.path.path) else { return [] }
        return try parser.parse(filePath: source.path, sourceId: source.id)
    }
}
```

- [ ] TDD：tempdir 建假 CLAUDE.md → 跑 → 驗 cards；missing path → 回 []（不 throw）
- [ ] commit：`feat(ingest): Ingester protocol + MarkdownIngester for *.md sources`

### Task 19：GitIngester (takes Set<String> snapshot) `[Spec §4.4, §4.6]`

**Files:**
- Create: `Pulse/Ingest/GitIngester.swift`, `PulseTests/Ingest/GitIngesterTests.swift`

> **Threading**：Ingesters 跑在 background；`Settings: ObservableObject` 只能從 `@MainActor` 讀。所以 GitIngester 不持 Settings 引用，由 RefreshScheduler（@MainActor）在 dispatch 前快照 `enabledTypes: Set<String>` 傳進來。

- [ ] `GitIngester`：
```swift
struct GitIngester: Ingester {
    let enabledTypes: Set<String>   // 快照值，不依賴 Settings ObservableObject

    func fetch(source: Source) async throws -> [Card] {
        let stdout = try GitLogRunner.run(at: source.path)
        let repoLabel = source.path.lastPathComponent
        return ConventionalCommitsParser.parse(stdout: stdout,
                                                sourceId: source.id,
                                                repoLabel: repoLabel,
                                                enabledTypes: enabledTypes)
    }
}
```

- [ ] TDD：
  - tempdir git init + commit `feat: x` → fetch with enabled=`["feat"]` → 1 卡
  - 同上 + `docs: y` → enabled=`["feat"]` → 1 卡（docs 被過濾）
  - enabled=`["feat", "docs"]` → 2 卡
  - 非 git repo 路徑 → throw
- [ ] commit：`feat(ingest): GitIngester takes Set<String> snapshot (decoupled from Settings)`

---

## Phase 6：AutoSourceDetector

### Task 20：AutoSourceDetector + skiplist `[Spec §6.4, §13.3]`

**Files:**
- Create: `Pulse/Ingest/AutoSourceDetector.swift`, `PulseTests/Ingest/AutoSourceDetectorTests.swift`

- [ ] API：
```swift
struct DetectedProject {
    let dir: URL
    let detectedFiles: [SourceKind]   // claudeMd / agentsMd / geminiMd
    let lastModified: Date
    let isGitRepo: Bool
}

struct AutoSourceDetector {
    static let scanRoots: [URL] = [
        URL(fileURLWithPath: NSHomeDirectory() + "/Desktop"),
        URL(fileURLWithPath: NSHomeDirectory() + "/Projects"),
        URL(fileURLWithPath: NSHomeDirectory() + "/code"),
        URL(fileURLWithPath: NSHomeDirectory() + "/Developer"),
        URL(fileURLWithPath: NSHomeDirectory() + "/Documents"),
    ]
    static let skipDirNames: Set<String> = [
        "node_modules", ".git", ".venv", "venv", "__pycache__",
        "dist", "build", "target", "vendor", ".next", ".cache",
        "DerivedData", ".DS_Store", ".pytest_cache", ".tox"
    ]
    static let detectedFilenames = ["CLAUDE.md", "AGENTS.md", "GEMINI.md"]

    func scan(depth: Int = 2, progress: ((Int, Int) -> Void)? = nil) async -> [DetectedProject]
}
```

- [ ] 實作：BFS 到 `depth` 層；skip skipDirNames；找 `detectedFilenames` 任一存在 → 收 dir
- [ ] git 偵測：dir 含 `.git/` → `isGitRepo = true`
- [ ] TDD：tempdir 建假目錄樹（含 node_modules / 含 CLAUDE.md / 含巢狀 monorepo）→ 驗 detected list 正確、跳過 skiplist
- [ ] commit：`feat(ingest): AutoSourceDetector with skiplist + depth control`

### Task 21：parallel scan + cancellable `[Spec §11]`

**Files:**
- Modify: `Pulse/Ingest/AutoSourceDetector.swift`

- [ ] 加 `withTaskGroup(of: [DetectedProject].self)` 並行掃 5 個 root
- [ ] 接受 `Task.checkCancellation()` 中斷
- [ ] progress callback `(scanned, total)` 用於 UI
- [ ] TDD：模擬 1000+ 假目錄 → 跑 → 在 < 2s 完成；cancel 後不再回 callback
- [ ] commit：`feat(ingest): parallel scan + cancellation in AutoSourceDetector`

---

## Phase 7：App Scaffold + Menubar

### Task 22：MenubarIconController `[Spec §4.1, §6.1]`

**Files:**
- Create: `Pulse/UI/MenubarIconController.swift`
- Modify: `Pulse/App/AppDelegate.swift`

- [ ] `MenubarIconController.swift`：
```swift
import AppKit
import SwiftUI

@MainActor
final class MenubarIconController {
    private let statusItem: NSStatusItem
    let popover: NSPopover   // 公開以便外部（⚙ 按鈕）關閉

    init(rootView: AnyView) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        popover = NSPopover()
        popover.behavior = .transient   // 失焦自動關（含切換到別的 app）
        popover.animates = true
        popover.contentSize = NSSize(width: 400, height: 600)
        popover.contentViewController = NSHostingController(rootView: rootView)

        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "waveform.path.ecg",
                                 accessibilityDescription: "Pulse")
            image?.isTemplate = true   // 自動配深淺色 menubar
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
            NSApp.activate(ignoringOtherApps: true)   // 啟用 app 才能收 keyboard events
        }
    }

    func updateRootView(_ rootView: AnyView) {
        popover.contentViewController = NSHostingController(rootView: rootView)
    }
}
```

- [ ] AppDelegate.applicationDidFinishLaunching：建立 controller，rootView = `Text("Pulse v0.1 — popover placeholder")`（後續 Task 25 換成 PopoverContentView，用 `updateRootView()`）
- [ ] 實機 verify：
  - 看到 menubar icon（淺色 menubar 是黑、深色 menubar 是白 — `isTemplate` 生效）
  - click 開 placeholder popover
  - 點 Finder / 桌面 → popover 自動關（`.transient`）
  - popover 開啟後 Esc / Tab / 上下鍵有反應（`NSApp.activate` 生效）
- [ ] commit：`feat(ui): NSStatusItem + NSPopover with template icon + activate-on-open`

> **Drop NSEvent.addGlobalMonitorForEvents**（reviewer S3）：`popover.behavior = .transient` 已自動處理外部點擊 dismiss；額外加 NSEvent monitor 是 cargo cult、會持 app 生命週期 leak。
>
> **⚙ 按鈕同 app 內 dismiss 議題**：transient 在 user 開同 app 的 settings window 時不會自動關 popover（同 app focus 不算失焦）。Task 25 PopoverHeaderView 的 ⚙ 按鈕 onTap 要顯式 `popover.performClose(nil)` 後再 open settings。

---

## Phase 8：Refresh Scheduler + FSEvents

### Task 23：RefreshScheduler timer + force refresh `[Spec §4.7]`

**Files:**
- Create: `Pulse/Ingest/RefreshScheduler.swift`, `PulseTests/Ingest/RefreshSchedulerTests.swift`

- [ ] API：
```swift
@MainActor
final class RefreshScheduler: ObservableObject {
    private let sourceStore: SourceStore
    private let cardStore: CardStore
    private let parser: MultiStrategyMarkdownParser
    private let settings: Settings    // 只在 main 讀取做快照，不傳給 ingesters
    @Published var lastRefreshAt: Date?
    @Published var isLoading: Bool = false       // popover 顯示 scanning 狀態用
    @Published var loadingProgress: (done: Int, total: Int) = (0, 0)

    func start() async         // app 啟動呼叫；跑 initial + 起 5 分鐘 timer
    func forceRefresh() async  // 全 source refresh
    func refresh(_ source: Source) async   // 單 source（FSEvents trigger 用）
}
```

- [ ] **Threading**：
  - `RefreshScheduler` 是 `@MainActor`，讀 Settings 取 `enabledTypes` 快照（`Set<String>`）
  - 構造 `GitIngester(enabledTypes: snapshot)` 然後 `Task.detached` 跑 `fetch(source:)` 在 background
  - 結果 await 回 main 寫進 cardStore
- [ ] 5 分鐘 timer 用 `Task { while !Task.isCancelled { try await Task.sleep(...) ; await forceRefresh() } }`
- [ ] parallel limit 4 用 `withThrowingTaskGroup` + counter
- [ ] `forceRefresh()` 開頭 `isLoading = true`，更新 progress；結束 `isLoading = false`
- [ ] TDD：
  - `refresh(_)` 呼叫對應 ingester、寫進 cardStore
  - `forceRefresh()` 處理多 source
  - **isLoading 進場 / 出場**：呼叫 `forceRefresh` 時 isLoading 變 true，完成變 false
  - **enabledTypes snapshot 隔離**：refresh 開始後 user 改 Settings preset → 該次 refresh 仍用舊 preset；下次 refresh 才看到新 preset（避免 race）
- [ ] commit：`feat(ingest): RefreshScheduler with snapshot + isLoading state`

### Task 24：FSEventStream on parent dir + debounce `[Spec §4.7]`

**Files:**
- Create: `Pulse/Ingest/FileWatcher.swift`, `PulseTests/Ingest/FileWatcherTests.swift`
- Modify: `Pulse/Ingest/RefreshScheduler.swift`

> **Why FSEventStream not DispatchSource**：vim / VSCode / BBEdit / Sublime 等編輯器存檔模式是 atomic-rename（寫 tmp 檔 → `rename(2)` 蓋原檔）。對單檔的 `DispatchSource.makeFileSystemObjectSource` watcher 持有的 fd 在 rename 後失效，watcher 收到 `.delete` event 後就**靜默死**，再也不 fire。FSEventStream 對父目錄 watch + filter 對應檔名才能撐住此 pattern，這是 Apple 官方推薦做法。

- [ ] `FileWatcher` 用 `FSEventStreamCreate` 對 markdown 檔的**父目錄**watch：
```swift
import CoreServices

final class FileWatcher {
    private var stream: FSEventStreamRef?
    private let parentDir: URL
    private let targetFilename: String
    private let onChange: () -> Void
    private var debounceTask: Task<Void, Never>?

    init(fileURL: URL, onChange: @escaping () -> Void) {
        self.parentDir = fileURL.deletingLastPathComponent()
        self.targetFilename = fileURL.lastPathComponent
        self.onChange = onChange
    }

    func start() {
        var context = FSEventStreamContext(version: 0, info: Unmanaged.passUnretained(self).toOpaque(),
                                             retain: nil, release: nil, copyDescription: nil)
        let pathsToWatch = [parentDir.path] as CFArray
        let flags = UInt32(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes)
        let callback: FSEventStreamCallback = { _, info, count, eventPaths, eventFlags, _ in
            guard let info = info else { return }
            let watcher = Unmanaged<FileWatcher>.fromOpaque(info).takeUnretainedValue()
            let paths = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue() as! [String]
            for path in paths where (path as NSString).lastPathComponent == watcher.targetFilename {
                watcher.scheduleDebounce()
                return
            }
        }
        stream = FSEventStreamCreate(nil, callback, &context, pathsToWatch,
                                      FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
                                      0.5, flags)
        if let s = stream {
            FSEventStreamSetDispatchQueue(s, DispatchQueue.main)
            FSEventStreamStart(s)
        }
    }

    private func scheduleDebounce() {
        debounceTask?.cancel()
        debounceTask = Task { @MainActor [onChange] in
            try? await Task.sleep(nanoseconds: 1_000_000_000)   // 1s debounce
            if Task.isCancelled { return }
            onChange()
        }
    }

    func stop() {
        if let s = stream {
            FSEventStreamStop(s); FSEventStreamInvalidate(s); FSEventStreamRelease(s)
        }
        stream = nil
        debounceTask?.cancel()
    }

    deinit { stop() }
}
```

- [ ] RefreshScheduler 維護 `[UUID: FileWatcher]`（per markdown source）
- [ ] sources 變動時 reset watchers（stop 舊的、start 新的）
- [ ] TDD：
  - tempdir 寫檔 → trigger callback in <2s
  - 連續寫 3 次（< 1s 內） → 只 trigger 1 次（debounce）
  - **atomic rename test**：寫 `tmp.md` → `rename` 成 `target.md` → trigger callback（這正是 DispatchSource 會 fail 的場景）
  - watcher stop 後不再 fire
- [ ] commit：`feat(ingest): FileWatcher with FSEventStream on parent dir (survives atomic rename)`

---

## Phase 9：Popover UI (SwiftUI)

### Task 25：PopoverContentView shell `[Spec §6.2]`

**Files:**
- Create: `Pulse/UI/PopoverContentView.swift`, `Pulse/UI/PopoverHeaderView.swift`, `Pulse/UI/PopoverFooterView.swift`
- Modify: `Pulse/App/AppDelegate.swift`（real rootView）

- [ ] `PopoverContentView`：
```swift
struct PopoverContentView: View {
    @ObservedObject var scheduler: RefreshScheduler
    @ObservedObject var cardStore: CardStore
    let sourceStore: SourceStore
    let onSettingsTap: () -> Void   // 由 owner 注入：close popover then open settings
    @State private var filter: CardFilter = .all
    enum CardFilter { case all, todo, done }

    var body: some View {
        VStack(spacing: 0) {
            PopoverHeaderView(
                onSettings: onSettingsTap,
                onRefresh: { Task { await scheduler.forceRefresh() } }
            )
            FilterBar(filter: $filter)

            if scheduler.isLoading && cardStore.cards.isEmpty {
                LoadingPlaceholderView(progress: scheduler.loadingProgress)
            } else if cardStore.cards.isEmpty {
                EmptyStateView()   // 提示「請設定第一個 source」按鈕
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(grouped, id: \.label) { group in
                            ProjectGroupView(group: group, filter: filter)
                        }
                    }
                    .padding(.horizontal, 12)
                }
            }
            PopoverFooterView(stats: stats, lastRefreshAt: scheduler.lastRefreshAt,
                              isLoading: scheduler.isLoading)
        }
        .frame(width: 400, height: 600)
    }

    private var grouped: [ProjectGroup] {
        // 1. filter cards by `filter` state (all/todo/done)
        // 2. group by sourceId → label (look up Source.label via sourceStore)
        // 3. within each group sort: todo first, then done by completedAt desc
        let sources = sourceStore.load()
        let labelById = Dictionary(uniqueKeysWithValues: sources.map { ($0.id, $0.label) })
        let filtered = cardStore.cards.filter { card in
            switch filter {
            case .all:  return true
            case .todo: return card.status == .todo
            case .done: return card.status == .done
            }
        }
        let byLabel = Dictionary(grouping: filtered) { labelById[$0.sourceId] ?? "Unknown" }
        return byLabel.map { (label, cards) in
            let sorted = cards.sorted { lhs, rhs in
                if lhs.status != rhs.status { return lhs.status == .todo }
                return (lhs.completedAt ?? .distantPast) > (rhs.completedAt ?? .distantPast)
            }
            // 取該 label 對應的 sources 集合，並判斷是否有缺檔
            let groupSources = sources.filter { labelById[$0.id] == label }
            return ProjectGroup(label: label, sources: groupSources, cards: sorted)
        }.sorted { $0.label < $1.label }
    }

    private var stats: PopoverStats {
        let cards = cardStore.cards
        let labels = Set(cards.compactMap { c in sourceStore.load().first(where: { $0.id == c.sourceId })?.label })
        return PopoverStats(
            projects: labels.count,
            todos: cards.filter { $0.status == .todo }.count,
            dones: cards.filter { $0.status == .done }.count
        )
    }
}

struct PopoverStats { let projects: Int; let todos: Int; let dones: Int }
```

- [ ] `LoadingPlaceholderView`：顯示「掃描中 \(progress.done) / \(progress.total) 專案」+ ProgressView spinner
- [ ] `EmptyStateView`：顯示「尚未設定任何 source」+「打開設定」按鈕
- [ ] `PopoverFooterView` 顯示「N 專案 · M 待辦 · K 完成 · 2 分前更新」（loading 中改顯示「掃描中…」）
- [ ] `onSettingsTap` 由 AppDelegate 注入：先 `popover.performClose(nil)` 再 `NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)`（標準 macOS 開 Settings scene）
- [ ] commit：`feat(ui): PopoverContentView shell with loading + empty states`

### Task 26：ProjectGroupView + CardRowView + 缺檔狀態 `[Spec §6.2, §7]`

**Files:**
- Create: `Pulse/UI/ProjectGroupView.swift`, `Pulse/UI/CardRowView.swift`

- [ ] `ProjectGroupView`：
  - 標題 `📄 {label}`
  - **若 group.sources 任一 path 不存在**（user 移走專案）→ header 旁加 ⚠ + 「來源遺失」灰字
  - cards list（按 status 排序：todo 先、done 後）
  - 缺檔時 group 仍顯示舊 cache 的 cards 但全部 dimmed (`.opacity(0.5)`)，避免 user 以為資料消失
- [ ] `CardRowView`：
  - todo 顯示 `○ {title}`；done 顯示 `✓ {title}`（淡灰）
  - 行尾 date `(MM-DD)` 灰色字
  - body 不展開（hover tooltip 顯示完整 body 100 字內 preview，v2+）
  - hover background `.gray.opacity(0.1)`
- [ ] **檢查缺檔**：用 `FileManager.default.fileExists(atPath:)` 檢查 markdown source path；git source 檢查 `.git/` 子目錄
- [ ] click → `onTapGesture { openSourceRef(card) }`（下一 task 實作）
- [ ] TDD：
  - group 含 missing source → ProjectGroupView body 包含「來源遺失」字串
  - 全 source 都正常 → 無「來源遺失」字串
- [ ] commit：`feat(ui): ProjectGroupView + CardRowView with missing-source visual`

### Task 27：openSourceRef (NSWorkspace.open) `[Spec §6.2 G5]`

**Files:**
- Create: `Pulse/UI/OpenSourceRef.swift`, `PulseTests/UI/OpenSourceRefTests.swift`

- [ ] markdown source → `NSWorkspace.shared.open(URL(fileURLWithPath: source.path.path))`
- [ ] git source → 試 `git -C path remote get-url origin`：
  - SSH `git@github.com:owner/repo.git` 解析成 `https://github.com/owner/repo/commit/<sha>`
  - HTTPS 同
  - 失敗 → fallback `Process` 開 Terminal `git -C path show <sha>`
- [ ] TDD：mock origin URL parse 函式測各種格式
- [ ] commit：`feat(ui): openSourceRef opens markdown in default editor / git in browser`

---

## Phase 10：Settings Window

### Task 28：SettingsView (3 tabs) + SourcesTab `[Spec §6.3]`

**Files:**
- Create: `Pulse/UI/Settings/SettingsView.swift`, `Pulse/UI/Settings/SourcesTab.swift`
- Modify: `Pulse/App/PulseApp.swift`（Settings scene rootView）

> **B 簡化方案**：3 tabs 而非 4。drop ParserTab（4 strategy 全 ON 不開放調整）。FiltersTab 從 10 個 toggle 收成 1 個 segmented control（Task 29）。

- [ ] `SettingsView`：
```swift
struct SettingsView: View {
    @StateObject private var settings = Settings()
    var body: some View {
        TabView {
            SourcesTab().tabItem { Label("Sources", systemImage: "list.bullet") }
            FiltersTab(settings: settings).tabItem { Label("Filters", systemImage: "line.horizontal.3.decrease") }
            AboutTab().tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 600, height: 460)
    }
}
```

- [ ] `SourcesTab`：list `[Source]` from SourceStore；row 含 enabled toggle、label edit、刪除按鈕；`+ 加 markdown source`（NSOpenPanel 選 .md 檔）/ `+ 加 git source`（NSOpenPanel 選資料夾）按鈕
- [ ] commit：`feat(ui): SettingsView with 3 tabs + SourcesTab`

### Task 29：FiltersTab (3-preset segmented control) `[Spec §6.3]`

**Files:**
- Create: `Pulse/UI/Settings/FiltersTab.swift`

- [ ] `FiltersTab`：
```swift
struct FiltersTab: View {
    @ObservedObject var settings: Settings
    var body: some View {
        Form {
            Section("Git commits 過濾") {
                Picker("過濾預設", selection: Binding(
                    get: { settings.gitFilterPreset },
                    set: { settings.gitFilterPreset = $0 }
                )) {
                    Text("Minimal — 只收 feat / fix").tag(GitFilterPreset.minimal)
                    Text("Recommended — feat / fix / refactor / perf").tag(GitFilterPreset.recommended)
                    Text("All — 全部 conventional commit type").tag(GitFilterPreset.all)
                }
                .pickerStyle(.inline)

                Text("變更後下次 refresh 才會生效。").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}
```

- [ ] commit：`feat(ui): FiltersTab with 3-preset git commit filter`

### Task 30：AboutTab + ⌘, hotkey verify `[Spec §6.3]`

**Files:**
- Create: `Pulse/UI/Settings/AboutTab.swift`

- [ ] `AboutTab`：版本字串（從 Info.plist `CFBundleShortVersionString`）+ Build (Internal / Public 由 `#if INTERNAL_BUILD` 切) + GitHub link + 開源 license
- [ ] 實機 verify：app 跑時按 ⌘, 開 Settings window
- [ ] commit：`feat(ui): AboutTab with version + build identification`

---

## Phase 11：Onboarding (通用版第一次啟動)

### Task 31：OnboardingView scan flow `[Spec §6.4]`

**Files:**
- Create: `Pulse/UI/OnboardingView.swift`, `Pulse/UI/OnboardingScanResultsView.swift`

- [ ] 第一頁：歡迎文案 + scan roots 列表 + `[開始掃描]` `[手動加路徑]`
- [ ] 第二頁（scan 完）：`[Detected]` 列表 + 每 row 含 path / 檔案類型（CLAUDE.md / AGENTS.md / GEMINI.md）/ lastModified（相對日期：「3 天前」「3 年前」）/ 勾選 toggle
- [ ] 預設勾選 lastModified < 90 天的；其餘預設不勾
- [ ] 「+ 手動加路徑」按鈕 → `NSOpenPanel` 選 dir → 加進 list
- [ ] commit：`feat(ui): OnboardingView with two-step scan flow`

### Task 32：onboarding 完成寫 sources.json + 進主 popover `[Spec §6.4]`

**Files:**
- Modify: `Pulse/App/AppDelegate.swift`, `Pulse/Core/Settings.swift`

- [ ] AppDelegate.applicationDidFinishLaunching：
  - 若 `Settings.firstRunCompleted == false` 且非 internal build → open onboarding window first，菜單列 icon 暫顯但 popover 顯示「先完成設定」
  - 完成 onboarding（user 按「完成」）→ 寫 sources.json、`firstRunCompleted = true`、close window、trigger initial refresh
- [ ] 實機 verify：刪 `~/Library/Application Support/Pulse/` → 跑 → onboarding 顯示
- [ ] commit：`feat(ui): wire onboarding to first-run + persist sources`

---

## Phase 12：Internal Build Flag

### Task 33：Internal.swift preloaded sources + first-run logic `[Spec §13.2]`

**Files:**
- Create: `Pulse/Build/Internal.swift`
- Modify: `Pulse/App/AppDelegate.swift`

- [ ] `Internal.swift`：
```swift
struct PreloadedProject {
    let path: String
    let label: String
}

enum HuangSunQuanProjects {
    #if INTERNAL_BUILD
    static let list: [PreloadedProject] = [
        .init(path: "/Users/sunquanhuang/Desktop/new_heterotopias", label: "Heterotopias"),
        .init(path: "/Users/sunquanhuang/Desktop/heterotopias-next", label: "Heterotopias Next"),
        .init(path: "/Users/sunquanhuang/Desktop/md-editor", label: "md-editor"),
        .init(path: "/Users/sunquanhuang/Desktop/pots-archive", label: "破週報"),
        .init(path: "/Users/sunquanhuang/Desktop/新大眾文藝", label: "新大眾文藝"),
        .init(path: "/Users/sunquanhuang/Desktop/矽盾週報", label: "矽盾週報"),
        .init(path: "/Users/sunquanhuang/Desktop/文化與技術三部曲", label: "文化與技術三部曲"),
        .init(path: "/Users/sunquanhuang/Desktop/writing-agent", label: "writing-agent"),
        .init(path: "/Users/sunquanhuang/Desktop/中國技術道路_2008_2028", label: "中國技術道路"),
    ]
    #else
    static let list: [PreloadedProject] = []
    #endif

    static func materialize() -> [Source] {
        list.flatMap { p in
            let dir = URL(fileURLWithPath: p.path)
            var sources: [Source] = []
            for filename in ["CLAUDE.md", "AGENTS.md", "GEMINI.md"] {
                let kind: SourceKind = filename == "CLAUDE.md" ? .claudeMd
                                     : filename == "AGENTS.md" ? .agentsMd
                                     : .geminiMd
                let filePath = dir.appendingPathComponent(filename)
                let exists = FileManager.default.fileExists(atPath: filePath.path)
                sources.append(Source(kind: kind, path: filePath, label: p.label,
                                       enabled: exists))
            }
            // git source
            let gitDir = dir.appendingPathComponent(".git")
            let isGit = FileManager.default.fileExists(atPath: gitDir.path)
            sources.append(Source(kind: .gitLog, path: dir, label: p.label, enabled: isGit))
            return sources
        }
    }
}
```

- [ ] AppDelegate first-run logic：
```swift
if !settings.firstRunCompleted {
    #if INTERNAL_BUILD
    let preloaded = HuangSunQuanProjects.materialize()
    try sourceStore.save(preloaded)
    settings.firstRunCompleted = true
    Task { await scheduler.forceRefresh() }
    #else
    showOnboarding()
    #endif
}
```

- [ ] 實機 verify：
  - Internal build 跑 → 預載 9 專案、popover 顯示資料、無 onboarding
  - Public build 跑 → onboarding 顯示
- [ ] commit：`feat(build): Internal build preloads 9 personal projects`

---

## Phase 13：Build / Ship

### Task 34：G7 read-only verification (byte-for-byte) `[Spec §2 G7]`

**Files:**
- Create: `Scripts/verify-readonly.sh`, `PulseTests/Integration/ReadOnlyVerificationTests.swift`

> G7 hard requirement：Pulse 不寫回 source（CLAUDE.md / AGENTS.md / GEMINI.md / git）。需要可重複的驗證 script 證明 byte-for-byte 不變。

- [ ] `Scripts/verify-readonly.sh`：
```bash
#!/usr/bin/env bash
# Run this script before launching Pulse and after running for N minutes.
# Captures sha256 + mtime of all source files; second run compares.
set -euo pipefail

MODE="${1:?Usage: verify-readonly.sh [snapshot|compare]}"
SNAPSHOT_FILE="${HOME}/.pulse-readonly-snapshot.json"

source_paths=(
  "${HOME}/Desktop/new_heterotopias/CLAUDE.md"
  "${HOME}/Desktop/heterotopias-next/CLAUDE.md"
  "${HOME}/Desktop/md-editor"  # no CLAUDE.md but watch git
  "${HOME}/Desktop/pots-archive/CLAUDE.md"
  "${HOME}/Desktop/新大眾文藝/CLAUDE.md"
  "${HOME}/Desktop/矽盾週報/CLAUDE.md"
  "${HOME}/Desktop/文化與技術三部曲/CLAUDE.md"
  "${HOME}/Desktop/writing-agent"
  "${HOME}/Desktop/中國技術道路_2008_2028/CLAUDE.md"
)

snapshot() {
  local out="["
  local first=1
  for p in "${source_paths[@]}"; do
    [[ -f "$p" ]] || continue
    local sha=$(shasum -a 256 "$p" | awk '{print $1}')
    local mtime=$(stat -f %m "$p")
    [[ $first -eq 0 ]] && out+=","
    out+="{\"path\":\"$p\",\"sha\":\"$sha\",\"mtime\":$mtime}"
    first=0
  done
  out+="]"
  echo "$out" > "$SNAPSHOT_FILE"
  echo "snapshot written: $SNAPSHOT_FILE"
}

compare() {
  [[ -f "$SNAPSHOT_FILE" ]] || { echo "no snapshot, run 'snapshot' first"; exit 1; }
  local fail=0
  for p in "${source_paths[@]}"; do
    [[ -f "$p" ]] || continue
    local sha=$(shasum -a 256 "$p" | awk '{print $1}')
    local mtime=$(stat -f %m "$p")
    local snap_sha=$(jq -r ".[] | select(.path==\"$p\") | .sha" "$SNAPSHOT_FILE")
    local snap_mtime=$(jq -r ".[] | select(.path==\"$p\") | .mtime" "$SNAPSHOT_FILE")
    if [[ "$sha" != "$snap_sha" || "$mtime" != "$snap_mtime" ]]; then
      echo "❌ MODIFIED: $p"
      echo "   sha:   $snap_sha → $sha"
      echo "   mtime: $snap_mtime → $mtime"
      fail=1
    else
      echo "✅ $p"
    fi
  done
  exit $fail
}

case "$MODE" in
  snapshot) snapshot ;;
  compare)  compare ;;
  *) echo "Usage: $0 [snapshot|compare]"; exit 1 ;;
esac
```

- [ ] `chmod +x Scripts/verify-readonly.sh`
- [ ] **驗證流程**：
  1. `./Scripts/verify-readonly.sh snapshot`
  2. 啟動 Pulse internal build；放著 5 分鐘讓它 refresh + FSEvents 跑
  3. 關 Pulse
  4. `./Scripts/verify-readonly.sh compare` → 全部 ✅ = G7 達成
- [ ] **單元測試** `ReadOnlyVerificationTests.swift`：
  - tempdir 建假 CLAUDE.md（含 todo）
  - 跑 MarkdownIngester.fetch
  - 驗證該檔案的 sha256 + mtime 跟跑 ingester 之前一致
- [ ] commit：`test: add G7 read-only byte-for-byte verification`

### Task 35：build-dmg.sh `[Spec §4.3]`

**Files:**
- Create: `Scripts/build-dmg.sh`

- [ ] 內容：
```bash
#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:?Usage: build-dmg.sh <version> [internal|public|both]}"
BUILD_KIND="${2:-both}"

build_one() {
  local kind="$1"
  local config="Release-$( [[ "$kind" == "internal" ]] && echo Internal || echo Public )"
  local suffix="$( [[ "$kind" == "internal" ]] && echo "-internal" || echo "" )"
  local dmg="build/Pulse-${VERSION}${suffix}.dmg"

  rm -rf build/staging
  mkdir -p build/staging

  xcodebuild -project Pulse.xcodeproj -scheme Pulse \
    -configuration "$config" \
    -derivedDataPath build/dd-${kind} \
    clean build

  cp -R "build/dd-${kind}/Build/Products/${config}/Pulse.app" build/staging/

  hdiutil create -volname "Pulse ${VERSION}" \
    -srcfolder build/staging \
    -ov -format UDZO "$dmg"

  echo "✅ $dmg"
}

case "$BUILD_KIND" in
  internal) build_one internal ;;
  public)   build_one public ;;
  both)     build_one public; build_one internal ;;
  *) echo "Unknown kind: $BUILD_KIND"; exit 1 ;;
esac
```

- [ ] `chmod +x Scripts/build-dmg.sh`
- [ ] commit：`build: add build-dmg.sh for internal+public dmg`

### Task 36：CHANGELOG + README finalize `[Spec §13]`

**Files:**
- Create: `CHANGELOG.md`
- Modify: `README.md`, `HANDOFF.md`

- [ ] `CHANGELOG.md` v0.1.0 section（含 Phase 1-12 highlights）
- [ ] `README.md` 補：
  - 安裝說明（從 GitHub release 下載 `Pulse-0.1.0.dmg`）
  - 第一次啟動 onboarding 說明
  - 支援的 source 格式（CLAUDE.md / AGENTS.md / GEMINI.md / git log conventional commits）
  - 4 個 parser strategies 簡介
  - 螢幕截圖 placeholder（Verification Log 截圖填入）
- [ ] `HANDOFF.md` 寫成 v0.1 ship 後的狀態（給未來 session 接手）
- [ ] commit：`docs: CHANGELOG + README + HANDOFF for v0.1.0`

### Task 37：tag v0.1.0 + GitHub release (public dmg only, with bundle ID safety) `[Spec §11 risk]`

**Files:**
- Create: `Scripts/release.sh`

> reviewer N6：release script 必須**檢查 dmg 內 app 的 bundle ID** = `com.huangsunquan.pulse`（公開版），不是 `com.huangsunquan.pulse.internal`，避免誤把 internal build 推上 GitHub release。

- [ ] 跑 `./Scripts/build-dmg.sh 0.1.0 both` → 產 `build/Pulse-0.1.0.dmg` + `build/Pulse-0.1.0-internal.dmg`
- [ ] 全 verification log（§Verification Log）填完
- [ ] `Scripts/release.sh`：
```bash
#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:?Usage: release.sh <version>}"
DMG="build/Pulse-${VERSION}.dmg"
EXPECTED_BUNDLE_ID="com.huangsunquan.pulse"

[[ -f "$DMG" ]] || { echo "Public dmg not found: $DMG"; exit 1; }

# Mount dmg, inspect bundle ID
MOUNT=$(hdiutil attach -nobrowse -readonly "$DMG" | tail -1 | awk '{print $3}')
trap "hdiutil detach '$MOUNT' >/dev/null" EXIT
ACTUAL_BUNDLE_ID=$(plutil -p "$MOUNT/Pulse.app/Contents/Info.plist" \
  | awk -F'"' '/CFBundleIdentifier/ {print $4}')

if [[ "$ACTUAL_BUNDLE_ID" != "$EXPECTED_BUNDLE_ID" ]]; then
  echo "❌ Bundle ID mismatch: expected $EXPECTED_BUNDLE_ID, got $ACTUAL_BUNDLE_ID"
  echo "   This dmg may be the internal build. Refusing to publish."
  exit 1
fi
echo "✅ Bundle ID correct: $ACTUAL_BUNDLE_ID"

# Tag
git tag -a "v${VERSION}" -F - <<EOF
v${VERSION} — Pulse

跨專案 todo / done 自動 monitor menubar app。

支援格式：CLAUDE.md / AGENTS.md / GEMINI.md / git log conventional commits
通用版 onboarding 自動掃常見路徑。讀取，不寫回。
EOF
git push origin "v${VERSION}"

# GitHub release (public dmg only)
gh release create "v${VERSION}" \
  --title "Pulse v${VERSION}" \
  --notes-file CHANGELOG.md \
  "$DMG"
```

- [ ] `chmod +x Scripts/release.sh`
- [ ] 跑 `./Scripts/release.sh 0.1.0`
- [ ] internal dmg 留 `build/Pulse-0.1.0-internal.dmg`，user 自用安裝（不上 release）
- [ ] commit：`build: release script with bundle-ID safety check`

---

## Verification Log（每 task 過 → 截圖貼此）

| Task | 測試項 | 結果 | 備註 |
|---|---|---|---|
| 4 | xcodebuild Debug-Public 跑通 |  |  |
| 14 | MultiStrategyParser 對 fixture (heterotopias-sample.md) 抓 cards 數正確 |  |  |
| 14 | lineNumber drift 回歸測試（前面塞空行 → cards id 不變） |  |  |
| 19 | GitIngester 跑 tempdir feat/fix 卡（無 docs/chore 雜訊） |  |  |
| 22 | menubar icon 顯示且 isTemplate 配深淺 menubar |  |  |
| 22 | popover 點別處關閉（`.transient`） |  |  |
| 22 | popover 開啟後可 keyboard event（NSApp.activate 生效） |  |  |
| 24 | 改 CLAUDE.md → < 2s popover 反映（debounce 1s + FSEventStream） |  |  |
| 24 | atomic rename 存檔（vim/VSCode 模擬）→ FSEventStream 仍 fire |  |  |
| 25 | popover loading 狀態顯示「掃描中 N/M」 |  |  |
| 25 | empty state 顯示「請設定第一個 source」按鈕 |  |  |
| 26 | popover 顯示 9 專案、todo + done 分區、source missing dimmed |  |  |
| 27 | click markdown card → 開預設 markdown editor |  |  |
| 27 | click git card → 開 GitHub commit URL |  |  |
| 30 | ⌘, 開 Settings window |  |  |
| 30 | Settings 3 tabs（Sources / Filters / About）顯示正確 |  |  |
| 31 | Public build 第一次跑 → onboarding 顯示 |  |  |
| 33 | Internal build 第一次跑 → 預載 9 專案 |  |  |
| 33 | Internal build 啟動後 30 秒內 popover 顯示資料（G2 budget） |  |  |
| 34 | `verify-readonly.sh snapshot/compare` 跑 5 分鐘後 → 9 source byte-for-byte 一致 |  |  |
| 35 | build-dmg.sh both 產 Pulse-0.1.0.dmg + Pulse-0.1.0-internal.dmg |  |  |
| 37 | release.sh bundle ID check 拒絕 internal dmg；接受 public dmg |  |  |
| 37 | GitHub release 只含 public dmg（gh release view 確認） |  |  |

---

## Spec Coverage

| Spec section | Plan task |
|---|---|
| §1 背景動機 (含 user persona) | 整體 framing |
| §2 G1 menubar popover | Task 22, 25-26 |
| §2 G2 全自動 ingest | Task 33 (internal preload) + Task 31-32 (public onboarding) |
| §2 G3 markdown 5s 反映 | Task 24 (FSEventStream + debounce) |
| §2 G4 git 5min 反映 | Task 23 (5-min timer) |
| §2 G5 點 item 跳原檔 | Task 27 |
| §2 G6 個人版 / 通用版 | Task 31-33 |
| §2 G7 不寫回 | Task 34 (verify-readonly.sh) + 全 plan 無 write API on source paths |
| §3 非目標 | 遵守 |
| §4.1 NSStatusItem + Popover | Task 22 |
| §4.2 不用 MenuBarExtra | Task 22 註明 |
| §4.3 build flag | Task 2 (xcconfig) + Task 33 (Internal.swift) |
| §4.4 source kinds | Task 5 (enum) + Task 18-19 (ingesters) |
| §4.5 Multi-strategy parser | Task 10-14 |
| §4.6 Conventional commits | Task 15-17 |
| §4.7 refresh 策略 | Task 23-24 |
| §4.8 identity & dedup | Task 7 (drop lineNumber) + Task 14 (normalize-then-hash) |
| §5.1 Source | Task 5-6 |
| §5.2 Card + cache schema versioning | Task 7-8 |
| §5.3 ProjectGroup | Task 25-26（顯示用，無 storage） |
| §6.1 menubar icon | Task 22 (SF Symbol + isTemplate) |
| §6.2 popover layout (含 loading + empty state + missing source) | Task 25-27 |
| §6.3 settings window (3 tabs) | Task 28-30 |
| §6.4 onboarding | Task 31-32 |
| §6.5 個人版跳過 | Task 33 |
| §7 失敗模式 | Task 18 (missing path), 21 (cancellation), 24 (debounce + atomic rename), 26 (UI 顯示 missing) |
| §8 與 Nacelle 切割 | 不 import；DesignTokens 複製不依賴 |
| §9 測試策略 | TDD 散在 Task 5-24 + 實機 verify Task 22-37 |
| §10 成功指標 | Verification Log |
| §11 風險 | Task 16 (PATH), 21 (cancellation), 23 (timer), 37 (release bundle ID check) |
| §13 附錄 (file list) | 全 plan |
| §14 決議紀錄 | 全 plan 對齊 |

---

## Risk Register

| Risk | Mitigation |
|---|---|
| Markdown 格式約定 user 寫不一致 | Task 14 dedup + 多 strategy 互補 |
| FSEventStream 漏 event | Task 23 5-min timer 保底 |
| FSEventStream 對單檔 watch 失效 | Task 24 改 watch 父目錄 + filter 檔名 |
| git log Process spawn PATH 找不到 git | Task 16 PATH-aware 找 binary（系統 git / Homebrew arm64 / Homebrew x86_64） |
| Sandbox 限制 Process | Sandbox v0.1 不開（`com.apple.security.app-sandbox = NO`），完全不影響 |
| 個人版誤 publish 到 GitHub release | Task 37 release.sh 檢查 dmg 內 bundle ID，mismatch 則 abort |
| menubar icon 用戶找不到 | Task 31 onboarding 文字提示「螢幕右上角」+ macOS 預設讓新加 icon 浮現 |
| LSUIElement 設了反悔（要 main window） | xcconfig 切，需要 debug 用 internal build 加 main window flag（v2+） |
| Card.id lineNumber drift 破壞 cache | Task 7 drop lineNumber，hash 用 path+heading+normalizedTitle |
| @AppStorage 無法注入 ephemeral UserDefaults | Task 9 改用 init-injection UserDefaults |
| Cards cache schema 升級時 crash | Task 8 version 欄位 + decode fail → cold start |
| Settings reference 跨 actor 競態 | Task 19/23 改 pass `Set<String>` 快照 |

---

## Out of Scope (v0.1)

- 全域熱鍵（cmd+shift+P 開 popover）
- GitHub issues / PRs ingest
- `.cursorrules` / `.github/copilot-instructions.md` 解析
- 系統通知（NSUserNotification）
- iOS / iPadOS companion
- 雙向同步（寫回 CLAUDE.md）
- App Store 上架
- Plugin 機制
- i18n / 多語介面
- Sparkle 自動更新
- Homebrew cask 分發
