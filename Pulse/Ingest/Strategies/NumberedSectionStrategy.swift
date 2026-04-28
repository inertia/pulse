import Foundation

/// Parses 黃孫權-style numbered items inside trigger sections such as
/// `### URGENT`, `### HIGH`, `### Recently Done (2026-04-17)` etc.
///
/// Headings are matched case-insensitively as substrings against two keyword
/// groups:
/// - **Todo keywords** → `.todo` (URGENT / HIGH / MEDIUM / LOW / Planned Work / To Do / 待辦 / TODO)
/// - **Done keywords** → `.done` (Recently Done / Recent Work / 已完成 / Done / DONE)
///
/// If a heading matches both groups, Done wins (rare edge case).
///
/// Numbered items have three accepted forms (tried in order):
/// 1. `N. **Title** — body` (separator may be `—`, `-`, `:`, or `：`)
/// 2. `N. **Title only**` (body may follow as indented continuation lines)
/// 3. `N. plain title text`
///
/// Body collection: any indented continuation lines (≥ 2 leading whitespace
/// chars) immediately following the numbered line are appended to the body.
/// Collection ends at the first blank line, next numbered item at root level,
/// or next heading. Inline body (form 1) and indented continuation are joined
/// with `\n`. If neither is present, `body` is `nil`.
///
/// Strategy is intentionally raw: dates, tags, and other normalization are NOT
/// applied here — that's the job of the parser composition step (Task 14).
struct NumberedSectionStrategy: MarkdownStrategy {

    // MARK: - Keyword groups

    /// Todo keywords — heading substring match (case-insensitive) → `.todo`.
    private static let todoKeywords: [String] = [
        "URGENT", "HIGH", "MEDIUM", "LOW",
        "Planned Work", "To Do", "TODO", "待辦"
    ]

    /// Done keywords — heading substring match (case-insensitive) → `.done`.
    /// Checked BEFORE todo keywords so a heading matching both prefers Done.
    private static let doneKeywords: [String] = [
        "Recently Done", "Recent Work", "已完成", "Done", "DONE"
    ]

    // MARK: - Regexes

    // ^(#{1,6})\s+(.+)$  → markdown heading
    private static let headingRegex: NSRegularExpression = {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: #"^(#{1,6})\s+(.+)$"#)
    }()

    // ^[\s]*\d+\.\s+\*\*(.+?)\*\*\s*[—\-:：]?\s*(.+)$  → bold + optional separator + body
    //
    // Separator is optional so headings like
    //   `1. **Title**(parenthetical body)`  or
    //   `1. **Title** trailing prose`
    // also parse as form 1. Bold-only (form 2) only matches if nothing follows.
    private static let boldWithBodyRegex: NSRegularExpression = {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: #"^[\s]*\d+\.\s+\*\*(.+?)\*\*\s*[—\-:：]?\s*(.+)$"#)
    }()

    // ^[\s]*\d+\.\s+\*\*(.+?)\*\*\s*$  → bold-only (no inline body)
    private static let boldOnlyRegex: NSRegularExpression = {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: #"^[\s]*\d+\.\s+\*\*(.+?)\*\*\s*$"#)
    }()

    // ^[\s]*\d+\.\s+(.+)$  → plain numbered (fallback)
    private static let plainNumberedRegex: NSRegularExpression = {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: #"^[\s]*\d+\.\s+(.+)$"#)
    }()

    // ^\s{2,}\S  → indented continuation (≥ 2 leading whitespace + non-blank)
    private static let indentedContinuationRegex: NSRegularExpression = {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: #"^\s{2,}\S"#)
    }()

    // MARK: - Parse

