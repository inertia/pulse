import Foundation

struct ProjectGroup: Identifiable, Equatable {
    var id: String { label }
    let label: String
    let sources: [Source]
    let cards: [Card]
}
