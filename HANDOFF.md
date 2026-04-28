# Handoff · last updated 2026-04-29

> 換 session 時讀這檔。Pulse v0.2.0 已 ship；2026-04-29 user 拍板**產品方向**（aggregator 不是 session monitor）+ **stack 不變**（Swift）+ **brand identity 換成 designer spec**（amber pulse spike + slate）+ **下一版 IA shape A**（Overview tab + per-project drill-down）。下一輪做 Q6 Overview tab。

---

## TL;DR — 在哪裡

- Pulse v0.2.0 已**裝在** `/Applications/Pulse Internal.app`（個人版）跑著，icon 已換成 designer 的 amber pulse spike
- repo at `/Users/sunquanhuang/Desktop/pulse/`，**已 push GitHub** (private) `https://github.com/inertia/pulse`
- Tag `v0.2.0` 指最新（含 Info.plist 版號 baked + designer icon + click-outside dismiss fix）
- 9 個個人專案（user Desktop 上）已有 `pulse.md` + 8 個 `CLAUDE.md` 加了 hook block，全部 commit 但未 push 到各 repo remote
- **設計參考**：`/tmp/pulse-handoff/`（designer 提供，user 2026-04-29 給）— 視覺 / brand 採納；session monitoring 產品定位**未採納**

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

### Q3: 公開版英文化 — **下次 session 第一件事**

User 拍板：不做 runtime locale 切換，直接 `#if INTERNAL_BUILD` 切兩套字串：
- 個人版（Internal）：中文 hardcoded（現狀不動）
- 公開版（Public）：全英文

要做：
1. 建 `Pulse/Resources/Strings.swift`（集中所有 user-facing 字串）
2. 每個字串 `#if INTERNAL_BUILD ... #else ...`
3. 重新 build 公開版 dmg
4. 預估 1-2 小時

要動的字串約 30-50 條：popover header / footer / tab / pills / QuickTodoComposer / OnboardingView / Settings tabs / EmptyStateView / LoadingPlaceholderView。pulse.md 的 header 文字也要決定（兩語都接受 vs 只英文）。

### Q4: Settings → 管理監控專案 — **觀察 1-2 天後做**（2026-04-28 拍板）

現狀（user 痛點）：
- **個人版**：9 專案 hardcoded 在 `Pulse/Build/Internal.swift`，要砍 / 加只能改 Swift 重 build。日常用沒辦法自己增減。
- **公開版**：onboarding 第一次掃描勾選後就鎖定；之後沒地方再呼叫一次 scan，只能進 Settings → Sources tab 一條條手動管。

兩版都需要的功能（user 拍板「否則很難用」）：
- Settings 加「重新掃描 Desktop」按鈕，跳出 onboarding-style 結果視窗讓 user 補勾新專案 / 取消勾舊專案
- 個人版要能蓋掉 hardcoded list（讓 user 在 UI 改動，不用回 Internal.swift）
- 拖檔加專案考慮（拖一個資料夾進 popover 直接成 source，跳過掃描）

先觀察期 1-2 天看實際使用 pain points，再決定 scope。MVP 可能只做「重新掃描」按鈕，個人版 hardcoded list 改成 default 但允許覆寫。

### Q5: Popover header dismiss 行為 + 鈕辨識度（2026-04-28 user 回報，**part A 完工 2026-04-29**）

User 回報「打開以後關掉鈕（⏻ Quit）比較明顯，但另一個『收起』小按鍵不太容易直接感覺到，很像設定的按鈕。本來以為離開視窗按別的地方就會自動收起，但結果沒有」。

**A. Click-outside 不會 dismiss — 已修（2026-04-29，icon swap commit 一起）**：原因是 `togglePopover()` show 完緊接 `NSApp.activate(ignoringOtherApps: true)`，吃掉 .transient 失焦訊號。fix = 拿掉 `NSApp.activate` 那行；popover SwiftUI 自己處理 keyboard event 不受影響。

