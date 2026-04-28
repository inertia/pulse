# Pulse · 跨專案 todo / done 自動 monitor menubar app · Design

| 項目 | 值 |
|---|---|
| 日期 | 2026-04-28 |
| 階段 | Design 完成，待 implementation plan |
| 作者 | 黃孫權 + Claude (Opus 4.7) |
| 狀態 | 待 user 審核 |
| 對應 | Nacelle v2 Phase B 衍生（從 kanban target 獨立成新 product） |

---

## 1. 背景與動機 (Context)

黃孫權同時推進 8+ 個專案，每個都在 macOS 本機 Desktop 有獨立目錄。每個專案的「進行中工作 / 已完成工作」分散於：

- `CLAUDE.md` 的 `Planned Work` / `Recently Done` 段落（含個人風格的 `- ✅` / `### URGENT` 數字編號項）
- `git log` 的 conventional commits

每天要看跨專案進度時，目前只能靠記憶 + 手動開個別 CLAUDE.md / 跑 `git log`。對於：

- 黃孫權自己（用 Claude Code 跨多 repo 研究／開發）
- **研究者**（用 Claude Code 寫論文 / 整理資料 / 分析 corpus）
- **Semi-coder**（不專業，但用 AI 協作管理多 codebase）

這個族群的共同需求：「**全自動把多個專案的 todo / done 攤在眼前**」，不需手動輸入、不必切到 GitHub / Linear。

Nacelle v2 原本想把這個功能塞進 kanban app 的「自動」分頁，但 user 要求 **Nacelle 主體保持簡單輕量**，因此把這個功能獨立成新 product `Pulse`。

Pulse 的策略定位：**Claude Code 用戶（含 Codex / Cursor / Gemini CLI 用戶）的跨專案 dashboard menubar app**。

### 1.1 為何選 menubar 形態

- read-only 全自動 monitor 的天然形態：點 menubar icon 展開、再點別處就收回，不佔螢幕
- 跟 Nacelle kanban 主視窗哲學切割：Nacelle 是「擁有 / 編輯 / 計畫」、Pulse 是「監看 / 提醒」
- macOS 慣例 semi-coder 熟悉：系統本身就有類似工具
- 無 dock icon 干擾：常駐瞄一眼工具不該佔 dock

### 1.2 為何不放 Raycast extension

- Raycast 是商業 launcher，user 要先付費 / 安裝 Raycast，多一道門檻
- Raycast extension 沒「常駐瞄一眼」體驗，要主動觸發
- 自製 menubar app 對 semi-coder 更直覺（macOS 本身就懂）

### 1.3 為何不用 SaaS / Web app

- 跨專案資料是本機 markdown + git，無需 server
- semi-coder 不想設帳號 / 訂閱
- 隱私：資料不離開本機

---

## 2. 目標 (Goals)

| # | 目標 | 驗收方式 |
|---|---|---|
| G1 | menubar icon 點擊展開 popover，顯示跨專案 todo / done list | 啟動 → 看到 menubar icon → click → popover 含 todo / done |
| G2 | 全自動 ingest，啟動後不需手動輸入即顯示資料 | 個人版啟動後 30 秒內顯示 8 專案；通用版完成 onboarding 後立即顯示 |
| G3 | CLAUDE.md / AGENTS.md / GEMINI.md 變動時 5 秒內反映 | 改 CLAUDE.md 加一條 todo → popover 5 秒內出現 |
| G4 | git commit 變動時 5 分鐘內反映 | push `feat:` commit → popover 5 分鐘內出現 |
| G5 | 點 todo / done item → 跳到原檔（NSWorkspace.open） | click markdown item → 開預設編輯器；click git item → 開 GitHub URL |
| G6 | 個人版預載 8 專案；通用版第一次啟動 onboarding 列偵測到的 source | 個人版 dmg 跑起來自動有資料；通用版第一次啟動進 onboarding |
| G7 | 不寫回 source（CLAUDE.md / AGENTS.md / GEMINI.md / git） | 用 mtime + content hash 驗證 byte-for-byte 一致 |

---

## 3. 非目標 (Non-Goals)

