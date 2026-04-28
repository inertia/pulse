import Foundation

/// Writes / updates a Pulse-managed delimited section inside a project's
/// CLAUDE.md so Claude Code (and any LLM reading CLAUDE.md) sees a pointer to
/// `pulse.md` for the project's todos and commit log.
///
/// Pulse only modifies content between `<!-- pulse-hook:start -->` and
/// `<!-- pulse-hook:end -->` markers. User can delete the markers at any time;
/// Pulse won't re-add (respects intent).
enum CLAUDEMdHookWriter {

    static let startMarker = "<!-- pulse-hook:start -->"
    static let endMarker = "<!-- pulse-hook:end -->"

    /// Generate the hook block content (markers included).
    /// Tells Claude Code session: read pulse.md, and auto-record certain user
    /// utterances as todos (trigger phrase semantic match).
    static func hookBlock() -> String {
        """
        \(startMarker)
        📋 **此專案的工作清單在 [`pulse.md`](./pulse.md)。**

        **Session 開始**：先讀 pulse.md 看 outstanding todos。

        **自動加 todo 規則**：user 講以下類型語句時，append 到 pulse.md `## To Do` 段：

        觸發語句：
        - 「加 todo」/「加待辦」/「加進清單」/「加上 X」
        - 「優先處理 X」/「要先做 X」/「P0」/「緊急」
        - 「下次要做 X」/「下一輪」/「下一步」
        - 「記下來」/「不要忘記」/「記得處理」
        - "add todo X" / "TODO: X" / "make X a priority"

        格式：在 `## To Do` 段尾 append：
        - 普通：`- [ ] (YYYY-MM-DD) {內容}`
        - 緊急 / P0：`- [ ] 🔴 (YYYY-MM-DD) {內容}`
        - 高優先：`- [ ] 🟡 (YYYY-MM-DD) {內容}`

        寫完一句確認：「已記 pulse.md：[xxx]」

        **完成 / 刪除規則**：user 講以下類型語句時，更新 pulse.md `## To Do` 對應行：

        完成觸發：「X 完成」/「X 做完了」/「X 結了」/「done X」/「finished X」
        → 找到對應 `- [ ]` 行，改成 `- [x] (done YYYY-MM-DD)` + 原內容

        刪除觸發：「幫我刪掉 X」/「不要這條 X」/「拿掉 X」/「remove X」/「drop X」
        → 找到對應 `- [ ]` 或 `- [x]` 行，整行 remove

        寫完一句確認：「已標完成：[xxx]」或「已刪除：[xxx]」

        **注意**：完成 30 天後 Pulse 會自動清掉那行（commit log 已涵蓋歷史）。

        **不要寫**：
        - 已完成（git commit log 涵蓋）
        - brainstorm 中、未拍板要做
        - session-only 步驟（用 TodoWrite tool）

        Pulse menubar app 自動讀 pulse.md 顯示在系統工具列。
        \(endMarker)
        """
    }

    /// Ensure CLAUDE.md has the hook block. Idempotent:
    /// - If markers absent: append hook block at end
    /// - If markers present: leave as-is (don't overwrite — user may have edited)
    /// - If CLAUDE.md absent: do nothing (don't create CLAUDE.md just for hook)
    ///
    /// Returns true if file was written.
    @discardableResult
    static func ensureHook(in claudeMdURL: URL) throws -> Bool {
        let fm = FileManager.default
        guard fm.fileExists(atPath: claudeMdURL.path) else { return false }

        let existing = try String(contentsOf: claudeMdURL, encoding: .utf8)
        if existing.contains(startMarker) {
            return false   // hook already present (or user-customized between markers)
        }

        let suffix = existing.hasSuffix("\n") ? "" : "\n"
        let appended = existing + suffix + "\n" + hookBlock() + "\n"
        try appended.write(to: claudeMdURL, atomically: true, encoding: .utf8)
        return true
    }

    /// Standard CLAUDE.md location for a project: `<projectDir>/CLAUDE.md`.
    /// Returns the URL even if the file doesn't exist (caller checks).
    static func claudeMdURL(for projectDir: URL) -> URL {
        projectDir.appendingPathComponent("CLAUDE.md")
    }
}
