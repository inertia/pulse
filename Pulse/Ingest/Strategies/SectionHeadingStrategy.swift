import Foundation

/// Parses plain dash bullets (`- 文字`) inside trigger headings such as
/// `## To Do` / `## Done` — the spec §4.1 v1 fixture format that has no
/// checkbox or emoji marker. The status is derived purely from the enclosing
/// heading.
///
/// Trigger headings are matched by **full equality** (case-insensitive) against
/// two keyword groups; substring is intentionally NOT enough — `### URGENT
/// (foo)` is `NumberedSectionStrategy`'s territory:
/// - **Todo headings** → `.todo` (`To Do`, `Todo`, `TODO`, `Planned Work`, `待辦`)
/// - **Done headings** → `.done` (`Done`, `DONE`, `Recently Done`,
///   `Recent Work`, `已完成`)
///
/// Heading level (h1-h6) is irrelevant; only the trimmed heading text matters.
///
/// Orthogonality: dash bullets that match other strategies' patterns are
/// skipped here. Specifically:
/// - `- [ ]` / `- [x]` / `- [X]` → CheckboxStrategy
/// - `- ✅` → EmojiCheckmarkStrategy
/// - `- ⏳` / `- ❌` → explicitly skipped (not Pulse-ingested)
/// - `1. ...` numbered → NumberedSectionStrategy
///
/// Sub-bullets immediately following a matched line (indented 2+ spaces,
/// starting with `- `) are folded into that card's `body`, matching the
/// convention in `CheckboxStrategy` / `EmojiCheckmarkStrategy`.
///
/// Strategy is intentionally raw: dates, tags, and other normalization are NOT
/// applied here — that's the job of the parser composition step (Task 14).
struct SectionHeadingStrategy: MarkdownStrategy {

    // MARK: - Trigger heading keywords (full match, case-insensitive)

    private static let todoHeadings: Set<String> = [
        "to do", "todo", "planned work", "待辦"
    ]

    private static let doneHeadings: Set<String> = [
        "done", "recently done", "recent work", "已完成"
    ]

    // MARK: - Regexes

    // ^(#{1,6})\s+(.+)$  → markdown heading
    private static let headingRegex: NSRegularExpression = {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: #"^(#{1,6})\s+(.+)$"#)
    }()

    // ^[\s]*-\s+(.+)$  → plain dash bullet (post-filtering for orthogonality)
    private static let dashBulletRegex: NSRegularExpression = {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: #"^[\s]*-\s+(.+)$"#)
    }()

    // ^[\s]*-\s+\[[ xX]\]  → checkbox bullet (skip — CheckboxStrategy)
    private static let checkboxBulletRegex: NSRegularExpression = {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: #"^[\s]*-\s+\[[ xX]\]"#)
    }()

    // ^[\s]*-\s+(✅|⏳|❌)  → emoji bullet (skip)
    private static let emojiBulletRegex: NSRegularExpression = {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: #"^[\s]*-\s+(✅|⏳|❌)"#)
    }()

    // ^\s{2,}-\s+  → indented sub-bullet (continuation body)
    private static let subBulletRegex: NSRegularExpression = {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: #"^\s{2,}-\s+"#)
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

            // Only attempt dash-bullet parse inside trigger sections.
            guard let triggerStatus = currentTrigger else {
                index += 1
                continue
            }

            // Orthogonality: skip lines other strategies own.
            if Self.isCheckboxBullet(line) || Self.isEmojiBullet(line) {
                index += 1
                continue
            }

            if let title = Self.matchDashBullet(line) {
                // Collect indented sub-bullets immediately following.
                var bodyLines: [String] = []
                var lookahead = index + 1
                while lookahead < lines.count {
                    let next = lines[lookahead]
                    if Self.isSubBullet(next) {
                        // Strip leading whitespace, keep the "- " prefix.
                        let trimmed = next.drop { $0 == " " || $0 == "\t" }
                        bodyLines.append(String(trimmed))
                        lookahead += 1
                    } else {
                        break
                    }
                }

                let body: String? = bodyLines.isEmpty ? nil : bodyLines.joined(separator: "\n")

                items.append(ParsedItem(
                    title: title,
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

    /// Returns `.todo` / `.done` if the heading text (case-insensitive, trimmed)
    /// fully equals a trigger keyword; otherwise `nil`.
    private static func triggerStatus(for heading: String) -> Status? {
        let normalized = heading.lowercased()
        if doneHeadings.contains(normalized) {
            return .done
        }
        if todoHeadings.contains(normalized) {
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

    private static func matchDashBullet(_ line: String) -> String? {
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = dashBulletRegex.firstMatch(in: line, options: [], range: range),
              match.numberOfRanges >= 2,
              let titleRange = Range(match.range(at: 1), in: line) else {
            return nil
        }
        return String(line[titleRange])
    }

    private static func isCheckboxBullet(_ line: String) -> Bool {
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        return checkboxBulletRegex.firstMatch(in: line, options: [], range: range) != nil
    }

    private static func isEmojiBullet(_ line: String) -> Bool {
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        return emojiBulletRegex.firstMatch(in: line, options: [], range: range) != nil
    }

    private static func isSubBullet(_ line: String) -> Bool {
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        return subBulletRegex.firstMatch(in: line, options: [], range: range) != nil
    }
}
