<p align="center">
  <img src="docs/screenshots/pulse-icon.png" width="128" alt="Pulse app icon — amber pulse spike on slate">
</p>

<h1 align="center">Pulse</h1>

<p align="center"><em>Cross-project todo &amp; done aggregator for the macOS menubar.</em></p>

---

Built for developers who use AI coding assistants (Claude Code, Codex, Cursor, Gemini CLI) and work across many repos. Pulse passively reads your `CLAUDE.md` / `AGENTS.md` / `GEMINI.md` / `pulse.md` checkbox items and your `git log` conventional commits, then surfaces them in a single menubar popover so you can see what's outstanding and what just landed without `cd`-hopping between repositories.

## Screenshots

<table>
  <tr>
    <td width="50%">
      <img src="docs/screenshots/01-overview-urgent.png" alt="Overview tab — URGENT outstanding cards across projects">
      <p><strong>Overview · URGENT outstanding</strong><br>Cards aggregated across every tracked project, each tagged with a project chip and source-agent badge.</p>
    </td>
    <td width="50%">
      <img src="docs/screenshots/02-quick-todo-composer.png" alt="Quick todo composer with project picker">
      <p><strong>Quick todo composer</strong><br>Type once, choose whether the todo lives only inside Pulse or gets appended to a specific project's <code>pulse.md</code>.</p>
    </td>
  </tr>
  <tr>
    <td width="50%">
      <img src="docs/screenshots/03-overview-done-7d.png" alt="Completed last 7 days, git commits and pulse.md mixed">
      <p><strong>Completed · last 7 days</strong><br><code>git log</code> commits and <code>pulse.md</code> <code>[x]</code> items merged chronologically with <code>git</code> / <code>pulse</code> agent badges.</p>
    </td>
    <td width="50%">
      <img src="docs/screenshots/04-settings-rescan.png" alt="Settings → Sources tab with Rescan Desktop button">
      <p><strong>Settings · Sources + Rescan Desktop</strong><br>Add / remove / toggle sources by hand, or click <em>Rescan Desktop</em> to find newly-added projects without restarting onboarding.</p>
    </td>
  </tr>
</table>

## Features

