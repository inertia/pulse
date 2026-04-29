# CHANGELOG

## v0.4.0：Settings 重新掃描 Desktop (2026-04-29)

### 新增功能

- **Settings → SourcesTab 加「重新掃描 Desktop」按鈕（Q4）**：點開跳 modal，重跑 `AutoSourceDetector` 掃 `~/Desktop` `~/Projects` `~/code` `~/Developer` `~/Documents`，filter 掉 sources.json 已涵蓋的 dirs，剩下用 OnboardingScanResultsView 給 user 勾選新專案。完成後 merge 進既有 sources.json（不替換）。
- 新檔 `Pulse/UI/Settings/RescanWindow.swift`：`RescanWindowController` + `RescanView`（scanning → results phase machine）。
- `SourcesTab.existingDirs(from:)` static helper：算「現在 sources.json 涵蓋的 project dirs」（markdown → parent dir，gitLog → dir as-is），canonical `.path` 字串去重。

### 技術重點

- Test suite 194 → 196 green（+2 SourcesTab 測試）。Critical：`testExistingDirs_dedupsAcrossKinds` 鎖 URL trailing-slash 邊界 — `URL.deletingLastPathComponent()` 補 trailing slash 但 `URL(fileURLWithPath:)` 不補，同一 dir 經兩條路徑 hash 進 Set 不相等，dedup 失效。改 Set<String> of `.path` 解。
- 個人版 Internal hardcoded list 蓋掉需求**已內建**：first-run materialize → save sources.json → `firstRunCompleted = true`，之後 sources.json 為 truth source。User 可在 SourcesTab 直接刪 / 改既有 entry。

### 修正

無（純新增功能）。

### 升級備註

無 schema 變動。直接 build Release-Internal + 替換 /Applications/Pulse Internal.app 即可。

### 已知限制

- Q4 optional 拖檔加專案沒做（觀察 Rescan 按鈕用得順不順再決定）。

---

## v0.3.0：Overview tab + 公開版英文化 + icon 修整 (2026-04-29)

### 新增功能

- **Overview tab（Q6）**：ProjectTabBar 最左加「總覽」/「Overview」pseudo-pill，app 啟動時預設選中。內容：
  - 一句話 digest「今天完成 N　outstanding M　X 個專案待處理」（amber 強調 outstanding）
  - 🔴 URGENT outstanding section（cross-project，每張卡 = dot indicator + project chip + agent badge + relative age）
  - 🟡 HIGH outstanding section（同上）
  - 完成 last 24h（git commit + pulse.md `[x]` 並列；agent badge 區分 git / pulse / claude / agents / gemini / quick）
  - 完成 last 7d（disclosure 折疊，預設關；點開 chronological list；24h ↔ 7d 邊界用 half-open `(lower, upper]` 不重疊）
- **Priority 偵測（Q6）**：兩條路徑同時吃。Title 開頭 `🔴`/`🟡` emoji；section heading 含 `🔴`/`🟡`（`### 🔴 URGENT / P0`）由 `MultiStrategyMarkdownParser.normalize()` 注入 `priority-urgent`/`priority-high` synthetic tag。Cache schema v1 不動。
- **Brand tokens**：`Pulse/Brand/Colors.swift` 落地 designer pulse-handoff 主色（amber `#ffa940` / amberDeep / slate `#1a1f2e` / surface2）。Q6 元件統一從這 reference。
- **公開版英文（Q3）**：個人版 (Pulse Internal.app) 維持中文，公開版 (Pulse.app) 全英文。compile-time switch via `#if INTERNAL_BUILD`。46 處 user-facing string 集中在 `Pulse/Resources/Strings.swift`（`enum L` + private `bilingual(zh:en:)`）。
- **Header 快捷鍵補完（Q5-B）**：`.keyboardShortcut("r", modifiers: .command)` 補上 Refresh、`.keyboardShortcut(",", modifiers: .command)` 補上 Settings。Tooltips 對齊 ⌘R / ⌘, / ⌘Q。click-outside dismiss（Q5-A）已在 v0.2 final ship。

### 技術重點

- Test suite 186 → 194 green
  - 5 cases for Q6 baseline aggregator + sentinel
  - 1 case for priority-from-synthetic-tag detection（CardStoreTests）
  - 1 case for priority-from-section-heading injection（MultiStrategyMarkdownParserTests）
  - 1 case for half-open boundary on chained 24h/7d windows
- `CardStore` extension 拆 static helpers (`filterCards` / `cardsCompletedWithin` / `digest`) + instance wrapper：靜態接受 `[Card]` 給 OverviewView 合併 cardStore + quickTodoStore，instance 給單元測試
- OverviewView body 入口 once cache `cards` 跟 `sources`，row helpers 接 `sources` 參數，避免 N 卡的場景 2N 次 disk read

### 修正

- **Menubar icon 白底巨大（Q8）**：之前 `menubar_44.png` 是 88×44 pixel + 四角 RGBA(255,255,255,255) opaque white（qlmanage 對 stroke-only SVG 補白底是 macOS Quick Look 默認行為）。改 22×22 viewBox + PIL 直接畫透明底 PNG（`Scripts/render-menubar-icon.py`）。
- **Code review 抓的 2 BUG**：
  - Settings tooltip 寫「(⌘,)」但沒實際 wire keyboardShortcut（補上）
  - URGENT/HIGH section 在實機 9 專案 pulse.md 全部空，因 emoji 在 section heading 不在 bullet（加 section-heading-derived tag）

### 升級備註

