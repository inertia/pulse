import Foundation

/// Reads/writes user-authored QuickTodos to disk, exposes ObservableObject
/// for SwiftUI bindings. Stored at
/// `~/Library/Application Support/Pulse/quick-todos.json`.
@MainActor
final class QuickTodoStore: ObservableObject {
    @Published private(set) var todos: [QuickTodo] = []
    private let url: URL

    init(directoryURL: URL? = nil) {
        let dir = directoryURL ?? Self.defaultDirectory()
        self.url = dir.appendingPathComponent("quick-todos.json")
    }

    private static func defaultDirectory() -> URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Pulse")
    }

    func load() {
        guard let data = try? Data(contentsOf: url) else { todos = []; return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        todos = (try? decoder.decode([QuickTodo].self, from: data)) ?? []
    }

    func save() throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                  withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(todos).write(to: url, options: .atomic)
    }

    func add(title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        todos.insert(QuickTodo(title: trimmed), at: 0)
        try? save()
    }

    func toggle(_ id: UUID) {
        guard let idx = todos.firstIndex(where: { $0.id == id }) else { return }
        var t = todos[idx]
        if t.status == .todo {
            t.status = .done
            t.completedAt = Date()
        } else {
            t.status = .todo
            t.completedAt = nil
        }
        todos[idx] = t
        try? save()
    }

    func remove(_ id: UUID) {
        todos.removeAll { $0.id == id }
        try? save()
    }

    /// Convert each QuickTodo to a Card for unified rendering with auto-ingested
    /// cards. Uses a fixed synthetic sourceId / sourceRef.
    func cards() -> [Card] {
        todos.map { todo in
            Card(
                id: todo.id.uuidString,
                sourceId: QuickTodoConstants.sourceId,
                title: todo.title,
                body: nil,
                status: todo.status,
                dueDate: nil,
                completedAt: todo.completedAt,
                sourceRef: "quick:\(todo.id.uuidString.prefix(8))",
                tags: ["quick"]
            )
        }
    }
}