**B. Header 三鈕語意混淆**（仍待做）：⚙️ gear / 🔄 arrow.clockwise / ⏻ power — user 把 ⏻ 認成「關閉」（其實是 Quit 整個 app），把 ⚙️ 誤認成「收起」。Q6 Overview tab 落地時順便解：
- 加一顆明確的「收起 popover」鈕（chevron.up / xmark）
- 或：⏻ 改 icon + label，更明顯是「離開 app」
- 或：拿掉 ⏻，靠 ⌘Q 即可（既然 A 修了，user 也很少需要 ⏻ 主動退出）

### Q6: Overview tab — 跨專案 digest（**下一輪重點，2026-04-29 拍板**）

User 觀察 v0.2 IA 不對：「跨專案 review」現在被切成 9 個 per-project tab，方向反了。Designer spec 雖然產品定位錯，但 status-grouped + 每張卡掛 project chip 的 IA shape 對 review 是對的方向。

**Shape A 設計**：
- ProjectTabBar 最左加 **Overview** tab，預設選中 first-launch + 之後
- Overview view 內容（從上到下）：
  1. **Digest 一句話**：`今天完成 N 件 / outstanding M 件 / X 個專案有東西未完成`（用 designer amber 強調）
  2. **🔴 URGENT outstanding**（cross-project，每張卡 = project chip + age + 文字）
  3. **🟡 HIGH outstanding**（同上）
  4. **完成 last 24h**（git commit + pulse.md `- [x]` 並列；project chip + 時間 stamp + agent label「git / pulse」）
  5. **完成 last 7d**（disclosure 折疊；點開 chronological list）
- Per-project tabs 留作 drill-down，不變
- Card pattern 借 designer：bg-stone-100/zinc-800 等價、dot indicator（emerald = done、amber = urgent）、font-mono for project name + dates、tabular-nums for counts

**新增 Swift 元件**（推估）：
- `OverviewView.swift` — root，組合 digest + 4-5 sections
- `DigestLineView.swift` — 一句話 summary，從 cardStore aggregate
- `CardChipView.swift` — 通用卡，project chip + age + dot 配色
- `lib/Format.swift` — `formatElapsed(_:)` / `formatRelative(_:)` / `formatCount(_:)` 對應 designer helper
- `Pulse/Brand/Colors.swift`（新檔）— `Brand.amber` `#ffa940` / `Brand.slate` `#1a1f2e` 等 token

**選 A 不選 B 的原因**：reuse 現有 ProjectTabBar / CardRowView component；漸進演化；用一陣子若 per-project tab 沒人點再升級 B（廢 tab）。

預估：2-3 天工作量。執行 order：tokens / Brand → OverviewView 殼 → digest line → URGENT/HIGH section → done sections → 整合 first-launch 預設 → 跑 tests（既有 186 + Overview 至少 5 cases）。

### Q7: 已完成軸的處理（伴隨 Q6）

現在 `已完成 (N) ▼` 是 per-project + collapsed by default。「review 跨專案」場景下這是反的：done 軸應該是 review 主角，不該藏起來。Q6 Overview 落地後，per-project tab 內的 disclosure 仍然保留（drill-down 場景合理藏起），但 Overview 內 done 是預設展開、cross-project chronological。

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

---

## 重要 commit 序（讀 history 用）

