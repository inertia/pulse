# CHANGELOG

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
