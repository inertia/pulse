import Foundation

/// Composes the four `MarkdownStrategy` implementations, normalizes each
/// `ParsedItem`'s raw title (extracts trailing date → `dueDate` / `completedAt`,
/// inline `#tag` occurrences → `tags`, trims whitespace), then builds `Card`s
/// with content-keyed identity.
///
/// Cross-strategy dedup: if two strategies emit `ParsedItem`s that hash to the
/// same `Card.id` (path + sectionHeading + normalizedTitle), only the first is
/// kept. Spec §4.5, §4.8.
final class MultiStrategyMarkdownParser {
    private let strategies: [MarkdownStrategy]

    init(strategies: [MarkdownStrategy] = MultiStrategyMarkdownParser.defaultStrategies) {
        self.strategies = strategies
    }

    /// v0.1 defaults: tight match only. NumberedSectionStrategy excluded because
    /// it triggers on `### URGENT` / `### HIGH` etc which are often "structured
    /// priority lists" rather than actionable todos and produce noise. Users
    /// who want it can construct the parser explicitly with that strategy.
    static var defaultStrategies: [MarkdownStrategy] {
        [
            CheckboxStrategy(),
            EmojiCheckmarkStrategy(),
            SectionHeadingStrategy()
        ]
    }

    func parse(filePath: URL, sourceId: UUID) throws -> [Card] {
        let raw = try String(contentsOf: filePath, encoding: .utf8)
        let lines = raw.components(separatedBy: "\n")

        // 1. Run each strategy, collect all ParsedItems.
        let allItems = strategies.flatMap { $0.parse(lines: lines, sourcePath: filePath) }

        // 2. Normalize each item then build a Card. Dedup across strategies via id.
        var seenIds = Set<String>()
        var cards: [Card] = []
        for item in allItems {
            let normalized = normalize(item: item)
            let card = Card(
                id: Card.makeId(
                    path: filePath.path,
                    sectionHeading: normalized.sectionHeading,
                    normalizedTitle: normalized.title
                ),
                sourceId: sourceId,
                title: normalized.title,
                body: normalized.body,
                status: normalized.status,
                dueDate: normalized.dueDate,
                completedAt: normalized.completedAt,
                sourceRef: "\(filePath.lastPathComponent):\(item.lineNumber)",
                tags: normalized.tags
            )
            if seenIds.insert(card.id).inserted {
                cards.append(card)
            }
        }
        return cards
    }

    // MARK: - Normalization

    /// Returns a `ParsedItem` with normalized title (date / `#tag` stripped) and
    /// populated `dueDate` / `completedAt` / `tags` derived from the raw title.
    private func normalize(item: ParsedItem) -> ParsedItem {
        var title = item.title
        var dueDate: Date? = nil
        var completedAt: Date? = nil

        // Extract trailing date FIRST so `#tag` regex doesn't trip on hash inside (YYYY-MM-DD).
        if let (date, range) = extractTrailingDate(in: title) {
            switch item.status {
            case .todo: dueDate = date
            case .done: completedAt = date
            }
            title.removeSubrange(range)
        }

        // Extract inline #tags throughout the (possibly already date-stripped) title.
        let (cleanedTitle, foundTags) = extractTags(from: title)
        title = cleanedTitle

        // Final trim of any leading/trailing whitespace introduced by stripping.
        title = title.trimmingCharacters(in: .whitespacesAndNewlines)

        // Derive priority hint from enclosing section heading. pulse.md
        // convention puts 🔴/🟡/🟢 on the heading (`### 🔴 URGENT`), not the
        // bullet itself, so query-time `title.hasPrefix("🔴")` would miss
        // those. Surface the signal through a synthetic tag the aggregator
        // can read alongside the title-prefix path. The hook format
        // `- [ ] 🔴 (...)` (emoji on bullet) is still detected by title prefix
        // so both layouts work.
        var augmentedTags = foundTags
        if item.sectionHeading.contains("🔴") {
            augmentedTags.append("priority-urgent")
        } else if item.sectionHeading.contains("🟡") {
            augmentedTags.append("priority-high")
        }

        return ParsedItem(
            title: title,
            body: item.body,
            status: item.status,
            lineNumber: item.lineNumber,
            sectionHeading: item.sectionHeading,
            dueDate: dueDate,
            completedAt: completedAt,
            tags: augmentedTags
        )
    }

    /// Extract a trailing `（YYYY-MM-DD）` (fullwidth) or `(YYYY-MM-DD)` (ASCII)
    /// date suffix at the end of the title. Returns the parsed date (UTC) and
    /// the substring range to strip.
    private func extractTrailingDate(in title: String) -> (Date, Range<String.Index>)? {
        let pattern = #"\s*[（(](\d{4}-\d{2}-\d{2})[）)]\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsTitle = title as NSString
        let nsRange = NSRange(location: 0, length: nsTitle.length)
        guard let match = regex.firstMatch(in: title, range: nsRange),
              match.numberOfRanges == 2 else { return nil }
        let dateString = nsTitle.substring(with: match.range(at: 1))
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        guard let date = formatter.date(from: dateString),
              let range = Range(match.range, in: title) else { return nil }
        return (date, range)
    }

    /// Extract all `#tag` occurrences (not preceded by another `#`, so heading
    /// markers don't match). Allowed chars: ASCII letters, digits, underscore,
    /// hyphen, CJK unified ideographs (U+4E00 to U+9FFF, expressed as literal
    /// `一` to `鿿`). Returns the cleaned title and the list of tag names (no
    /// leading `#`).
    ///
    /// Note: cannot use `\u{4e00}` etc. inside the regex pattern. Swift's raw
    /// string `#"..."#` does not interpret `\u{...}` escapes, and
    /// `NSRegularExpression` itself does not parse them either. Embedding the
    /// literal codepoints in a regular Swift string is the only working form.
    private func extractTags(from title: String) -> (String, [String]) {
        let pattern = "(?<!#)#([A-Za-z0-9_\u{4e00}-\u{9fff}-]+)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return (title, []) }
        let nsTitle = title as NSString
        let matches = regex.matches(in: title, range: NSRange(location: 0, length: nsTitle.length))
        let tags = matches.map { nsTitle.substring(with: $0.range(at: 1)) }

        // Strip in reverse so earlier ranges remain valid.
        var cleaned = title
        for match in matches.reversed() {
            if let r = Range(match.range, in: cleaned) {
                cleaned.removeSubrange(r)
            }
        }
        // Tidy double spaces left behind by stripping mid-string tags.
        while cleaned.contains("  ") {
            cleaned = cleaned.replacingOccurrences(of: "  ", with: " ")
        }
        return (cleaned, tags)
    }
}
