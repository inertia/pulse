# Handoff · last updated 2026-04-28 (post-Q1)

> 換 session 時讀這檔。Pulse v0.1 已 ship；Q1 done 機制 2026-04-28 完工 + e2e 驗過；下一輪做 Q3 英文公開版。

---

## TL;DR — 在哪裡

- Pulse v0.1 已**裝在** `/Applications/Pulse Internal.app`（個人版）跑著
- repo at `/Users/sunquanhuang/Desktop/pulse/`，main 上 commit `b47f06a` 是最新
- 兩個 dmg 在 `build/`：`Pulse-0.1.0.dmg`（公開）+ `Pulse-0.1.0-internal.dmg`（個人）
- 9 個個人專案（user Desktop 上）已有 `pulse.md` + 8 個 `CLAUDE.md` 加了 hook block
- **沒 push 到 GitHub**（還沒建 repo）

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

### Q5: Popover header dismiss 行為 + 鈕辨識度（2026-04-28 user 回報）

User 回報「打開以後關掉鈕（⏻ Quit）比較明顯，但另一個『收起』小按鍵不太容易直接感覺到，很像設定的按鈕。本來以為離開視窗按別的地方就會自動收起，但結果沒有」。

問題拆兩件：

**A. Click-outside 不會 dismiss**：`MenubarIconController` 已設 `popover.behavior = .transient`（理論上失焦自動關），但 `togglePopover()` 在 show 之後緊接 `NSApp.activate(ignoringOtherApps: true)`（為了收 keyboard events）— Pulse 變 active app 後 .transient 的「失焦」訊號被吃掉，點 popover 外面不算 lose focus。
- Fix 候選 1：show 完不要 activate，等使用者真的需要 keyboard 時再啟用（compose / search）
- Fix 候選 2：保留 activate 但加 NSEvent.addGlobalMonitorForEvents(.leftMouseDown) 自己偵測 popover 外點擊 → performClose
- Fix 候選 3：改用 `NSStatusItem` + 自己管 NSWindow（捨棄 NSPopover），完整自控 dismiss
- 推薦先 1，token 成本最低；不影響 ⌘K search 因為 search 在 popover 內、popover open 期間 SwiftUI 會吃 keyboard

**B. Header 三鈕語意混淆**：⚙️ gear / 🔄 arrow.clockwise / ⏻ power — user 把 ⏻ 認成「關閉」（其實是 Quit 整個 app），把 ⚙️ 誤認成「收起」。
- 加一顆明確的「收起 popover」鈕（chevron.up / xmark）
- 或：⏻ 改 icon 跟 label，更明顯是「離開 app」（避免跟「關 popover」混淆）
- 或：拿掉 ⏻，靠 ⌘Q 即可（HANDOFF v0.1.x 的坑：原本沒 Quit 鈕，user 殺不掉才加，但加了之後反而混淆）

兩件可一起做、commit 拆分。預估 30-60 min。

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

讀完此檔。直接做 Q3 英文公開版（1-2 hr，工作量散在 30-50 條 string）：

1. 建 `Pulse/Resources/Strings.swift`，集中所有 user-facing 字串（enum L 帶 `#if INTERNAL_BUILD` 切兩套）
2. `grep -rn '"[\x{4e00}-\x{9fff}]"' Pulse/UI/` 列出所有中文字面量，逐個搬到 `L.xxx`
3. 確認 `Pulse-Internal.xcconfig` 的 `SWIFT_ACTIVE_COMPILATION_CONDITIONS` 含 `INTERNAL_BUILD`
4. 預期動到的檔案：`PopoverContentView` / `PopoverHeaderView` / `PopoverFooterView` / `ProjectTabBar` / `QuickTodoComposer` / `OnboardingView` / `Settings/{SettingsView, SourcesTab, FiltersTab, AboutTab}` / `EmptyStateView` / `LoadingPlaceholderView`
5. **不動的字串**：`CLAUDEMdHookWriter.hookBlock()` 永遠中文（hook 內容是給該專案 Claude Code session 讀，不是 app UI；公開版下載者用自己的 LLM/語言）
6. Build internal + public 兩個 dmg 驗：internal 中文不變，public 全英文
7. Commits: `feat(i18n): centralize strings in L enum` → `feat(i18n): English strings for public via #if INTERNAL_BUILD`
