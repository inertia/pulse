import Foundation

enum GitLogError: Error {
    case gitNotFound
    case failed(Int32, stderr: String)
}

struct GitLogRunner {
    /// Try standard git binary locations in order of preference.
    /// macOS 14+ ships /usr/bin/git via Xcode CLT; Homebrew installs differ by arch.
    static let candidatePaths = [
        "/usr/bin/git",                  // macOS Xcode CLT
        "/opt/homebrew/bin/git",         // Apple Silicon Homebrew
        "/usr/local/bin/git",            // Intel Homebrew
    ]

    /// Resolve the first executable git binary among `candidatePaths`.
    static func resolveGitPath(fileManager: FileManager = .default) -> String? {
        candidatePaths.first { fileManager.isExecutableFile(atPath: $0) }
    }

    /// Default time window for git log. Reduces "old commits as fake todos" noise.
    static let defaultSinceDays = 14

    /// Run `git -C <dir> log --pretty=%H%x09%aI%x09%s%x09%b%x1e --since=<days> ago -n <limit>` and return stdout.
    static func run(at dir: URL, limit: Int = 50, sinceDays: Int = defaultSinceDays) throws -> String {
        guard let gitPath = resolveGitPath() else { throw GitLogError.gitNotFound }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: gitPath)
        p.arguments = [
            "-C", dir.path, "log",
            "--pretty=%H%x09%aI%x09%s%x09%b%x1e",
            "--since=\(sinceDays) days ago",
            "-n", String(limit)
        ]
        let outPipe = Pipe()
        let errPipe = Pipe()
        p.standardOutput = outPipe
        p.standardError = errPipe
        try p.run()
        p.waitUntilExit()
        guard p.terminationStatus == 0 else {
            let err = String(decoding: errPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            throw GitLogError.failed(p.terminationStatus, stderr: err)
        }
        return String(decoding: outPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    }
}