- 不做 main window app（純 menubar）
- 不做雙向同步（Pulse 純讀）
- 不做 GitHub issues / PRs ingest（v1 無 token 機制）
- 不做帳號管理 / 雲端 sync（資料是本機衍生，每機獨立）
- 不替代 Nacelle kanban / Things 3 / OmniFocus（不收手動 todo）
- 不做 iOS / iPad（純 macOS）
- 不做 i18n（v1 中文 + 英文 hardcoded UI text；正式國際化留 v2）
- 不做 plugin 機制（v1 內建固定 source kinds）
- 不上 App Store（v1 沙箱不開、用 GitHub release 分發）

---

## 4. 技術選擇

### 4.1 NSStatusItem + NSPopover

- `NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)` 註冊 menubar icon
- click → 顯示 NSPopover 內含 SwiftUI view
- click 別處 → popover 自動 dismiss（`.behavior = .transient`）
- `LSUIElement = YES` in Info.plist → 無 dock icon、無 cmd-tab

### 4.2 為何不用 SwiftUI MenuBarExtra

macOS 13+ 的 SwiftUI MenuBarExtra 也能做，但：
- popover 大小客製較難（MenuBarExtra default 受限）
- 動畫客製性差
- v1 用 NSStatusItem + NSPopover 更可控；UI 內部仍用 SwiftUI

### 4.3 個人版 / 通用版 build flag

xcconfig：

```
// xcconfig/Pulse-Internal.xcconfig
GCC_PREPROCESSOR_DEFINITIONS = $(inherited) INTERNAL_BUILD=1
SWIFT_ACTIVE_COMPILATION_CONDITIONS = $(inherited) INTERNAL_BUILD
PRODUCT_BUNDLE_IDENTIFIER = com.huangsunquan.pulse.internal
INFOPLIST_KEY_CFBundleDisplayName = Pulse Internal

// xcconfig/Pulse-Public.xcconfig (default)
PRODUCT_BUNDLE_IDENTIFIER = com.huangsunquan.pulse
INFOPLIST_KEY_CFBundleDisplayName = Pulse
```

Swift 端：

```swift
#if INTERNAL_BUILD
let preloadedSources: [PreloadedProject] = HuangSunQuanProjects.list
#else
let preloadedSources: [PreloadedProject] = []
#endif
```

CI：`Scripts/build-dmg.sh` 跑兩次（含 / 不含 `-internal` 旗標），產 `Pulse-0.1.0-internal.dmg` 跟 `Pulse-0.1.0.dmg`。Internal dmg 不 publish 到 GitHub release（local 自用）。

### 4.4 Source kinds (v1)

| Kind | 路徑 | Parser |
|---|---|---|
| `claudeMd` | `<project>/CLAUDE.md` | MultiStrategyMarkdownParser |
| `agentsMd` | `<project>/AGENTS.md` | MultiStrategyMarkdownParser |
| `geminiMd` | `<project>/GEMINI.md` | MultiStrategyMarkdownParser |
| `gitLog` | `<project>` (git repo dir) | ConventionalCommitsParser |

未來 v2+ 可加：`.cursorrules`、`.github/copilot-instructions.md`、`AGENT_RULES.md` 等。

### 4.5 MultiStrategyMarkdownParser

讀 markdown 檔，啟用多個 strategy 抽 todo / done cards。每個 strategy 獨立可組合：

| Strategy | 抓什麼 | 範例 |
|---|---|---|
| `CheckboxStrategy` | `- [ ] X` / `- [x] X` 標準 markdown checkbox（最通用） | `- [ ] 重建 OCR pipeline` |
| `EmojiCheckmarkStrategy` | `- ✅ X`（done）/ `- ⏳ X`（in-progress 不收）/ `- ❌ X`（cancelled 不收） | `- ✅ R2 圖片搬遷` |
| `NumberedSectionStrategy` | `### URGENT/HIGH/MEDIUM/LOW` 段內 `1. **X**` 編號項當 todo；`### Recently Done` 段內當 done | `1. **P0-1 schema drift** — body...` |
| `SectionHeadingStrategy` | `## To Do` / `## Planned Work` / `## Recently Done` / `## Done` 段標題 + 段內 `- X` 一律收為 todo / done | `## Recently Done\n- ✅ 修 bug` |

