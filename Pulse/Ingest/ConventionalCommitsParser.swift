import Foundation

/// Parses raw `git log` output (records separated by U+001E, fields by tab)
/// into `Card` instances. Only commits whose subject matches the conventional
/// commits pattern AND whose type is in `enabledTypes` are emitted.
/// Non-conformant lines are silently dropped.
enum ConventionalCommitsParser {
    // 三類前綴：
    // (1) 標準 conventional commit 十種
    // (2) 黃孫權日常研究工序 type：daily 報、papers 入庫、audit、skill 沉澱、pulse todo 同步等
    // (3) 中文 repo 前綴：commit subject 以專案名直接開頭時的慣例
    // 分隔符放寬，type 後三種寫法皆認：
    //   (a) 冒號（半形 `:` 或全形 `：`），冒號後可帶 0+ 空白：`feat: x`、`feat:x`、`矽盾：archive`
    //   (b) 純空白（無冒號）：`daily 5/20 B 區：…`、`add 045 期日報 …`、`中國技術道路 2026-05-20 日報`
    private static let pattern =
        #"^(feat|fix|refactor|perf|chore|docs|build|ci|style|test|daily|papers|pulse|skill|audit|add|wip|revert|矽盾週報|矽盾|新大眾文藝|中國技術道路|破週報|文化與技術三部曲)(?:\([^)]*\))?(?:[:：]\s*|\s+)(.+)$"#

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
