# Handoff · last updated 2026-04-29 (v0.3 ship)

> 換 session 時讀這檔。**v0.3 已完工 single session**：Q3 公開版英文化、Q5-B 快捷鍵補完、Q6 Overview tab + cross-project digest、Q8 menubar icon transparent。下一輪做 **Q4：Settings 管理監控專案**（HANDOFF 已寫好 spec、觀察期已過）。

---

## TL;DR — v0.3 狀態

- 13 commits 在 local main，**未 push origin/main**（user 拍板才推）
- Pulse v0.3 內部版**已裝**在 `/Applications/Pulse Internal.app`，最新 commit `d7b831f`
- 194/194 tests green（v0.2.0 ship 時 186 → +5 Q6 baseline → +3 priority/boundary regression → 194）
- repo at `/Users/sunquanhuang/Desktop/pulse/`，私有 GitHub `https://github.com/inertia/pulse`
- 9 個個人專案 `pulse.md` + 8 個 `CLAUDE.md` hook block 都在
- **設計參考**：`/tmp/pulse-handoff/`（designer 2026-04-29 給）— 視覺 / brand 採納；session monitoring 產品定位**未採納**

### v0.3 上線新功能（user 一句話 review 看不出時翻這段）

1. **Overview tab**（最左 pill「總覽」/「Overview」+ outstanding 總數）：跨專案 digest 一句話、🔴 URGENT outstanding、🟡 HIGH outstanding、完成 last 24h、完成 last 7d (disclosure 折疊)。app 啟動時預設選中。
2. **Priority 偵測**從 title 開頭 emoji 跟 section heading（`### 🔴 URGENT`）兩條路徑都吃。實機 9 專案已驗 17 urgent + 6 high tag 對齊 ground truth。
3. **公開版 (Pulse.app) 全英文**，個人版 (Pulse Internal.app) 維持中文。compile-time switch via `#if INTERNAL_BUILD`，46 strings 集中在 `Pulse/Resources/Strings.swift`。
4. **Header 快捷鍵**：⌘, 開 Settings、⌘R 觸發 refresh、⌘Q quit；tooltip 都對齊。Q5-A click-outside dismiss 已 ship。
5. **Menubar icon** 22×22 透明底（之前 44×22 + 白底）。`Scripts/render-menubar-icon.py` 是 single source of truth。

---

## 方向決議（2026-04-29，不要再 re-litigate）

### 產品定位 = 跨專案 todo / done aggregator（**不是** session monitor）

User 評估 designer 的 session monitor 提案後決定：
- 「通知我 Claude session 在等輸入」**不是核心價值** — 開發者 / 研究者不會一直待在電腦旁；待在電腦旁自然會看到。
- **長期追蹤跨專案**才是 Pulse 該解的問題：「我可以 review 一下有什麼東西做了、什麼東西沒做」。
- 資料源穩定性 vs session schema fragility：CLAUDE.md hook + pulse.md + git log 是 user 自己的 markdown，不依賴 Anthropic / OpenAI 私有 schema。

不採納 designer spec 的部分：
- ❌ Session monitoring 產品定位（watch `~/.claude/sessions/` / `~/.codex/sessions/`）
- ❌ 4-state model `waiting/doing/queued/done`（session-specific）
- ❌ 通知系統（critical / standard 區分）
- ❌ Dashboard window（kanban + timeline + cost panel）
- ❌ Tauri / React / Rust / SQLite stack rewrite

採納 designer spec 的部分：
- ✅ App icon + menubar icon（amber pulse spike `#ffa940` on slate `#1a1f2e`，菜單列 template image）
- ✅ Brand 主色（amber + slate）— Q6 開始落地到 popover 元件
- ✅ Click-outside dismiss + ⌘W 行為（已修 Q5）
- ✅ Card pattern 參考（dot indicator + 分層 typography + 緊湊間距）— 落到 Q6
- ✅ `formatElapsed` / `formatTokens` / `formatRelative` helper 命名 — 之後 Swift 寫對應

### Stack = Swift / SwiftUI（不重寫）

