import Foundation

/// Writes Pulse-managed `<project>/pulse.md` containing project todos and (later)
/// commit history. Designed so Claude Code sees it via a hook in CLAUDE.md
/// (CLAUDEMdHookWriter writes that hook with delimiters).
///
/// Pulse reads and writes pulse.md. Pulse never modifies CLAUDE.md outside the
/// delimited hook section.
enum PulseQuickWriter {

    static let filename = "pulse.md"

    enum WriteError: Error {
        case ioFailed(underlying: Error)
    }

    /// `<project>/pulse.md`
    static func quickFileURL(for projectDir: URL) -> URL {
        projectDir.appendingPathComponent(filename)
    }

    /// Append a todo entry. Creates file with header if missing.
    static func append(title: String, to projectDir: URL) throws -> URL {
        let url = quickFileURL(for: projectDir)
        let entry = formatEntry(title: title)
        let fm = FileManager.default
        do {
            if fm.fileExists(atPath: url.path) {
                let existing = try String(contentsOf: url, encoding: .utf8)
                let appended = ensureToDoSection(existing) + entry
                try appended.write(to: url, atomically: true, encoding: .utf8)
            } else {
                let header = """
                # \(projectDir.lastPathComponent) · pulse.md

                Pulse menubar app 自動管理本檔。歡迎 user 編輯。
                Hook 在專案 CLAUDE.md，Claude Code session 開始會自動讀。

                ## To Do

                """
                try (header + entry).write(to: url, atomically: true, encoding: .utf8)
            }
        } catch {
            throw WriteError.ioFailed(underlying: error)
        }
        return url
    }

    /// Format a single todo entry: `- [ ] (YYYY-MM-DD) title`
    static func formatEntry(title: String, date: Date = Date()) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        let dateStr = formatter.string(from: date)
        return "- [ ] (\(dateStr)) \(trimmed)\n"
    }

    /// Ensure existing content has a `## To Do` heading; if not, append one.
    static func ensureToDoSection(_ content: String) -> String {
        if content.range(of: "## To Do", options: [.caseInsensitive]) != nil {
            return content.hasSuffix("\n") ? content : content + "\n"
        }
        let suffix = content.hasSuffix("\n") ? "" : "\n"
        return content + suffix + "\n## To Do\n\n"
    }
}
