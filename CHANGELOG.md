# CHANGELOG

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