不切 Tauri 即使 Tauri/React/Rust 對 AI 更順手。理由：
- v0.2 已 ship + 186 tests + 8 repo 已 onboard，重寫成本 2-3 週
- Designer 的 session monitor 才需要 dashboard / kanban / cost panel 那些重 UI；aggregator 不需要這麼多
- macOS 原生 menubar 體驗在 Swift / AppKit 比 Tauri tray 好（特別是 NSStatusItem / NSPopover）
- 累積在 Swift codebase 的 maintenance cost vs 重寫風險：選累積

### UX rethink — Shape A

User 點出 v0.2 的 IA mismatch：「跨專案 review」變成 9 個 tab 點過去看，方向反了。決議：

**Shape A — Overview tab + 保留 per-project drill-down**：
- 加一個 **Overview** tab 在 ProjectTabBar 最左，預設選中（first-launch + 之後）
- Overview 內容：
  - 頂部 digest 一句話（`今天完成 N 件 / outstanding M 件 / 4 個專案有東西未完成`）
  - 🔴 URGENT outstanding cross-project（每張卡掛 project chip + age）
  - 🟡 HIGH outstanding cross-project
  - 完成 last 24h（git commit + pulse.md `- [x]`，並列；project chip + 時間 stamp）
  - 完成 last 7d（disclosure 折疊）
- Per-project tabs 留作 drill-down，不變
- 用 designer 的 amber 色於 URGENT section、card pattern 於 done items

不選 Shape B（廢 tab 直接 status sections）的原因：reuse 現有 component、漸進演化；先看 Overview 用得多不多再決定要不要全砍 tab。

### 旁邊：CLAUDE.md → pulse.md content 整理（**進行中由另外的 AI 處理**）

User 2026-04-29 同步用另一個 AI session 把各專案 CLAUDE.md 裡的「待辦 / 願望」性質內容遷出，整合到 `<project>/pulse.md`。CLAUDE.md 留 stable 規範 / 架構，pulse.md 收 active todos。對 Pulse 的影響：
- pulse.md 內容會變多 / 變結構化 — Pulse 的 markdown ingester（CheckboxStrategy / EmojiCheckmarkStrategy / SectionHeadingStrategy）要繼續 robust，特別是看到 `## 願望 / ## To Do / ## Backlog` 等不同 section 標題時要正確 parse
- 下次 session refresh 後 card 數會跳很多 — 不是 bug，是 user 主動搬資料的結果

---

## 已完成的 v0.1（37 plan tasks + 大量迭代）

### Plan / Spec
- `docs/superpowers/specs/2026-04-28-pulse-design.md`
- `docs/superpowers/plans/2026-04-28-pulse-implementation.md`

### Ingest 架構
- `Pulse/Ingest/MultiStrategyMarkdownParser.swift`：3 strategy default（CheckboxStrategy / EmojiCheckmarkStrategy / SectionHeadingStrategy）
- `Pulse/Ingest/Strategies/NumberedSectionStrategy.swift` 保留但**不在 default**（user 拍板砍：URGENT/HIGH/MEDIUM 段觸發太多 false positive）
- `Pulse/Ingest/GitLogRunner.swift`：`--since=30 days ago`（user 拍板從 14 改 30）
- `Pulse/Ingest/ConventionalCommitsParser.swift`：feat/fix/refactor/perf default
- `Pulse/Ingest/RefreshScheduler.swift`：5 分鐘 timer + cardStore.save 每次 refresh

### UI（board-style popover）
- `Pulse/UI/PopoverContentView.swift`：tab bar + 選中專案 + 已完成折疊 + 快速記
- `Pulse/UI/ProjectTabBar.swift`：horizontal scroll pills
- `Pulse/UI/CardRowView.swift`：圓角背景 + hover + 無 body 顯示
- `Pulse/UI/QuickTodoComposer.swift`：+ 按鈕展開 → inline TextField + 專案 picker + 「寫進專案」按鈕