設定面板可勾哪些 strategy 啟用。預設全部開。Strategy 之間互補，不重複收同一條（identity hash 去重）。

### 4.6 ConventionalCommitsParser

- 跑 `git log --pretty=%H%x09%aI%x09%s%x09%b -n 100`
- regex 過濾：`^(feat|fix|refactor|perf|chore|docs|build|ci|style|test)(\([^)]*\))?:\s+`
- type=`docs` / `chore` 預設不收（雜訊）
- card title = subject 第一行
- card body = subject 後面 + commit body
- card.completed = commit author date
- card.tags = `[<repo-name>, <type>]`

### 4.7 Refresh 策略

| 觸發 | 行為 |
|---|---|
| App 啟動 | 全 source 跑一次（async, parallel limit 4） |
| FSEventStream on markdown source 父目錄 | 該 source re-parse (debounce 1s) |
| 每 5 分鐘 timer | 所有 git source re-fetch |
| Popover ⟳ 按鈕 | 全 source 強制重跑 |

> **檔案 watch 為何 watch 父目錄而非單檔**：vim / VSCode / BBEdit 等編輯器 atomic-rename 存檔（寫 tmp → rename 蓋原檔）；對單檔的 `DispatchSource` watcher fd 會失效，watcher 靜默死。FSEventStream 對父目錄 + `kFSEventStreamCreateFlagFileEvents` 撐住 atomic rename。
>
> **menubar context menu「立即重整」punt 到 v0.2**：右鍵 NSStatusItem 設 `menu` 會跟左鍵 `action` 衝突，需額外狀態機；v0.1 只用 popover 內 ⟳ 按鈕。

### 4.8 Identity 與 dedup

- markdown card identity = SHA256(path + sectionHeading + normalizedTitle)
- `normalizedTitle` 是 title 經行尾日期解析、`#tag` 抽取、trim 空白後的純 title
- 不含 `lineNumber`：避免 user 在檔案上方插一行 → 所有後續 cards id 全變 → cache 失效
- git card identity = commit SHA
- 跨 strategy dedup：同一 source 內若兩 strategy 抓到 hash 相同 → 收一次
- 跨 source dedup：不嘗試（同一 todo 在 CLAUDE.md 跟 AGENTS.md 都寫 = user 故意，照顯示）

---

## 5. 資料模型

### 5.1 Source

```swift
enum SourceKind: String, Codable {
    case claudeMd, agentsMd, geminiMd, gitLog
}

struct Source: Identifiable, Codable, Equatable {
    let id: UUID
    let kind: SourceKind
    let path: URL              // file path for *.md, dir path for gitLog
    let label: String          // user-friendly project name
    let enabled: Bool
}
```

存 `~/Library/Application Support/Pulse/sources.json`。

### 5.2 Card

```swift
enum Status: String, Codable { case todo, done }

struct Card: Identifiable, Equatable {
    let id: String              // stable hash for identity
    let sourceId: UUID
    let title: String
    let body: String?
    let status: Status
    let dueDate: Date?
    let completedAt: Date?
    let sourceRef: String       // file:line OR commit SHA
    let tags: [String]
}
```

In-memory + cache `~/Library/Application Support/Pulse/cards-cache.json`。

**Cache schema versioning**：cache root 帶 `version: Int` 欄位（v0.1 = 1）。`CardStore.load()` decode 失敗或 version mismatch → 視為 cold start：清空 cache、首次 refresh 重建。避免改 Card schema 後 user 升級 app 即 crash。

**JSONEncoder dateEncodingStrategy = .iso8601**（pin 死，避免不同 Swift 版本預設不同）。

### 5.3 ProjectGroup（顯示用）

```swift
struct ProjectGroup {
    let label: String           // 從 source label 推導
    let sources: [Source]
    let cards: [Card]
}
```

UI 顯示時按 label group，不存檔。

---

## 6. UX

### 6.1 Menubar icon

- 形狀：v1 用 SF Symbol `waveform.path.ecg` 暫代；正式版找設計師另出構想
- `image.isTemplate = true` 讓 icon 自動配合 light / dark menubar
- 暖米色 / 灰階搭配（matches Nacelle palette）
- 有更新時 icon 旁邊小 badge 數字 → punt 到 v0.2（v0.1 只顯示 icon）

