# HANDOFF

Cross-session handoff state for Pulse. Update this every time a session ends with notable progress.

## Current state（2026-04-28）

- **Status**：v0.1.0 ship 完成，Tasks 1-37 全部結案
- **Branch**：`main`
- **Tests**：177 passing（unit + integration）
- **Spec**：`docs/superpowers/specs/2026-04-28-pulse-design.md`
- **Plan**：`docs/superpowers/plans/2026-04-28-pulse-implementation.md`（37 tasks，全部完成）
- **Repo state**：clean，可開 v0.2 worktree

## v0.1.0 內容

詳見 [CHANGELOG.md](CHANGELOG.md)。重點：

- Menubar app（NSStatusItem + NSPopover）跨專案讀 CLAUDE.md / AGENTS.md / GEMINI.md checkbox + git log conventional commits
- Internal build 預載 9 個專案；Public build 第一次啟動跑 onboarding 掃描 5 個常見目錄
- 設定面板 ⌘, 三 tabs（Sources / Filters / About）
- FSEventStream 1 秒 debounce 自動 refresh markdown，5 分鐘保底 timer 掃 git
- 唯讀（G7 byte-for-byte 驗證）

## 常用指令

```bash
# 跑 tests
./Scripts/run-tests.sh

# Build dmg（v0.1.0 release 用）
./Scripts/build-dmg.sh 0.1.0 both

# G7 唯讀驗證（需先 brew install jq）
./Scripts/verify-readonly.sh snapshot
# 開 Pulse app 跑 5 分鐘
./Scripts/verify-readonly.sh compare
```

## Task 37（剩下唯一一項）

最後 ship task：

1. `git tag v0.1.0`
2. 跑 `Scripts/release.sh`（會做 build-dmg + 產生 release notes）
3. 在 GitHub 開 release，附 dmg + CHANGELOG 內容

完成後 v0.1.0 即正式發行。

## v0.2 backlog

對應 CHANGELOG「已知限制」段，下一版規劃：

- 全域熱鍵開 popover
- GitHub issues / PRs ingest（需 token，加 token 設定 UI）
- Onboarding 結果頁加「+ 手動加路徑」按鈕
- Menubar badge count（未讀 todo / 新 done 數）
- 正式 menubar icon 設計（取代 SF Symbol `waveform.path.ecg`）

## Pulse vs Nacelle

避免混淆：

- **Pulse**：唯讀 auto monitor。讀既有的 CLAUDE.md / git log，不寫回，純呈現跨專案進度。
- **Nacelle**：kanban app（另一專案 `~/Desktop/nacelle/`），手動建卡、拖卡、編輯，是輸入工具不是觀察工具。

兩個 app 互補：Pulse 看「外面世界發生什麼」，Nacelle 管「自己手上要做什麼」。