### pulse.md 體系
- `Pulse/Core/PulseQuickWriter.swift`：append todo to `<project>/pulse.md`
- `Pulse/Core/CLAUDEMdHookWriter.swift`：在 CLAUDE.md 加 delimited hook block（含 trigger phrases + 寫入格式）
- `Pulse/Core/QuickTodoStore.swift`：「📝 只記在 Pulse」用的 `quick-todos.json`
- `Pulse/Build/Internal.swift`：個人版 9 專案預載；每專案 5 sources（CLAUDE / AGENTS / GEMINI / pulse / git）

### 9 專案 bootstrap（subagent 平行完成）
- 各專案的 outstanding todos 已掃 + 整理進 `<project>/pulse.md`
- 8 個 CLAUDE.md 已加 `<!-- pulse-hook:start -->...<!-- pulse-hook:end -->` block（含完整 trigger phrase 規則）
- md-editor 沒 CLAUDE.md，hook 跳過
- Cache 狀態：**354 cards / 260 todos** 跨 9 projects

### Build
- xcconfig 雙 build：`Pulse-Public.xcconfig` + `Pulse-Internal.xcconfig`
- PRODUCT_NAME 切：個人版 `Pulse Internal.app`、公開版 `Pulse.app`（同 /Applications 可共存）
- `INFOPLIST_KEY_NSDesktopFolderUsageDescription` 在 Shared.xcconfig（TCC scope 只 Desktop）
- `Scripts/build-dmg.sh` / `Scripts/release.sh` / `Scripts/verify-readonly.sh`

### Tests：186/186 PASS（179 baseline + 7 PulseFileMaintenanceTests）

---

## 還沒做的（user 拍板，下 session 開工）

### Q1: pulse.md 已完成事項處理機制 — **完工 2026-04-28**（commits f6b69b3 / 2624d1e / 5dcb462 / 5fbfe35）

實際做的（user 拍板「直接刪除」、不做 Archive 段）：
1. ✅ `CLAUDEMdHookWriter.hookBlock()` 加完成 / 刪除規則段：
   - 完成觸發 → `- [x] (done YYYY-MM-DD) {原內容}`
   - 刪除觸發 → 整行 remove
2. ✅ 新檔 `Pulse/Core/PulseFileMaintenance.swift`：`cleanLines` (純 helper) + `cleanAgedDoneItems` (file IO)；regex `^- \[x\] \(done (\d{4}-\d{2}-\d{2})\)`，date > 30 天 → 整行刪除；malformed date / 無 marker 的 `- [x]` 不動
3. ✅ `RefreshScheduler.forceRefresh()` 尾端 wire-in：filter `path.lastPathComponent == "pulse.md"` 後跑 maintenance
4. ✅ `Scripts/update_existing_hooks.py`：sync 8 個現存 CLAUDE.md hook block；NEW_BLOCK 與 Swift `hookBlock()` byte-for-byte 一致（一次性 diff 驗過）
5. ✅ `PulseTests/Core/PulseFileMaintenanceTests.swift`：8 個 cases，179 → 186 tests green
6. ✅ E2E 驗：md-editor pulse.md 寫 38 天前 fixture line → build Release-Internal → install /Applications → launch → forceRefresh on launch 跑掉 fixture line（備份還原 OK）

下次擴 hook 內容的工作流：改 Swift `hookBlock()` → 把新 body 複製進 `Scripts/update_existing_hooks.py` 的 NEW_BLOCK → `python3 Scripts/update_existing_hooks.py`。

git log 不動：仍每次讀 git，commit 顯示為 done card 在 popover「已完成 (N) ▼」disclosure。pulse.md `- [x]` 跟 git commit done 並列顯示。

**為什麼不靠 commit 自動 mark done**：commit subject 跟 todo title 模糊比對誤殺成本高；保險走 hook 路。

### Q2: 速記寫進專案（已實作，user 只是 confirm）

`+ 快速記` 展開 → 選某專案 → 寫進 `<project>/pulse.md` `## To Do` 段。「📝 只記在 Pulse」= 存 `quick-todos.json`（跨專案 / 雜事）。

### Q3: 公開版英文化 — **完工 2026-04-29**（commit `d7b831f`）

