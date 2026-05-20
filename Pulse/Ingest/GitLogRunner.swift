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

    /// Default time window for git log. User picked 30 days (2026-04-28) to keep
    /// monthly retro view; older commits dropped to reduce noise.
    static let defaultSinceDays = 30

    /// Run `git -C <dir> log --pretty=%H%x09%aI%x09%s%x09%b%x1e --since=<days> ago -n <limit>` and return stdout.
    ///
    /// 注意：兩條 pipe 都用背景 thread 邊跑邊讀，再 `waitUntilExit()`。
    /// 早期版本 `waitUntilExit()` 在前、`readDataToEndOfFile()` 在後，當 stdout 量超過
    /// pipe 緩衝（~64KB，例如多行 commit body × 50 筆，新大眾文藝/矽盾 daily 工序常見）
    /// 時，git 會 block 在 write，而 Swift 在 wait，雙方互鎖（實測卡 7+ 分鐘無進度）。
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

        var outData = Data()
        var errData = Data()
        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            outData = outPipe.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }

        try p.run()
        p.waitUntilExit()
        group.wait()   // 確認兩條 pipe 都讀完（child 已關閉檔案）

        guard p.terminationStatus == 0 else {
            throw GitLogError.failed(p.terminationStatus,
                                     stderr: String(decoding: errData, as: UTF8.self))
        }
        return String(decoding: outData, as: UTF8.self)
    }
}
