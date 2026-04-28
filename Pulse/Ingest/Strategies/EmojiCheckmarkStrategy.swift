import Foundation

/// Parses 黃孫權's personal-style emoji checkmark bullets (`- ✅` / `- ⏳` / `- ❌`).
///
/// Only `✅` produces a `ParsedItem` (status `.done`); `⏳` (in-progress) and
/// `❌` (cancelled) lines are skipped — Pulse only ingests done items via this
/// strategy. Sub-bullets immediately following a matched line (indented 2+
/// spaces, starting with `- `) are folded into that card's `body`, matching
/// the convention in `CheckboxStrategy`.
///
/// Strategy is intentionally raw: dates, tags, and other normalization are NOT
/// applied here — that's the job of the parser composition step (Task 14).
struct EmojiCheckmarkStrategy: MarkdownStrategy {

    // ^(#{1,6})\s+(.+)$  → markdown heading
    private static let headingRegex: NSRegularExpression = {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: #"^(#{1,6})\s+(.+)$"#)
    }()

    // ^[\s]*-\s+(✅|⏳|❌)\s*(.+)$  → emoji checkmark bullet
    private static let emojiRegex: NSRegularExpression = {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: #"^[\s]*-\s+(✅|⏳|❌)\s*(.+)$"#)
    }()

    // ^\s{2,}-\s+  → indented sub-bullet (continuation body)
    private static let subBulletRegex: NSRegularExpression = {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: #"^\s{2,}-\s+"#)
    }()

    func parse(lines: [String], sourcePath: URL) -> [ParsedItem] {
        var items: [ParsedItem] = []
        var currentHeading = ""

        var index = 0
        while index < lines.count {
            let line = lines[index]
            let lineNumber = index + 1

            if let heading = Self.matchHeading(line) {
                currentHeading = heading
                index += 1
                continue
            }

            if let (mark, title) = Self.matchEmoji(line) {
                // Only ✅ emits a ParsedItem; ⏳ / ❌ are consumed (so we still
                // collect their sub-bullets to advance index) but skipped.
                guard mark == "✅" else {
                    index += 1
                    continue
                }

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
                    status: .done,
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

    private static func matchEmoji(_ line: String) -> (mark: String, title: String)? {
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = emojiRegex.firstMatch(in: line, options: [], range: range),
              match.numberOfRanges >= 3,
              let markRange = Range(match.range(at: 1), in: line),
              let titleRange = Range(match.range(at: 2), in: line) else {
            return nil
        }
        return (String(line[markRange]), String(line[titleRange]))
    }

    private static func isSubBullet(_ line: String) -> Bool {
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        return subBulletRegex.firstMatch(in: line, options: [], range: range) != nil
    }
}