實際做的：
1. ✅ 新增 `Pulse/Resources/Strings.swift`：`enum L { ... }` + private `bilingual(zh:en:)` helper 用 `#if INTERNAL_BUILD` 分流
2. ✅ 換掉 46 處 user-facing 中文字串 across 14 個 UI 檔（Onboarding / Popover / Overview / QuickTodoComposer / Settings 三 tab / EmptyState / LoadingPlaceholder / ProjectGroup / ProjectTabBar）
3. ✅ `QuickTodoConstants.label` 改 computed `var` 透過 `L.quickProjectLabel`：Internal「📝 快速記」/ Public「📝 Quick」。sourceId 是固定 UUID，cards-cache.json 跨 build 不會崩
4. ✅ Overview URGENT/HIGH 標題保留 emoji + 英文（兩 build 共用，emoji 跨語）
5. ✅ Build verified：Debug-Internal + Debug-Public 都 SUCCEEDED；194/194 tests green

不動的：
- `Build/Internal.swift` 9 個 hardcoded 專案 label：本來就在 `#if INTERNAL_BUILD` 內，public build 沒這份 list
- SectionHeading / NumberedSection / EmojiCheckmark strategies 的「待辦」/「已完成」keyword：那是 ingest 比對 user pulse.md heading 用，跟 build 無關，兩個 token 都該收

下次擴字串的工作流：加一條到 `enum L`（`static let foo = bilingual(zh: "...", en: "...")`），call site 寫 `Text(L.foo)`。動態 interpolation 用 `static func`。

### Q4: Settings → 管理監控專案 — **觀察 1-2 天後做**（2026-04-28 拍板）

現狀（user 痛點）：
- **個人版**：9 專案 hardcoded 在 `Pulse/Build/Internal.swift`，要砍 / 加只能改 Swift 重 build。日常用沒辦法自己增減。
- **公開版**：onboarding 第一次掃描勾選後就鎖定；之後沒地方再呼叫一次 scan，只能進 Settings → Sources tab 一條條手動管。

兩版都需要的功能（user 拍板「否則很難用」）：
- Settings 加「重新掃描 Desktop」按鈕，跳出 onboarding-style 結果視窗讓 user 補勾新專案 / 取消勾舊專案
- 個人版要能蓋掉 hardcoded list（讓 user 在 UI 改動，不用回 Internal.swift）
- 拖檔加專案考慮（拖一個資料夾進 popover 直接成 source，跳過掃描）

先觀察期 1-2 天看實際使用 pain points，再決定 scope。MVP 可能只做「重新掃描」按鈕，個人版 hardcoded list 改成 default 但允許覆寫。

### Q5: Popover header dismiss 行為 + 鈕辨識度（**A+B 都完工 2026-04-29**）

**A. Click-outside 不會 dismiss**：commit `b3a6136`（Q5-A）。原因是 `togglePopover()` show 完緊接 `NSApp.activate(ignoringOtherApps: true)`，吃掉 .transient 失焦訊號。fix = 拿掉 `NSApp.activate` 那行；popover SwiftUI 自己處理 keyboard event 不受影響。

**B. Header 三鈕語意混淆 — 縮 scope 解**（commits `b1782b6` + `f92b285`）：
- 只加 `.keyboardShortcut("r", modifiers: .command)` 到 Refresh 按鈕 + tooltip "Refresh now" → "Refresh (⌘R)"
- 加 `.keyboardShortcut(",", modifiers: .command)` 到 Settings 按鈕（之前 tooltip 寫 (⌘,) 但沒實際 wire；LSUIElement 無 menubar 不會 auto-route）
- ⏻ 跟 ⌘Q binding 維持原樣（user 原話「⏻ Quit 比較明顯」，沒換 power.circle）
- 沒加額外 chevron 收起鈕：A 修完 click-outside 已能 dismiss，多塞按鈕反而是噪音

HANDOFF Q5-B 原列三 a/b/c 候選，最終選最 minimal 的「補快捷鍵 + 對齊 tooltip」。

### Q6: Overview tab — 跨專案 digest（**完工 2026-04-29**，commits `69936e1` → `15acf44`）

