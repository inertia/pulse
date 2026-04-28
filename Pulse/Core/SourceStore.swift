import Foundation

final class SourceStore {
    private let url: URL

    init(directoryURL: URL? = nil) {
        let dir = directoryURL ?? Self.defaultDirectory()
        self.url = dir.appendingPathComponent("sources.json")
    }

    private static func defaultDirectory() -> URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Pulse")
    }

    func load() -> [Source] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([Source].self, from: data)) ?? []
    }

    func save(_ sources: [Source]) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(sources).write(to: url, options: .atomic)
    }
}
