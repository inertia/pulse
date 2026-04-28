# CLAUDE.md

Pulse 是 macOS 工具列 app，自動讀取多個專案的 `CLAUDE.md` / `AGENTS.md` / `GEMINI.md` checkbox 與 git log conventional commits，彙整為 todo / done 卡片。**唯讀**。

- Spec：`docs/superpowers/specs/2026-04-28-pulse-design.md`
- Plan：`docs/superpowers/plans/2026-04-28-pulse-implementation.md`（37 tasks）
- Tech：Swift 5.9+ / SwiftUI 4 / AppKit / xcodegen + xcconfig（Internal vs Public 雙 build），macOS 14 deployment target
- Author：黃孫權 (Huang Sun-Quan, GitHub `inertia`)

不要自動 commit / push，列出變更等用戶確認。寫文字（commit message、README、註解）一律繁體中文，自撰段落不用破折號（`——`），不用 italic 斜體。