實作完成 9 commits 跑完 Shape A：
1. ✅ `Pulse/Brand/Colors.swift`：amber `#ffa940` / amberDeep / slate `#1a1f2e` / surface2
2. ✅ `Pulse/Core/CardStoreAggregates.swift`：static `filterCards` / `cardsCompletedWithin` / `digest` 三個 helpers + instance wrapper（3 ways）
3. ✅ `Pulse/UI/Overview/`：OverviewView / DigestLineView / OverviewSection / CardChipView / Format.swift
4. ✅ `PopoverContentView` 整合：`selectedLabel: String? = ProjectTabBar.overviewLabel`，body 入口 once 算 cards / sources / 各 section，再 pass 給 row
5. ✅ `ProjectTabBar`：左側 inject Overview pseudo-pill，icon `square.grid.2x2.fill` + label「總覽」/「Overview」+ outstanding badge
6. ✅ Tests：CardStoreTests 加 4 cases（filtersByStatus / filtersByPriority / filtersByPriority_fromSyntheticTag / digestSummary_countsCorrectly）+ doneCardsLast 邊界 + halfOpenBoundary；OverviewViewTests 加 sentinel test。190 → 194。

**v0.3 踩到的關鍵坑（有獨立查核才發現）**：實機 9 專案 `pulse.md` 用 `### 🔴 URGENT / P0` heading + bullet 不帶 emoji，原本 `card.title.hasPrefix("🔴")` 完全抓不到。修法：`MultiStrategyMarkdownParser.normalize()` 從 `item.sectionHeading` 偵測 🔴/🟡 注入 `priority-urgent`/`priority-high` synthetic tag。`priority(of:)` 同時看 title prefix + tag。Cache schema 不動（schema v1 維持）。

驗證：cards-cache.json grep `priority-urgent` = 17 / grep `priority-high` = 6，跟 ground truth 對齊（heterotopias 5+6, 矽盾週報 12+0）。

**24h ↔ 7d boundary 不重疊**：`cardsCompletedWithin(_:hoursAgoLower:hoursAgoUpper:)` 用 half-open `(lower, upper]` 區間。Last 24h（lower=24, upper=0）跟 last 7d but not last 24h（lower=168, upper=24）對於完成於剛好 24h 前的卡只有後者收，前者跳過。

### Q7: 已完成軸的處理 — **完工 2026-04-29**（隨 Q6）

Per-project tab 仍維持 `已完成 (N) ▼` disclosure 折疊；Overview 內：last 24h 預設展開、last 7d 折疊（cross-project chronological，期待用 per-project drill-down 看細節）。

### Q8: Menubar icon — **完工 2026-04-29**（commit `3945700`）

修了 HANDOFF Q8 列的兩件事（candidate c：a+b 都做）：
1. ✅ artboard 改回 22×22；path 重新縮放到 `M 2,11 L 7,11 L 9,3 L 11,19 L 13,3 L 15,11 L 20,11`
2. ✅ render pipeline 改用 PIL（`Scripts/render-menubar-icon.py`）直接畫透明底 PNG，不走 qlmanage（會加白底）。22×22 跟 44×44（@2x）兩張，stroke 黑色 alpha=255、其他 pixel alpha=0。Verified 21.7% / 16.0% opaque、四角 RGBA(0,0,0,0)。

下次要動 icon shape：改 `Scripts/render-menubar-icon.py` 的 `PULSE_POINTS` / `stroke`，跑 `python3 Scripts/render-menubar-icon.py` 即可。

---

## 核心檔案地圖