### 6.2 Popover layout (default 400 × 600)

```
┌──────────────────────────────────────┐
│ Pulse                          ⚙  ⟳  │   ← header (settings + refresh)
├──────────────────────────────────────┤
│ [全部]  [待辦]  [已完成]              │   ← filter toggle
├──────────────────────────────────────┤
│ 📄 new_heterotopias                   │   ← project group header
│   ✓ 22 本書 zh/en 落地 (4-24)         │
│   ✓ types.ts drift 修完 (4-24)        │
│   ○ 跨篇書目 dict 拍板               │
│   ○ 6 本無源待補書                    │
│                                       │
│ 📄 矽盾週報                           │
│   ✓ W03 雙版本週報節奏 (4-19)         │
│   ○ W04 收束日機制                    │
│                                       │
│ ...                                   │
├──────────────────────────────────────┤
│ 8 專案 · 12 待辦 · 47 完成 · 2 分前更新│   ← footer status
└──────────────────────────────────────┘
```

- click item → NSWorkspace.open 跳到原檔
  - markdown source → 開預設 markdown editor（macOS 預設）
  - git source → `git remote get-url origin` 解析 GitHub URL → open browser to commit page；無 origin 時 fallback 到 Terminal `git show <sha>`
- ⚙ → 開設定 window；同時 `popover.performClose(nil)`（避免 settings 開了 popover 還掛在那）
- ⟳ → 強制 refresh
- popover 失焦自動關閉（`behavior = .transient`）
- **Loading 狀態**：first-run 或 `forceRefresh()` 進行中，popover 顯示「掃描中 N/M」placeholder（避免空清單誤導 user）
- **Source missing 狀態**：source path 不存在（user 移走專案）→ 該 group header 顯示 ⚠ + 「來源遺失」+ row 灰階 dimmed，user 可右鍵移除或更新路徑

### 6.3 設定 window (NSWindow, ⌘,)

3 tabs（精簡版，避免 14 toggle 嚇到 semi-coder 用戶）：

1. **Sources** — 列現有 source、加 / 刪 / enable / disable / 改 label
2. **Filters** — 一個 segmented control 三選一：
   - `Minimal`：只收 `feat` `fix`（最低雜訊）
   - `Recommended`（預設）：`feat` `fix` `refactor` `perf`
   - `All`：所有 conventional commit type（feat / fix / refactor / perf / chore / docs / build / ci / style / test）
3. **About** — 版本資訊 / build (internal / public) / GitHub link / 開源聲明

> **設計判斷**：4 個 strategy toggle 對 user 沒實質意義（user 看不懂 strategy 名字、無法 diagnose 誤判），預設全 ON 不開放調整。10 個 git type toggle 對「研究者 / semi-coder」過工程，收成 3 個 preset。日後 v2 若需細調再加 Advanced tab。

### 6.4 通用版 onboarding (第一次啟動)

第一頁：

```
歡迎使用 Pulse
跨專案 todo / done 自動 monitor。

我會掃以下路徑找含 CLAUDE.md / AGENTS.md / GEMINI.md 的目錄：
  ~/Desktop/*
  ~/Projects/*
  ~/code/*
  ~/Developer/*
  ~/Documents/*

[開始掃描]   [手動加路徑]
```

第二頁（掃描結果）：

```
找到 14 個專案：

☑ ~/Desktop/my-project          CLAUDE.md
☑ ~/Desktop/research-corpus     AGENTS.md
☐ ~/Desktop/old-archive         CLAUDE.md (3 年前)
☐ ~/Projects/temp-experiment    CLAUDE.md
...

[+ 手動加路徑]                    [完成]
```

每行右側註明：檔案類型（CLAUDE.md / AGENTS.md / GEMINI.md）+ 最後修改時間（讓 user 判斷是否還在用）。

完成後寫入 sources.json 並進主 popover。

### 6.5 個人版 onboarding (跳過)

啟動時 SourceStore 偵測 sources.json 是否存在：
- 不存在 → 從 `Build/Internal.swift` 的 `HuangSunQuanProjects.list` 寫入 sources.json
- 存在 → 維持