- **Overview tab** — one-line digest (today's done count, outstanding count, projects with outstanding work) plus cross-project sections: 🔴 URGENT outstanding, 🟡 HIGH outstanding, completed in the last 24h, completed in the last 7d (collapsed by default).
- **Per-project tabs** — drill into a single project's todos and recent commits.
- **Priority detection** — bullets prefixed with `🔴` / `🟡`, or grouped under `### 🔴 URGENT` / `### 🟡 HIGH` headings, are surfaced in the priority sections automatically. No config required.
- **Quick todo** — type a one-liner in the popover; either keep it Pulse-only or write it to a project's `pulse.md` so your AI assistant sees it on the next session.
- **Settings**
  - `Sources` — add / remove / toggle markdown and git sources.
  - `Filters` — pick a git commit filter preset (`Minimal` = `feat`/`fix` only, `Recommended`, `All`).
  - **Rescan Desktop** — find new projects added since onboarding.
- **Auto-refresh** — markdown sources update via `FSEventStream` with a 1-second debounce; git logs are scanned every 5 minutes as a backstop.
- **Keyboard** — `⌘,` Settings, `⌘R` Refresh, `⌘Q` Quit.

## Supported sources

| Source | What Pulse reads |
| --- | --- |
| `CLAUDE.md` | GitHub-flavored task list checkboxes (`- [ ]`, `- [x]`) under any heading |
| `AGENTS.md` | Same, for Codex / Cursor |
| `GEMINI.md` | Same, for Gemini CLI |
| `pulse.md` | Pulse's own convention; Quick Todo writes here |
| `git log` | Conventional Commits (`feat:`, `fix:`, `chore:`, etc.) from the last 30 days |

## Install

Pulse is free and not signed by Apple, because paying $99/year for an Apple Developer ID just to ship a free open-source tool isn't a trade I'm willing to make. There are two install paths — pick whichever you prefer.

### Path A — download the dmg (one extra click on first open)

1. Download `Pulse-x.y.z.dmg` from the [GitHub Releases](https://github.com/inertia/pulse/releases) page.
2. Mount it, drag `Pulse.app` into `/Applications`.
3. **First launch only**: right-click `Pulse.app` in `/Applications` → `Open` → in the dialog click `Open` again. macOS won't ask after that.

If you skipped step 3 and already saw the "unidentified developer" warning, you can clear the quarantine attribute from the terminal:

```bash
xattr -dr com.apple.quarantine /Applications/Pulse.app
```

This is exactly what the right-click trick does under the hood. Either works.

### Path B — build from source (no dmg, no warning)

Build with your own toolchain. Locally-built apps don't go through Gatekeeper, so there's no warning to bypass.

```bash
brew install xcodegen     # one-time
git clone https://github.com/inertia/pulse.git
cd pulse
./Scripts/build-and-install.sh
```

The script generates the Xcode project, builds the Public Release configuration, copies `Pulse.app` to `/Applications`, and launches it. Takes about 30-60 seconds on first run.

### What happens on first launch

Pulse asks macOS for read access to common dev folders (`~/Desktop`, `~/Projects`, `~/code`, `~/Developer`, `~/Documents`), scans one level deep for projects containing the supported markdown files, and lets you pick which to track. After onboarding, Pulse lives in your menubar (no Dock icon) and starts watching the chosen sources.

## First-launch and daily use

**First launch**

1. Pulse asks macOS for permission to read the standard dev folders.
2. Onboarding scans for projects and shows them in a list with checkboxes.
3. Tick the projects you want, click Done.

**Daily use**

- Click the Pulse icon in the menubar to open the popover. Click anywhere outside to dismiss, or press `⌘W`.
- The Overview tab is selected by default and shows cross-project priority + recent work.
- Use the tab bar to switch to a per-project view when you need detail.
- The `+` button in the popover footer is the Quick Todo composer.

## Keyboard shortcuts

| Shortcut | Action |
| --- | --- |
| `⌘,` | Open Settings |
| `⌘R` | Refresh sources now |
| `⌘Q` | Quit Pulse |
| `⌘W` | Close popover |

## Privacy and the read-only contract

Pulse is **read-only against the files you point it at**. It will never modify your `CLAUDE.md`, `AGENTS.md`, `GEMINI.md`, or any file in a `.git` directory. The single exception is `pulse.md`, which is Pulse's own convention — when you use Quick Todo and target a project, Pulse appends a single line to that project's `pulse.md` (creating the file if it doesn't exist).

You can verify the read-only contract by running `./Scripts/verify-readonly.sh` (requires `jq`: `brew install jq`).

Pulse does not phone home, does not collect telemetry, and does not require a network connection.

## System requirements

- macOS 14 Sonoma or later
- Apple Silicon or Intel
- About 30 MB disk; a few MB RAM

## Contributing

Issues and pull requests are welcome at [github.com/inertia/pulse](https://github.com/inertia/pulse). Please open an issue first for non-trivial changes so we can align on direction before you write code.

## License

MIT — see [LICENSE](LICENSE).

---

## 中文說明（簡述）

Pulse 是一個 macOS 工具列應用，用來跨專案匯總待辦與最近完成的工作。為使用 Claude Code / Codex / Cursor / Gemini CLI 等 AI 程式助手、且需要在多個 repo 之間切換的開發者打造。Pulse 唯讀讀取每個專案的 `CLAUDE.md` / `AGENTS.md` / `GEMINI.md` / `pulse.md` checkbox 跟 `git log` conventional commits，在工具列彈出視窗顯示成「待辦」與「已完成」卡片。

從 [GitHub Releases](https://github.com/inertia/pulse/releases) 下載 dmg，拖到 Applications。首次啟動會掃描 `~/Desktop` 等常見開發資料夾，讓你勾選要追蹤的專案。常駐工具列無 dock icon。

需要 macOS 14（Sonoma）以上。MIT 授權。