    func parse(lines: [String], sourcePath: URL) -> [ParsedItem] {
        var items: [ParsedItem] = []
        var currentHeading = ""
        var currentTrigger: Status? = nil  // nil = current heading not a trigger

        var index = 0
        while index < lines.count {
            let line = lines[index]
            let lineNumber = index + 1

            if let heading = Self.matchHeading(line) {
                currentHeading = heading
                currentTrigger = Self.triggerStatus(for: heading)
                index += 1
                continue
            }

            // Only attempt numbered-item parse inside trigger sections.
            guard let triggerStatus = currentTrigger else {
                index += 1
                continue
            }

            if let parsed = Self.matchNumberedItem(line) {
                // Collect indented continuation lines for body.
                var continuationLines: [String] = []
                var lookahead = index + 1
                while lookahead < lines.count {
                    let next = lines[lookahead]
                    if next.trimmingCharacters(in: .whitespaces).isEmpty {
                        break  // blank line ends body collection
                    }
                    if Self.matchHeading(next) != nil {
                        break  // next heading ends body collection
                    }
                    if Self.matchNumberedItem(next) != nil {
                        break  // next root-level numbered item ends body collection
                    }
                    if Self.isIndentedContinuation(next) {
                        let stripped = next.drop { $0 == " " || $0 == "\t" }
                        continuationLines.append(String(stripped))
                        lookahead += 1
                    } else {
                        break  // non-indented, non-numbered, non-heading line ends body collection
                    }
                }

                // Combine inline body (if any) with indented continuation.
                var bodyParts: [String] = []
                if let inline = parsed.inlineBody, !inline.isEmpty {
                    bodyParts.append(inline)
                }
                if !continuationLines.isEmpty {
                    bodyParts.append(continuationLines.joined(separator: "\n"))
                }
                let body: String? = bodyParts.isEmpty ? nil : bodyParts.joined(separator: "\n")

                items.append(ParsedItem(
                    title: parsed.title,
                    body: body,
                    status: triggerStatus,
                    lineNumber: lineNumber,
                    sectionHeading: currentHeading,
                    dueDate: nil,
                    completedAt: nil,
                    tags: []
                ))

                index = lookahead
                continue
            }

            index += 1
        }

        return items
    }

    // MARK: - Trigger classification

    /// Returns `.done` if the heading matches a done keyword (checked first),
    /// `.todo` if it matches a todo keyword, otherwise `nil`.
    private static func triggerStatus(for heading: String) -> Status? {
        let lower = heading.lowercased()
        for keyword in doneKeywords where lower.contains(keyword.lowercased()) {
            return .done
        }
        for keyword in todoKeywords where lower.contains(keyword.lowercased()) {
            return .todo
        }
        return nil
    }

    // MARK: - Regex helpers

    private static func matchHeading(_ line: String) -> String? {
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = headingRegex.firstMatch(in: line, options: [], range: range),
              match.numberOfRanges >= 3,
              let textRange = Range(match.range(at: 2), in: line) else {
            return nil
        }
        return String(line[textRange]).trimmingCharacters(in: .whitespaces)
    }

    /// Matches a numbered item line. Returns `(title, inlineBody)` where
    /// `inlineBody` is `nil` for bold-only and plain forms.
    private static func matchNumberedItem(_ line: String) -> (title: String, inlineBody: String?)? {
        let range = NSRange(line.startIndex..<line.endIndex, in: line)

        // Form 1: bold + separator + body
        if let match = boldWithBodyRegex.firstMatch(in: line, options: [], range: range),
           match.numberOfRanges >= 3,
           let titleRange = Range(match.range(at: 1), in: line),
           let bodyRange = Range(match.range(at: 2), in: line) {
            return (String(line[titleRange]), String(line[bodyRange]))
        }

        // Form 2: bold-only
        if let match = boldOnlyRegex.firstMatch(in: line, options: [], range: range),
           match.numberOfRanges >= 2,
           let titleRange = Range(match.range(at: 1), in: line) {
            return (String(line[titleRange]), nil)
        }

        // Form 3: plain numbered (fallback)
        if let match = plainNumberedRegex.firstMatch(in: line, options: [], range: range),
           match.numberOfRanges >= 2,
           let titleRange = Range(match.range(at: 1), in: line) {
            return (String(line[titleRange]), nil)
        }

        return nil
    }

    private static func isIndentedContinuation(_ line: String) -> Bool {
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        return indentedContinuationRegex.firstMatch(in: line, options: [], range: range) != nil
    }
}