直接進 popover，不跑 onboarding flow。

---

## 7. 失敗模式

| 失敗 | 偵測 | 處理 |
|---|---|---|
| Markdown 找不到（user 移走專案） | FileManager.fileExists | row dimmed + ⚠️ icon；popover 顯示「來源遺失」；user 可移除或更新路徑 |
| Git log 失敗（不是 git repo / permission） | Process exit code != 0 | 該 source 顯示 missing |
| Markdown 格式不符 | parser 回 [] | 該 source 顯示 0 卡，不爆；popover footer 顯示 hint |
| Popover 開時 source list empty | 通用版第一次未完成 onboarding | 顯示「請設定第一個 source」按鈕跳設定面板 |
| FSEvents 量大 | debounce 1s | 不過載 |
| User 把 menubar icon 隱藏（Bartender） | 無法偵測 | v2 加全域熱鍵 fallback；v1 documented limitation |
| Onboarding 掃路徑很慢（user 有 1000 個資料夾） | parallel scan + progress bar | UI 顯示「掃描中 N/M」；可中斷 |

---

## 8. 與 Nacelle 的關係

**完全切割**。Pulse 跟 Nacelle 不共用 codebase、不共用資料、不共用設定、不共用 release。唯一共用：

- Design tokens (palette / 字型 / 圓角 / spacing) — Pulse 直接複製 Nacelle 的暖米色 palette + Source Han Serif 字型，**不 import** Nacelle codebase
- 哲學一致：暖、紙感、不花俏；但兩個 product 將來 visual identity 可分流

兩個 app 可同時跑互不干擾（不同 bundle ID、不同 Application Support 目錄）。

---

## 9. 測試策略

### 9.1 單元測試

| 測試項 | 方法 |
|---|---|
| MultiStrategyMarkdownParser × 4 strategy | 餵不同 markdown 驗 cards |
| ConventionalCommitsParser | mock git log 輸出驗 cards |
| Identity stable | 同 source 跑兩次 cards identical |
| 跨 strategy dedup | 餵雙 strategy 都會抓的內容驗只收一次 |
| 個人版 vs 通用版 | mock `INTERNAL_BUILD` flag 驗 preloadedSources |
| Source missing | 不 crash |
| AutoSourceDetector 掃路徑 | tempdir 模擬數十個資料夾驗找出含 *.md 的 |

### 9.2 整合測試

| 測試 | 步驟 |
|---|---|
| End-to-end CLAUDE.md ingest | tempdir 建假 CLAUDE.md → onboarding → popover 顯示 |
| End-to-end AGENTS.md ingest | 同上但 AGENTS.md |
| End-to-end git ingest | tempdir git init + commit → 偵測到 → popover 顯示 |
| FSEvents 反應 | 改檔 → 5 秒內 popover 更新 |
| 不寫回 | mtime + content hash 跑前後一致 |
| 雙 build 同時跑 | Pulse-Internal + Pulse-Public 同時啟動互不干擾 |

### 9.3 實機 verify (UI)

xcodebuild + 單元測試覆蓋不到的 UI runtime 行為（依 memory `feedback_verified_vs_unverified_in_completion.md`）：

- menubar icon 顯示
- click 展開 popover
- popover 失焦關閉
- 點 item 跳原檔
- onboarding 第一次跑（通用版）
- 設定 window tabs 切換

每項實機過 → 截圖貼 verification log。

---

## 10. 成功指標

ship v0.1.0 兩週後：

- ✅ 9 專案的 CLAUDE.md / git log 全 hooked up
- ✅ 沒手動加過 source（個人版預載 + 通用版自動掃）
- ✅ 改 CLAUDE.md 後 5 秒內 popover 反映
- ✅ 沒寫回 source（mtime + content hash 測試）
- ✅ 沒影響 Nacelle 運作（不互相干擾）
- ✅ menubar icon 占用 <50MB RAM、idle <1% CPU

---

## 11. 風險

