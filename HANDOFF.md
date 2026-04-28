# Handoff · last updated 2026-04-28

> 換 session 時讀這檔。Pulse v0.1 已 ship 但仍在迭代；下一輪要做 Q1 done 機制 + Q3 英文公開版。

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

### Tests：179/179 PASS

---

## 還沒做的（user 拍板，下 session 開工）

### Q1: pulse.md 已完成事項處理機制 — **下次 session 第一件事**

要做：
1. **擴 hook trigger phrases**（在 `CLAUDEMdHookWriter.hookBlock()` 跟 8 個現存 CLAUDE.md），多加 done trigger：
   - 「X 完成」/「X 做完了」/「X 結了」→ Claude Code 把 pulse.md 對應 `- [ ]` 改 `- [x]`
   - 「幫我刪掉 X」/「不要這條 X」→ 整行 remove（user 拍板：完成或刪除二擇一）
2. **加 Pulse archive 邏輯**：`RefreshScheduler` 每次 refresh 額外掃所有 pulse.md 檔，把 `- [x]` 且日期 > 30 天前的項目搬到 `## Archive` 段（保留歷史）— **這個 user 還沒最後拍板「Archive 段」vs「直接刪」**
3. 同步用 Python regex 更新 8 個現存 CLAUDE.md hook block（沿用 b47f06a 那次的更新模式）

git log 不動：仍每次讀 git，commit 顯示為 done card 在 popover「已完成 (N) ▼」disclosure。pulse.md `- [x]` 跟 git commit done 並列顯示。

**為什麼不靠 commit 自動 mark done**：commit subject 跟 todo title 模糊比對誤殺成本高；保險走 hook 路。

### Q2: 速記寫進專案（已實作，user 只是 confirm）

`+ 快速記` 展開 → 選某專案 → 寫進 `<project>/pulse.md` `## To Do` 段。「📝 只記在 Pulse」= 存 `quick-todos.json`（跨專案 / 雜事）。

### Q3: 公開版英文化 — Q1 之後做

User 拍板：不做 runtime locale 切換，直接 `#if INTERNAL_BUILD` 切兩套字串：
- 個人版（Internal）：中文 hardcoded（現狀不動）
- 公開版（Public）：全英文

要做：
1. 建 `Pulse/Resources/Strings.swift`（集中所有 user-facing 字串）
2. 每個字串 `#if INTERNAL_BUILD ... #else ...`
3. 重新 build 公開版 dmg
4. 預估 1-2 小時

要動的字串約 30-50 條：popover header / footer / tab / pills / QuickTodoComposer / OnboardingView / Settings tabs / EmptyStateView / LoadingPlaceholderView。pulse.md 的 header 文字也要決定（兩語都接受 vs 只英文）。

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

讀完此檔。先做 Q1 done 機制（半小時）：

1. 擴 `CLAUDEMdHookWriter.hookBlock()` 加 done / delete trigger phrases：
   - 「X 完成」/「X 做完了」/「X 結了」→ `- [ ]` 改 `- [x]`
   - 「幫我刪掉 X」/「不要這條 X」→ 整行 remove
2. 用 Python regex 同步更新 8 個現存 CLAUDE.md hook block（pattern 跟 b47f06a 那次一樣）
3. **問 user 拍板**：完成 30 天前的 `- [x]` 要「搬到 ## Archive 段」還是「直接刪」？
4. 加 archive / cleanup 邏輯到 `RefreshScheduler` 或專屬 `PulseFileMaintenance.swift`
5. Tests + build dmg + commit

完成 Q1 後做 Q3 英文公開版字串（1-2 小時，工作量散在 30-50 條 string）。