```
~/Desktop/pulse/
├── docs/superpowers/{specs,plans}/2026-04-28-pulse-{design,implementation}.md
├── HANDOFF.md（此檔）
├── CHANGELOG.md
├── README.md / CLAUDE.md
├── Pulse/
│   ├── App/{PulseApp,AppDelegate}.swift
│   ├── Core/{Source,SourceStore,Card,CardStore,Settings,QuickTodo,QuickTodoStore,PulseQuickWriter,CLAUDEMdHookWriter}.swift
│   ├── Ingest/{MultiStrategyMarkdownParser,ConventionalCommitsParser,GitLogRunner,GitIngester,MarkdownIngester,Ingester,RefreshScheduler,FileWatcher,AutoSourceDetector}.swift
│   ├── Ingest/Strategies/{Checkbox,EmojiCheckmark,NumberedSection,SectionHeading}Strategy.swift
│   ├── UI/{PopoverContentView,PopoverHeaderView,PopoverFooterView,ProjectTabBar,CardRowView,LoadingPlaceholderView,EmptyStateView,QuickTodoComposer,MenubarIconController,OpenSourceRef,OnboardingView,...}.swift
│   ├── UI/Settings/{SettingsView,SourcesTab,FiltersTab,AboutTab}.swift
│   └── Build/Internal.swift
├── PulseTests/...
├── xcconfig/{Shared,Pulse-Internal,Pulse-Public}.xcconfig
├── project.yml
└── Scripts/{run-tests,build-dmg,release,verify-readonly}.sh
```

---

## User 拍板的決策（不要再問）

- **pulse.md 是 Pulse-managed convention**，不寫進 CLAUDE.md（除了 hook block）
- **NumberedSectionStrategy 不在 default**（URGENT/HIGH 段噪音太多）
- **git --since=30 days**（不是 14）
- **Done items NOT 寫進 pulse.md**：commit log 涵蓋「做了什麼」歷史
- **快速記分兩種**：寫進專案 OR 只記在 Pulse（跨專案雜事）
- **TCC scope 只 Desktop**（不要 Documents/Downloads 嚇到 user）
- **公開版英文 / 個人版中文** via `#if INTERNAL_BUILD`，不做 runtime locale
- **Hook trigger phrase semantic match**（不是 slash command）
- **CardRowView 不顯示 body**（只 title + date，body 在 hover tooltip）
- **DONE cards 折疊在「已完成 (N) ▼」**（不是獨立 tab，不是 hidden）

---

## 開工前必讀

### 1. 全域 CLAUDE.md hard rules
`~/.claude/CLAUDE.md`

特別記得：
- §0 工作邊界 — 只 commit 自己 session 的工作，不 sweep 別人的 dirty state
- §1 中文書寫 — 自撰段落不用破折號（`——`）、不用 italic
- §4 不自動 commit / push（user 須明示）

### 2. Memory 索引
`~/.claude/projects/-Users-sunquanhuang-Desktop-new-heterotopias/memory/MEMORY.md`

重點：
- `feedback_automate_user_mechanics.md` — 有 Bash 自己跑 pkill/cp/open，不要叫 user 拖檔
- `feedback_session_token_discipline.md` — token 是稀缺
- `feedback_subagent_pre_flight_check.md` — 派 agent 前 verify
- `feedback_no_choices_just_execute.md` — 別連續端選項給用戶
- `feedback_verified_vs_unverified_in_completion.md` — UI runtime 必須拆 verified vs unverified

---

## 慣例

```bash
# 開發
cd ~/Desktop/pulse
xcodegen generate                                 # 加新檔後跑
./Scripts/run-tests.sh                            # 跑全 test suite

# Release-Internal build + install + launch
xcodebuild -project Pulse.xcodeproj -scheme Pulse \
  -configuration Release-Internal \
  -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build
APP=$(find ~/Library/Developer/Xcode/DerivedData -name "Pulse Internal.app" -path "*Release-Internal*" | head -1)
pkill -9 -f "Pulse Internal"; sleep 1
rm -rf "/Applications/Pulse Internal.app"
cp -R "$APP" /Applications/
open "/Applications/Pulse Internal.app"

# Build dmg
./Scripts/build-dmg.sh 0.1.0 both                 # 產 internal + public dmg
```

**Commit message**：Conventional Commits + scope。Co-Authored-By trailer 帶 Claude attribution。

---

## v0.1.x 開發中踩過的坑（避免重複）