| 風險 | 嚴重度 | 緩解 |
|---|---|---|
| Markdown 格式約定散亂導致 parser 漏抓 | 中 | 多 strategy + 設定面板 lint warning |
| FSEvents 漏 event | 中 | 5 分鐘 timer 保底 |
| git log 量大噪音 | 低 | filter conventional commits + 限 100 筆 |
| menubar icon 用戶找不到 | 中 | onboarding 教 + system 通知首次顯示 |
| 個人版誤上 GitHub release | 高 | CI rule：`-internal` build 不 publish；release script 檢查 bundle ID |
| LSUIElement 設了反悔（要 main window） | 低 | xcconfig 切，需要 debug 用 internal build 加 main window flag |
| user 用 Bartender 隱藏 menubar icon | 低 | v2 加全域熱鍵 |
| 通用版 onboarding 掃路徑卡 (1000+ 資料夾) | 中 | 限制深度 2 + skiplist (node_modules/.git 等) + parallel + progress + 可中斷 |
| `git remote get-url origin` 失敗（local-only repo） | 低 | fallback 到 Terminal `git show` |

---

## 12. 後續延伸 (v2+)

- 全域熱鍵 (cmd+shift+P) 開 popover
- GitHub issues / PRs ingest (with token)
- `.cursorrules` / `.github/copilot-instructions.md` / `AGENT_RULES.md` 解析
- 通知：CLAUDE.md 加新 todo 跳系統通知（NSUserNotification）
- iOS / iPadOS companion (read-only)
- 雙向（在 Pulse 勾完成 → 寫回 CLAUDE.md `[x]`）— 高風險
- App Store 上架 (LSApplicationCategoryType = developer-tools)
- Plugin 機制（讓 user 自寫新 source kind）
- 中文 / 英文 i18n
- Pulse Pro：訂閱版 (合併寫回 + 通知 + 雲端 sync)
- Sparkle 自動更新
- Homebrew cask 分發

---

## 13. 附錄

### 13.1 實作位置 checklist (給 plan)

| 模組 | 動作 |
|---|---|
| `Pulse/App/PulseApp.swift` | NSApplicationDelegate + LSUIElement、註冊 NSStatusItem |
| `Pulse/UI/MenubarIconController.swift` | NSStatusItem 管理、icon 換色 |
| `Pulse/UI/PopoverContentView.swift` | SwiftUI popover 主視圖 |
| `Pulse/UI/PopoverFilterBar.swift` | 全部 / 待辦 / 已完成 toggle |
| `Pulse/UI/ProjectGroupView.swift` | 一個專案 group 的 list |
| `Pulse/UI/CardRowView.swift` | 單張 card 顯示 |
| `Pulse/UI/SettingsWindow.swift` | NSWindow + Tabs |
| `Pulse/UI/Settings/SourcesTab.swift` | sources 管理 |
| `Pulse/UI/Settings/FiltersTab.swift` | git filter preset 3 選一 segmented control |
| `Pulse/UI/Settings/AboutTab.swift` | 版本 / GitHub link |
| `Pulse/UI/OnboardingView.swift` | 通用版第一次掃描 |
| `Pulse/Core/Source.swift` | enum + struct + Codable |
| `Pulse/Core/SourceStore.swift` | sources.json 讀寫 |
| `Pulse/Core/Card.swift` | struct + identity hash |
| `Pulse/Core/CardStore.swift` | cards-cache.json 讀寫 + in-memory |
| `Pulse/Core/Settings.swift` | UserDefaults wrapper |
| `Pulse/Ingest/MultiStrategyMarkdownParser.swift` | 4 strategy 主類 + dedup |
| `Pulse/Ingest/Strategies/CheckboxStrategy.swift` | strategy 1 |
| `Pulse/Ingest/Strategies/EmojiCheckmarkStrategy.swift` | strategy 2 |
| `Pulse/Ingest/Strategies/NumberedSectionStrategy.swift` | strategy 3 |
| `Pulse/Ingest/Strategies/SectionHeadingStrategy.swift` | strategy 4 |
| `Pulse/Ingest/ConventionalCommitsParser.swift` | git log parser |
| `Pulse/Ingest/Ingester.swift` | protocol + claudeMd / agentsMd / geminiMd / gitLog impls |
| `Pulse/Ingest/RefreshScheduler.swift` | timer + FSEvents |
| `Pulse/Ingest/AutoSourceDetector.swift` | 通用版掃常見路徑 |
| `Pulse/Build/Internal.swift` | `#if INTERNAL_BUILD` 預載 sources |
| `Pulse/Resources/DesignTokens.swift` | palette / 字型 / spacing (從 Nacelle 複製) |
| `Pulse/Resources/Assets.xcassets/PulseIcon.imageset/` | menubar icon |
| `xcconfig/Pulse-Internal.xcconfig` | INTERNAL_BUILD=1 |
| `xcconfig/Pulse-Public.xcconfig` | (空 / default) |
| `xcconfig/Shared.xcconfig` | 共同 settings |
| `Scripts/build-dmg.sh` | 跑兩次 build 產 internal + public dmg |
| `Scripts/run-tests.sh` | unit + integration test runner |
| `project.yml` | xcodegen 配置 |
| `PulseTests/Ingest/*` | 各 parser 測試 |
| `PulseTests/Core/*` | model + store 測試 |
| `README.md` | 通用 README（給 GitHub） |
| `CLAUDE.md` | 給未來 Claude session 的 hint（簡略） |
| `HANDOFF.md` | 跨 session handoff |

