import Foundation

/// Ingester for `claudeMd` / `agentsMd` / `geminiMd` source kinds.
/// All three use the same MultiStrategyMarkdownParser; only the file path differs.
struct MarkdownIngester: Ingester {
    let parser: MultiStrategyMarkdownParser

    init(parser: MultiStrategyMarkdownParser = MultiStrategyMarkdownParser()) {
        self.parser = parser
    }

    func fetch(source: Source) async throws -> [Card] {
        guard FileManager.default.fileExists(atPath: source.path.path) else { return [] }
        return try parser.parse(filePath: source.path, sourceId: source.id)
    }
}
