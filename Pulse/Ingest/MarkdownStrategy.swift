import Foundation

struct ParsedItem: Equatable {
    let title: String           // raw title from markdown line; normalization (date / #tag stripping) happens later in MultiStrategyMarkdownParser (Task 14)
    let body: String?
    let status: Status
    let lineNumber: Int         // 1-indexed
    let sectionHeading: String  // 所屬 section（為 identity 用）；空字串若不在任何 ## / ### 段內
    let dueDate: Date?          // populated by parser composition step, not strategies
    let completedAt: Date?      // populated by parser composition step, not strategies
    let tags: [String]          // populated by parser composition step, not strategies
}

protocol MarkdownStrategy {
    func parse(lines: [String], sourcePath: URL) -> [ParsedItem]
}
