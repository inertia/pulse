import Foundation

/// User-authored quick todo, stored locally in Pulse's app support folder.
/// Distinct from auto-ingested cards — Pulse never writes back to source files,
/// but QuickTodos are Pulse's own writable note store.
struct QuickTodo: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var status: Status
    let createdAt: Date
    var completedAt: Date?

    init(id: UUID = UUID(),
         title: String,
         status: Status = .todo,
         createdAt: Date = Date(),
         completedAt: Date? = nil) {
        self.id = id
        self.title = title
        self.status = status
        self.createdAt = createdAt
        self.completedAt = completedAt
    }
}

/// Stable synthetic source label / id for QuickTodo grouping in the popover.
/// Unlike auto-ingested sources, Quick is not in `sources.json`; the popover
/// composes a virtual ProjectGroup from QuickTodoStore.todos.
enum QuickTodoConstants {
    /// Display label for Pulse's virtual quick-todo project. Bilingual via L.
    /// `sourceId` stays the same across builds, so cache keyed on UUID
    /// remains consistent if the user switches builds.
    static var label: String { L.quickProjectLabel }
    /// Deterministic UUID so card sourceId stays stable across launches.
    static let sourceId = UUID(uuidString: "00000000-0000-0000-0000-00000000ABCD")!
}
