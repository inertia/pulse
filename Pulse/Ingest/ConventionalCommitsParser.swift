import Foundation

/// Parses raw `git log` output (records separated by U+001E, fields by tab)
/// into `Card` instances. Only commits whose subject matches the conventional
/// commits pattern AND whose type is in `enabledTypes` are emitted.
/// Non-conformant lines are silently dropped.
enum ConventionalCommitsParser {
    private static let pattern =
        #"^(feat|fix|refactor|perf|chore|docs|build|ci|style|test)(?:\([^)]*\))?:\s+(.+)$"#

    /// Parse raw `git log` output into cards. Each conventional commit becomes
    /// a `.done` Card whose `id` is the commit SHA (already content-addressable).
    static func parse(stdout: String,
                      sourceId: UUID,
                      repoLabel: String,
                      enabledTypes: Set<String>) -> [Card] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]

        var cards: [Card] = []
        for raw in stdout.components(separatedBy: "\u{1e}") {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }

            let parts = trimmed.components(separatedBy: "\t")
            guard parts.count >= 3 else { continue }

            let sha = parts[0]
            let dateStr = parts[1]
            let subject = parts[2]
            let body = parts.count > 3 ? parts[3] : ""

            let nsSubject = subject as NSString
            let range = NSRange(location: 0, length: nsSubject.length)
            guard let match = regex.firstMatch(in: subject, range: range) else { continue }

            let type = nsSubject.substring(with: match.range(at: 1))
            guard enabledTypes.contains(type) else { continue }
            let titleAfterType = nsSubject.substring(with: match.range(at: 2))

            let card = Card(
                id: sha,
                sourceId: sourceId,
                title: titleAfterType,
                body: body.isEmpty ? nil : body,
                status: .done,
                dueDate: nil,
                completedAt: isoFormatter.date(from: dateStr),
                sourceRef: sha,
                tags: repoLabel.isEmpty ? [type] : [repoLabel, type]
            )
            cards.append(card)
        }
        return cards
    }
}