| 坑 | 對策 |
|---|---|
| TCC for Desktop folder block 整 process（不只 UI 線程） | 加 `INFOPLIST_KEY_NSDesktopFolderUsageDescription`，TCC prompt 出現帶 reason |
| Pulse Internal 沒 dock icon，TCC prompt 容易看不到 | 第一次 launch 要看選單列彈窗。實在沒看到就 `tccutil reset SystemPolicyDesktopFolder com.huangsunquan.pulse.internal` 重 prompt |
| PRODUCT_NAME 改了，Swift module 名也跟著改 → `Pulse.Settings()` 找不到 | 用 `PRODUCT_MODULE_NAME = Pulse` 鎖死 module 名 |
| `SwiftUI.Settings { ... }` scene 跟 `Pulse.Settings` class 撞名 | 用 `SwiftUI.Settings { SettingsView() }` 顯式 namespace |
| URL with percent-encoded path：`.path` 解碼 OK，`String(contentsOf:)` 直接收 URL 也 OK | — |
| dmg 沒 `Applications` symlink user 不會拖 | `ln -s /Applications "$staging/Applications"` 在 build-dmg.sh |
| Pulse 沒 Quit 按鈕 user 殺不掉 | popover header 加 ⏻ 按鈕 + ⌘Q 鍵盤捷徑 |
| NumberedSectionStrategy 把 URGENT/HIGH/MEDIUM 段抓進來太雜 | 從 default 拿掉，需要時 explicit pass strategies init |
| 9 專案大多數沒 `## To Do` 段，markdown ingest 抓不到 todo | bootstrap subagent 平行掃所有 audit/docs/memory 整理進 pulse.md |

## v0.3 開發中踩過的坑（避免重複）

| 坑 | 對策 |
|---|---|
| Plan §風險 row 寫了「先驗 fixture 真的含 🔴」但實際沒驗，Q6 ship 完發現 9 專案 URGENT/HIGH section 全空 | 規劃文件每個 mitigation row 開戰前轉 TodoWrite 條目，跑完才敢宣告完工。Code review 找 ground-truth 對照（cards-cache.json grep priority tag = 17 urgent + 6 high 對齊 real pulse.md） |
| Settings tooltip 寫「(⌘,)」但沒實際 wire `.keyboardShortcut(",", modifiers: .command)` | LSUIElement apps 沒預設 menu bar，SwiftUI Settings scene auto-wire 不會 fire；popover 內按鈕必須自己接 keyboardShortcut 才生效。tooltip 跟 binding 拆兩件事看 |
| OverviewView 每 render 算 6 次 allCards / 2N 次 sourceStore.load() | body 入口 `let cards = ...; let sources = ...` 一次 cache，pass 給 row helper。設計時就要想 SwiftUI 不 memoize computed property |
| 24h ↔ 7d 時間區間 inclusive 兩邊會在剛好 24h 邊界 double count | 用 half-open `(lower, upper]`：`d > lower && d <= upper`。Static helper 接 `hoursAgoLower:hoursAgoUpper:` 兩參數 |
| qlmanage 渲染 stroke-only SVG 加白底 | 不要走 qlmanage；用 PIL（`Scripts/render-menubar-icon.py`）或 rsvg-convert 直接畫透明 PNG，opaque pixels 只在 stroke |
| 5 個破折號（——）混進 commit body | CLAUDE.md §1 HARD RULE 自撰段落禁用破折號；起草時就不寫，不要等 review 才回頭改 |

---

## 重要 commit 序（讀 history 用）

### v0.3 (2026-04-29, 13 commits)

```
d7b831f feat(i18n): Public build switches to English via #if INTERNAL_BUILD (Q3)
3945700 fix(menubar): rerender icon to 22×22 transparent (Q8 a+b)
15acf44 refactor(overview): static aggregator helpers + half-open boundary + cache-per-render
f92b285 fix(header): wire ⌘, keyboardShortcut to Settings button (review §B 🔴-1)
9d98857 fix(overview): derive priority from section heading, not just title prefix
97b4f11 test(overview): aggregate + sentinel-label coverage (+5 cases)
b1782b6 fix(header): wire ⌘R keyboard shortcut + tooltip on Refresh button (Q5-B)
dd7948e feat(overview): wire Overview as default tab in PopoverContentView + ProjectTabBar
7dcf1b6 feat(overview): OverviewView + DigestLine + Section + CardChip components
6b6304e feat(overview): cross-project aggregator helpers in CardStore
69936e1 feat(brand): introduce Brand color tokens (designer amber/slate)
1d2f317 docs(handoff): Q8 menubar icon 白底 + 過大（下輪一起解）
f09f453 docs(handoff): v0.3 direction record — aggregator, no rewrite, Shape A IA
```

