# Pulse

跨專案 todo / done 自動 monitor menubar app。為 Claude Code、Codex、Cursor、Gemini CLI 使用者打造的 macOS 工具列應用。

Pulse 自動讀取你各個專案裡的 `CLAUDE.md` / `AGENTS.md` / `GEMINI.md` 中的 checkbox 待辦，以及 git log 裡的 conventional commits（`feat:` / `fix:` / `chore:` 等），在工具列彈出視窗即時呈現「待辦」與「已完成」卡片。**唯讀**，不會回寫任何檔案。

## 支援的資料來源

- `CLAUDE.md` — Claude Code 的 todo checkbox
- `AGENTS.md` — Codex / Cursor 的 todo checkbox
- `GEMINI.md` — Gemini CLI 的 todo checkbox
- `git log` — Conventional Commits 規範的 commit 訊息

## 安裝

從 [GitHub Releases](https://github.com/inertia/pulse/releases) 下載 `Pulse-x.y.z.dmg`，拖到 Applications 即可。

第一次啟動會跑 onboarding 偵測 source 路徑，之後會常駐工具列。

螢幕截圖補上 / Screenshots coming with v0.1.0 release.

## 系統需求

macOS 14 (Sonoma) 以上。

## License

MIT — see [LICENSE](LICENSE).

---

## English

Pulse is a macOS menubar app that auto-monitors todos and recent work across multiple projects, built for users of Claude Code, Codex, Cursor, and Gemini CLI. It reads `CLAUDE.md` / `AGENTS.md` / `GEMINI.md` checkbox items and `git log` conventional commits, surfacing them as todo / done cards in a menubar popover. Read-only by design — Pulse never writes back to your files.

Download `Pulse-x.y.z.dmg` from GitHub Releases, drag to Applications, run onboarding on first launch. macOS 14+. MIT licensed.
