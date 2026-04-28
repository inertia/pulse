import Foundation

struct CardCacheFile: Codable {
    let version: Int            // current = 1
    let cards: [Card]
}

@MainActor
final class CardStore: ObservableObject {
    static let currentVersion = 1
    @Published private(set) var cards: [Card] = []
    private let url: URL

    init(directoryURL: URL? = nil) {
        let dir = directoryURL ?? Self.defaultDirectory()
        self.url = dir.appendingPathComponent("cards-cache.json")
    }

    private static func defaultDirectory() -> URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Pulse")
    }

    func load() {
        // try-catch decode；version mismatch 或 decode fail → cards = []，視為 cold start
        guard let data = try? Data(contentsOf: url) else { cards = []; return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let file = try? decoder.decode(CardCacheFile.self, from: data),
              file.version == Self.currentVersion else {
            cards = []   // cold start，下次 refresh 重建
            return
        }
        cards = file.cards
    }

    func save() throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                  withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let file = CardCacheFile(version: Self.currentVersion, cards: cards)
        try encoder.encode(file).write(to: url, options: .atomic)
    }

    func replace(forSource sourceId: UUID, with newCards: [Card]) {
        cards = cards.filter { $0.sourceId != sourceId } + newCards
    }
}
