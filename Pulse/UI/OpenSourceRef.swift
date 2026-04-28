import AppKit
import Foundation

enum OpenSourceRef {
    /// Open a card's source reference: markdown file (in default editor) or
    /// git commit (in browser at GitHub commit URL). Falls back to opening the
    /// repo directory in Finder when the origin is missing or non-GitHub.
    static func open(card: Card, source: Source) {
        switch source.kind {
        case .claudeMd, .agentsMd, .geminiMd:
            NSWorkspace.shared.open(source.path)
        case .gitLog:
            if let commitURL = githubCommitURL(repoPath: source.path, sha: card.sourceRef) {
                NSWorkspace.shared.open(commitURL)
            } else {
                // Fallback: open repo directory in Finder.
                NSWorkspace.shared.open(source.path)
            }
        }
    }

    /// Derive `https://github.com/owner/repo/commit/<sha>` from git remote.
    /// Returns nil if origin is missing, non-GitHub, or unparseable.
    static func githubCommitURL(repoPath: URL, sha: String) -> URL? {
        guard let origin = readGitOrigin(repoPath: repoPath) else { return nil }
        guard let (owner, repo) = parseGitHubOrigin(origin) else { return nil }
        return URL(string: "https://github.com/\(owner)/\(repo)/commit/\(sha)")
    }

    /// Run `git -C <repoPath> remote get-url origin`. Returns nil if non-zero exit
    /// (no remote, not a git repo, etc.) or if stdout is empty.
    static func readGitOrigin(repoPath: URL) -> String? {
        guard let gitPath = GitLogRunner.resolveGitPath() else { return nil }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: gitPath)
        p.arguments = ["-C", repoPath.path, "remote", "get-url", "origin"]
        let outPipe = Pipe()
        p.standardOutput = outPipe
        p.standardError = Pipe()
        do { try p.run() } catch { return nil }
        p.waitUntilExit()
        guard p.terminationStatus == 0 else { return nil }
        let data = outPipe.fileHandleForReading.readDataToEndOfFile()
        let str = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        return str.isEmpty ? nil : str
    }

    /// Parse a GitHub origin URL into (owner, repo).
    /// Accepts:
    /// - SSH:    `git@github.com:owner/repo.git`
    /// - SSH:    `git@github.com:owner/repo`        (no .git)
    /// - HTTPS:  `https://github.com/owner/repo.git`
    /// - HTTPS:  `https://github.com/owner/repo`
    /// Returns nil for non-GitHub hosts or malformed input.
    static func parseGitHubOrigin(_ origin: String) -> (owner: String, repo: String)? {
        if origin.hasPrefix("git@github.com:") {
            let path = String(origin.dropFirst("git@github.com:".count))
            return splitOwnerRepo(path)
        }
        if origin.hasPrefix("https://github.com/") {
            let path = String(origin.dropFirst("https://github.com/".count))
            return splitOwnerRepo(path)
        }
        return nil
    }

    /// Split "owner/repo" or "owner/repo.git" into (owner, repo).
    /// Returns nil if there is no slash, the owner is empty, or the repo
    /// (after stripping .git) is empty.
    private static func splitOwnerRepo(_ path: String) -> (owner: String, repo: String)? {
        let parts = path.split(separator: "/", maxSplits: 1)
        guard parts.count == 2, !parts[0].isEmpty else { return nil }
        var repo = String(parts[1])
        if repo.hasSuffix(".git") { repo.removeLast(4) }
        guard !repo.isEmpty else { return nil }
        return (String(parts[0]), repo)
    }
}