### 13.2 個人版預載 source list

```swift
// Pulse/Build/Internal.swift
#if INTERNAL_BUILD
enum HuangSunQuanProjects {
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
}
#endif
```

每條會嘗試 4 個 source（claudeMd / agentsMd / geminiMd / gitLog）。沒對應檔案的會在 source list 中保留但 disabled（user 之後可手動 enable）。

### 13.3 通用版掃路徑清單

```swift
let scanRoots: [URL] = [
    URL(fileURLWithPath: NSHomeDirectory() + "/Desktop"),
    URL(fileURLWithPath: NSHomeDirectory() + "/Projects"),
    URL(fileURLWithPath: NSHomeDirectory() + "/code"),
    URL(fileURLWithPath: NSHomeDirectory() + "/Developer"),
    URL(fileURLWithPath: NSHomeDirectory() + "/Documents"),
]
let detectedFilenames = ["CLAUDE.md", "AGENTS.md", "GEMINI.md"]
let scanDepth = 2   // root 直接子目錄 + 巢狀 monorepo subprojects
let skipDirNames: Set<String> = [
    "node_modules", ".git", ".venv", "venv", "__pycache__",
    "dist", "build", "target", "vendor", ".next", ".cache",
    "DerivedData", ".DS_Store", ".pytest_cache", ".tox",
]
```

設定面板可手動加路徑（`+ 手動加路徑` 按鈕 → NSOpenPanel 選資料夾），depth 跟 skiplist 也可在「進階」分頁調整。

### 13.4 macOS deployment target

- macOS 14 (Sonoma)，與 Nacelle 一致
- 用 `@FocusState`、`AttributedString(markdown:)`、`.onChange(of:_:)`、SwiftUI 4

### 13.5 Bundle 結構

```
Pulse.app/
  Contents/
    Info.plist           (LSUIElement = YES)
    MacOS/Pulse
    Resources/
      Assets.car
      ...
```

`Info.plist` 關鍵 key：
- `LSUIElement = YES`
- `CFBundleDisplayName = Pulse` (or "Pulse Internal")
- `LSApplicationCategoryType = public.app-category.developer-tools`
- `NSHighResolutionCapable = YES`

---

## 14. 決議紀錄 (2026-04-28)

| # | 議題 | 決議 |
|---|---|---|
| 1 | Menubar icon | v1 用 SF Symbol `waveform.path.ecg` 暫代；正式版找設計師另出構想 |
| 2 | 個人版預載專案列表 | 9 條（見 §13.2）：原 8 個 + 中國技術道路_2008_2028 |
| 3 | 通用版 onboarding 掃路徑深度 | scanDepth = 2（root 直接子目錄 + 巢狀 monorepo subprojects） |
| 4 | AGENTS.md 規範假設 | v1 假設 user 自由格式，parser 全 strategy 跑能抓就抓 |
| 5 | 個人版 dmg 分發 | 個人版始終 private（local 自用，不上 GitHub release）；通用版功能完整後正式公共釋出 |
