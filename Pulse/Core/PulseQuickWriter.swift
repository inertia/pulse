import Foundation

/// Appends a quick todo line to a project's `PULSE_QUICK.md` file.
/// File is auto-created with a header on first write. Format is standard
/// markdown checkbox under `## To Do`, so:
/// - Pulse's own MarkdownIngester picks it up via SectionHeadingStrategy
/// - Claude Code / any LLM reading the project sees it naturally
///
/// Pulse never modifies CLAUDE.md / AGENTS.md / GEMINI.md (G7 read-only); this
/// is a Pulse-managed file living alongside.
enum PulseQuickWriter {

    enum WriteError: Error {
        case ioFailed(underlying: Error)
    }

    /// Append a todo entry. Creates the file with a header if it doesn't exist.
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
                # PULSE_QUICK

                Pulse 快速記檔。Auto-managed by Pulse menubar app — quick notes & todos
                that Claude Code (or any project tooling) can read alongside CLAUDE.md.

                ## To Do

                """
                try (header + entry).write(to: url, atomically: true, encoding: .utf8)
            }
        } catch {
            throw WriteError.ioFailed(underlying: error)
        }
        return url
    }

    /// `<project>/PULSE_QUICK.md`
    static func quickFileURL(for projectDir: URL) -> URL {
        projectDir.appendingPathComponent("PULSE_QUICK.md")
    }

    /// Format a single entry: `- [ ] (YYYY-MM-DD) title`
    static func formatEntry(title: String, date: Date = Date()) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        let dateStr = formatter.string(from: date)
        return "- [ ] (\(dateStr)) \(trimmed)\n"
    }

    /// If existing content lacks `## To Do`, append the heading before the new entry.
    static func ensureToDoSection(_ content: String) -> String {
        if content.range(of: "## To Do", options: [.caseInsensitive]) != nil {
            // Has section. Append at end (simple — does not insert mid-section).
            // Trailing newline guaranteed.
            return content.hasSuffix("\n") ? content : content + "\n"
        }
        let suffix = content.hasSuffix("\n") ? "" : "\n"
        return content + suffix + "\n## To Do\n\n"
    }
}
