import Foundation

/// Sweeps aged `- [x] (done YYYY-MM-DD) ...` lines out of pulse.md files.
///
/// User decision (2026-04-28 HANDOFF Q1): completed items past 30 days are
/// deleted outright. Commit log covers "what was done" history; pulse.md
/// stays a live working list. Bootstrap `- [x]` lines without a `(done ...)`
/// marker are left alone — only Claude-Code-managed completions get pruned.
enum PulseFileMaintenance {

    static let doneRegex: NSRegularExpression = {
        // Anchor to start of line; capture the YYYY-MM-DD inside `(done ...)`.
        // Tolerates one optional space between `[x]` and `(done`.
        let pattern = #"^- \[x\] \(done (\d{4}-\d{2}-\d{2})\)"#
        return try! NSRegularExpression(pattern: pattern)
    }()

    /// For each URL, read its content, drop aged `- [x] (done ...)` lines, and
    /// rewrite if anything changed. Best-effort: per-file IO failures are
    /// swallowed (a missing or unreadable pulse.md should not crash refresh).
    /// Returns total lines removed across all files.
    @discardableResult
    static func cleanAgedDoneItems(
        pulseURLs: [URL],
        now: Date = Date(),
        ageDays: Int = 30
    ) -> Int {
        var totalRemoved = 0
        for url in pulseURLs {
            guard let content = try? String(contentsOf: url, encoding: .utf8) else { continue }
            let (cleaned, removed) = cleanLines(content, now: now, ageDays: ageDays)
            guard removed > 0 else { continue }
            try? cleaned.write(to: url, atomically: true, encoding: .utf8)
            totalRemoved += removed
        }
        return totalRemoved
    }

    /// Pure helper: scan `content` line-by-line, drop any `- [x] (done D)`
    /// where `D` is more than `ageDays` before `now`. Preserves all other
    /// lines and final-newline state. Malformed dates → keep the line.
    static func cleanLines(_ content: String, now: Date, ageDays: Int) -> (String, Int) {
        let hasTrailingNewline = content.hasSuffix("\n")
        // `components(separatedBy:)` keeps a trailing empty string if input
        // ends in `\n`; we'll re-add the newline at the end instead.
        var lines = content.components(separatedBy: "\n")
        if hasTrailingNewline, lines.last == "" {
            lines.removeLast()
        }

        let cutoff = now.addingTimeInterval(-Double(ageDays) * 86400)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.locale = Locale(identifier: "en_US_POSIX")

        var removed = 0
        let kept: [String] = lines.compactMap { line in
            let range = NSRange(line.startIndex..<line.endIndex, in: line)
            guard let match = doneRegex.firstMatch(in: line, range: range),
                  match.numberOfRanges >= 2,
                  let dateRange = Range(match.range(at: 1), in: line),
                  let doneDate = formatter.date(from: String(line[dateRange]))
            else { return line }
            if doneDate < cutoff {
                removed += 1
                return nil
            }
            return line
        }

        var rebuilt = kept.joined(separator: "\n")
        if hasTrailingNewline {
            rebuilt += "\n"
        }
        return (rebuilt, removed)
    }
}
