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
    static func hookBlock() -> String {
        """
        \(startMarker)
        📋 **此專案的工作清單與 commit 紀錄統一在 [`pulse.md`](./pulse.md)。**

        每次 session 開始時請先讀 `pulse.md` 看現在做什麼、剛做完什麼。
        Pulse menubar app 會自動寫入；user 可隨時編輯。
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