- 個人版升級：build Release-Internal + cp 到 /Applications，cards-cache.json schema 不動，sources.json 不動。app 重啟後 RefreshScheduler 會重 parse 跑出新的 priority tag。
- 公開版升級：build Release-Public dmg。`#if INTERNAL_BUILD` 自動切 English；既有 user 升級時 cards-cache.json 會被 normalized priority tag 取代（cache key 一樣，schema 一樣）。
- v0.2 → v0.3 沒有 manual migration 步驟。

### 已知限制

- 個人版 9 專案還是 hardcoded 在 `Internal.swift`，要砍 / 加只能改 Swift 重 build（v0.4 Q4 補 Settings 增刪專案）
- 公開版 onboarding 後沒地方再重掃 Desktop（v0.4 Q4 補）
- Overview tab 只看 priority；medium / 🟢 / 無 emoji 的 todo 不在 URGENT/HIGH section（會散在 per-project tab）

---

## v0.2.0：todo lifecycle 補完 (2026-04-28)

### 新增功能

- **完整 todo 生命週期**（Q1）：CLAUDE.md hook 從只教「加 todo」擴成加 + 完成 + 刪除三段
  - 完成觸發語：「X 完成」/「X 做完了」/「X 結了」/「done X」/「finished X」→ Claude Code 把 `- [ ]` 改 `- [x] (done YYYY-MM-DD)`
  - 刪除觸發語：「幫我刪掉 X」/「不要這條 X」/「拿掉 X」/「remove X」/「drop X」→ 整行 remove
- **自動清理過期完成項**：`PulseFileMaintenance` 每次 `RefreshScheduler.forceRefresh()` 尾端掃所有 pulse.md，把 `- [x] (done YYYY-MM-DD)` 且 date > 30 天的整行刪除（commit log 已涵蓋歷史）
- **既有專案 hook 同步**：`Scripts/update_existing_hooks.py` 一次性同步 8 個個人專案 CLAUDE.md hook block；`ensureHook()` idempotent 不會自動推送內容更新，所以 hookBlock 改動後跑這 script

### 技術重點

- Test suite 179 → 186 green（PulseFileMaintenanceTests 7 cases：keeps non-marker / within window / removes past window / preserves structure / malformed date / trailing newline / writes only changed files）
- E2E 驗：38 天前 fixture line 寫入 md-editor pulse.md → forceRefresh on launch 整行刪除確認

### 升級備註

- 個人版升級：launch 後 hook 內容自動套用既有 8 個 CLAUDE.md（v0.1 已 onboarding 過的）；`PulseFileMaintenance` 只清 `(done ...)` marker 的行，bootstrap 既有 `- [x]` 不動
- 公開版升級：first-run user 走 onboarding 收到新 hook；既有 user 升級時 ensureHook idempotent 不蓋舊 hook，需要 user 自己跑 script 或刪 hook 段重新進 onboarding

### 已知限制

- 個人版 9 專案還是 hardcoded 在 `Internal.swift`，要改要重 build（v0.3 Q4 補 Settings 增刪專案）
- 公開版 onboarding 後沒地方再重掃 Desktop（v0.3 Q4 補）
- 公開版 UI 仍中文 hardcoded（v0.3 Q3 補英文 via `#if INTERNAL_BUILD`）

---

## v0.1.0：首版 (2026-04-28)

### 新增功能

- **跨專案 todo / done 自動 monitor**：menubar app（NSStatusItem + NSPopover），點 icon 展開 popover 看跨專案進度
- **多 source 格式支援**：
  - CLAUDE.md / AGENTS.md / GEMINI.md（markdown checkbox、emoji、numbered、section heading 共 4 種 strategy）
  - Git log conventional commits（feat / fix / refactor / perf / chore / docs / build / ci / style / test）
- **個人版**（INTERNAL_BUILD）：預載 9 個進行中的專案，啟動立即顯示
- **公開版**：第一次啟動 onboarding，掃描 ~/Desktop / ~/Projects / ~/code / ~/Developer / ~/Documents 找含 CLAUDE.md / AGENTS.md / GEMINI.md 的目錄，給使用者勾選
- **設定面板**（⌘,）：3 tabs（Sources / Filters / About）；Sources 增刪 source；Filters 切換 git commit preset（Minimal / Recommended / All）
- **自動 refresh**：FSEventStream watch markdown source 父目錄（撐住 vim / VSCode atomic-rename 存檔），1 秒 debounce；5 分鐘保底 timer for git
- **唯讀**：Pulse 不寫回 source 檔（G7 byte-for-byte 驗證 via `Scripts/verify-readonly.sh`）

### 技術重點

- Swift 5.9 + SwiftUI 4 + AppKit
- macOS 14 (Sonoma) 以上
- xcodegen + xcconfig 雙 build（Internal preload / Public onboarding）
- 177 unit + integration tests covering parsers / stores / ingesters / scheduler / file watcher
- Cards-cache schema versioning（避免升級 Card schema 後 crash）
- @MainActor 邊界清楚（RefreshScheduler 主，ingester 拿 Set<String> snapshot）

### 已知限制

- v0.1 menubar icon 用 SF Symbol `waveform.path.ecg` 暫代；正式 icon 待設計
- v0.1 不支援全域熱鍵開 popover（v0.2 規劃）
- v0.1 不支援 GitHub issues / PRs ingest（v2+ 規劃，需 token）
- v0.1 onboarding 沒有「+ 手動加路徑」於結果頁（v0.2 補；welcome 頁有提示）
- `Scripts/verify-readonly.sh` 需要 `jq`（macOS 預設無，`brew install jq`）

### 開源

- MIT License
- GitHub：https://github.com/inertia/pulse
- Author：黃孫權 (Huang Sun-Quan)
