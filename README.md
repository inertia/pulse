# Pulse

跨專案 todo / done 自動 monitor menubar app。為 Claude Code、Codex、Cursor、Gemini CLI 使用者打造的 macOS 工具列應用。

Pulse 自動讀取你各個專案裡的 `CLAUDE.md` / `AGENTS.md` / `GEMINI.md` 中的 checkbox 待辦，以及 git log 裡的 conventional commits（`feat:` / `fix:` / `chore:` 等），在工具列彈出視窗即時呈現「待辦」與「已完成」卡片。**唯讀**，不會回寫任何檔案。

## 支援的資料來源

- `CLAUDE.md`：Claude Code 的 todo checkbox
- `AGENTS.md`：Codex / Cursor 的 todo checkbox
- `GEMINI.md`：Gemini CLI 的 todo checkbox
- `git log`：Conventional Commits 規範的 commit 訊息

## 安裝

從 [GitHub Releases](https://github.com/inertia/pulse/releases) 下載 `Pulse-x.y.z.dmg`，拖到 Applications 即可。

第一次啟動會跑 onboarding 偵測 source 路徑，之後會常駐工具列。

螢幕截圖補上 / Screenshots coming with v0.1.0 release.

## 使用方式

第一次啟動：

1. **公開版**：onboarding 視窗會掃描 ~/Desktop / ~/Projects / ~/code / ~/Developer / ~/Documents，列出含 `CLAUDE.md` / `AGENTS.md` / `GEMINI.md` 的目錄；勾選要追蹤的專案後完成。
2. **個人版**（INTERNAL_BUILD）：預載 9 個進行中的專案，啟動立即顯示，無 onboarding。

日常使用：

- **點工具列 icon**：彈出 popover，看跨專案的 todo / done 卡片
- **⌘,**：開設定面板（Sources / Filters / About 三個 tabs）
  - Sources：增刪 source 路徑
  - Filters：切換 git commit preset（Minimal / Recommended / All）
  - About：版本資訊
- **自動 refresh**：markdown source 透過 FSEventStream 即時更新（1 秒 debounce）；git log 每 5 分鐘保底掃一次

## 系統需求

macOS 14 (Sonoma) 以上。

驗證 G7 唯讀（選用）需要 `jq`：`brew install jq`，然後執行 `./Scripts/verify-readonly.sh`。

## 貢獻 / 反饋

Bug、建議、功能請求歡迎開 issue：https://github.com/inertia/pulse/issues

PR 歡迎，請先在 issue 討論方向避免重工。

## License

MIT 授權，詳見 [LICENSE](LICENSE)。

---

## English

Pulse is a macOS menubar app that auto-monitors todos and recent work across multiple projects, built for users of Claude Code, Codex, Cursor, and Gemini CLI. It reads `CLAUDE.md` / `AGENTS.md` / `GEMINI.md` checkbox items and `git log` conventional commits, surfacing them as todo / done cards in a menubar popover. Read-only by design. Pulse never writes back to your files.

Download `Pulse-x.y.z.dmg` from GitHub Releases, drag to Applications, run onboarding on first launch. macOS 14+. MIT licensed.
