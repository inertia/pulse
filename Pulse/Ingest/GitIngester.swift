import Foundation

/// Ingester for `gitLog` source kind.
/// Takes a snapshot `enabledTypes: Set<String>` rather than a reference to Settings,
/// so it can run on a background actor without main-actor crossing (review feedback C4).
struct GitIngester: Ingester {
    let enabledTypes: Set<String>

    func fetch(source: Source) async throws -> [Card] {
        let stdout: String
        do {
            stdout = try GitLogRunner.run(at: source.path)
        } catch let GitLogError.failed(_, stderr)
            where stderr.contains("does not have any commits yet") {
            // Freshly-initialised repo with no commits: treat as empty, not an error.
            return []
        }
        let repoLabel = source.path.lastPathComponent
        return ConventionalCommitsParser.parse(
            stdout: stdout,
            sourceId: source.id,
            repoLabel: repoLabel,
            enabledTypes: enabledTypes
        )
    }
}