```
5fbfe35 chore(hooks): one-shot script to sync existing CLAUDE.md hook blocks
5dcb462 test(maintenance): unit cover cleanLines + cleanAgedDoneItems
2624d1e feat(maintenance): sweep aged `- [x] (done ...)` lines from pulse.md on refresh
f6b69b3 feat(hook): add done/delete trigger phrases to CLAUDE.md hook block
8c766a3 docs: handoff for next session — Q1 done mechanism + Q3 English public version
b47f06a feat(hook): expanded CLAUDE.md hook with trigger-phrase rules
67b17e8 chore(ingest): git log cutoff 14 → 30 days per user
46acd02 feat(detect): pulse.md added to auto-detection convention; 9-project bootstrap done
10048e1 feat(pulse-md): rename PULSE_QUICK.md → pulse.md + auto-write CLAUDE.md hook
bd5998f feat(ui): quick todo can target a project, writes to PULSE_QUICK.md
6ec3459 feat(v0.1): board UI + quick todos + 14d git cutoff + drop NumberedSectionStrategy
9d7cb87 fix(build): split PRODUCT_NAME (Pulse Internal vs Pulse)
a58971b fix(ui): Applications symlink + Quit button (⌘Q)
7512853 build: release script with bundle-ID safety check
5f17417 docs: CHANGELOG + README + HANDOFF for v0.1.0
```

`git log --oneline -20` 可看更全。

---

## 下個 session 第一個動作

讀完此檔。先做 Q6 Overview tab（2-3 天工作量，是 v0.3 重點），Q3 英文化降為 Q6 之後：

### Q6 step-by-step（推薦執行 order）

1. **Brand tokens 落地**：建 `Pulse/Brand/Colors.swift`：
   ```swift
   enum Brand {
     static let amber = Color(red: 1.0, green: 0.663, blue: 0.251)   // #ffa940
     static let amberDeep = Color(red: 0.78, green: 0.4, blue: 0.05)  // dark mode 補強對比
     static let slate = Color(red: 0.102, green: 0.122, blue: 0.18)   // #1a1f2e
     static let surface2 = Color(NSColor.controlBackgroundColor)      // designer surface-2 對應
   }
   ```
2. **OverviewView 殼**：建 `Pulse/UI/Overview/OverviewView.swift` + 子件 `DigestLineView` / `OverviewSection` / `CardChipView`
3. **PopoverContentView 整合**：在 `ProjectTabBar` 之前 inject `Overview` tab；`selectedLabel` 預設邏輯改成「if 沒選過 → Overview」
4. **Cross-project aggregator**：在 `cardStore` 加 helper（不破壞既有 per-project 接口）：
   - `cardsAcrossProjects(status: .todo, priority: .urgent)` → [Card]
   - `doneCardsLast(hours: 24)` → [Card] (mix git commit + pulse.md done)
   - `digestSummary()` → `(doneToday: Int, outstanding: Int, projectsWithOutstanding: Int)`
5. **Tests**：新增 `OverviewViewTests.swift` + `CardStoreAggregateTests.swift`（至少 5 cases — empty / single project / cross-project / urgent filter / done last 24h）
6. **跑 ./Scripts/run-tests.sh** — 期望 186 + 5 = 191 green
7. **Build Release-Internal + install + manual eyeball**：
   - Overview tab 是不是預設選中
   - Digest 一句話正確
   - URGENT / HIGH section 跨專案顯示（現有 9 專案 cards 應該分布在多 section）
   - 完成 last 24h 包含 git commit + pulse.md `[x]`
   - Per-project tab 點進去依然可看細節
8. **Commit 拆分**（per HARD RULE §0）：
   - `feat(brand): introduce Brand color tokens (designer amber/slate)`
   - `feat(overview): cross-project aggregator helpers in CardStore`
   - `feat(overview): OverviewView + DigestLine + Section + Card components`
   - `feat(overview): wire Overview as default tab in PopoverContentView`
   - `test(overview): aggregate + view tests`

### Q5-B（順便做）

- Q6 整合 PopoverContentView 時順便處理 header 三鈕語意 — 拿掉 ⏻（靠 ⌘Q），或把 ⏻ 改 icon + tooltip 強化「Quit Pulse」語意；⚙️ 維持 Settings；🔄 維持 Refresh

### Q3 / Q4（推遲）

- Q3 英文化 = Q6 落地後做（順便把 Overview 字串也搬進 L enum，一次到位）
- Q4 Settings 增刪專案 = Q3 之後做（觀察期已過，user 痛點若仍存在再做）