### v0.2 (2026-04-28)

```
b3a6136 fix(popover): drop NSApp.activate so .transient click-outside dismiss works (Q5-A)
a03ffe4 feat(brand): adopt designer pulse-spike icon (app + menubar template)
0851abb build: bake MARKETING_VERSION 0.2.0 + CURRENT_PROJECT_VERSION into xcconfig
5fbfe35 chore(hooks): one-shot script to sync existing CLAUDE.md hook blocks
5dcb462 test(maintenance): unit cover cleanLines + cleanAgedDoneItems
2624d1e feat(maintenance): sweep aged `- [x] (done ...)` lines from pulse.md on refresh
f6b69b3 feat(hook): add done/delete trigger phrases to CLAUDE.md hook block
b47f06a feat(hook): expanded CLAUDE.md hook with trigger-phrase rules
67b17e8 chore(ingest): git log cutoff 14 → 30 days per user
46acd02 feat(detect): pulse.md added to auto-detection convention; 9-project bootstrap done
10048e1 feat(pulse-md): rename PULSE_QUICK.md → pulse.md + auto-write CLAUDE.md hook
```

### v0.1 (older, foundational)

```
6ec3459 feat(v0.1): board UI + quick todos + 14d git cutoff + drop NumberedSectionStrategy
9d7cb87 fix(build): split PRODUCT_NAME (Pulse Internal vs Pulse)
a58971b fix(ui): Applications symlink + Quit button (⌘Q)
7512853 build: release script with bundle-ID safety check
5f17417 docs: CHANGELOG + README + HANDOFF for v0.1.0
```

`git log --oneline -30` 可看更全。

---

## 下個 session 第一個動作

讀完此檔，做 **Q4：Settings 管理監控專案**（HANDOFF 上面已有完整需求段）。MVP 建議：

1. Settings 加「重新掃描 Desktop」按鈕，跳出 onboarding-style 結果視窗讓 user 補勾新專案 / 取消勾舊專案
2. 個人版的 hardcoded list 改成「default 但可覆寫」：UI 上把 hardcoded 顯示為勾選狀態，user 可取消勾或新增其他路徑，覆寫值存到 sources.json
3. （optional）拖檔加專案：拖一個資料夾進 popover 或 Settings → SourcesTab 直接成 source

不做 runtime locale 切換（已決議 Q3 路線），Q4 新加的字串要：
- 同步進 `Pulse/Resources/Strings.swift` 的 `enum L`
- bilingual zh/en 兩條都寫

驗收：個人版能在 UI 把 9 個 hardcoded 專案改成 8 個，重啟後仍是 8 個（不會被 Internal.swift hardcode 蓋回）。公開版能再次掃描 Desktop 補勾新專案。

### v0.3 已 ship 的 Q items（不要再 re-litigate）

| Q | 描述 | commit |
|---|---|---|
| Q1 | pulse.md 完成事項處理機制 | v0.2.0 (`f6b69b3` etc.) |
| Q2 | 速記寫進專案 | v0.2.0 |
| Q3 | 公開版英文化 #if INTERNAL_BUILD + Strings.swift | `d7b831f` |
| Q5-A | click-outside dismiss fix | `b3a6136` |
| Q5-B | ⌘R / ⌘, keyboardShortcut + tooltip 對齊 | `b1782b6` + `f92b285` |
| Q6 | Overview tab + cross-project digest（Brand → aggregator → view → wire → tests） | `69936e1` → `15acf44`（9 commits） |
| Q7 | 已完成 disclosure 處理（隨 Q6） | 同 Q6 |
| Q8 | Menubar icon 22×22 transparent | `3945700` |
