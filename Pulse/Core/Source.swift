import Foundation

enum SourceKind: String, Codable, CaseIterable {
    case claudeMd, agentsMd, geminiMd, gitLog
}

struct Source: Identifiable, Codable, Equatable {
    let id: UUID
    let kind: SourceKind
    let path: URL
    let label: String
    let enabled: Bool

    init(id: UUID = UUID(), kind: SourceKind, path: URL, label: String, enabled: Bool = true) {
        self.id = id
        self.kind = kind
        self.path = path
        self.label = label
        self.enabled = enabled
    }
}
