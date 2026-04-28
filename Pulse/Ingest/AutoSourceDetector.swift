import Foundation

/// A directory found to contain one or more agent-config files
/// (CLAUDE.md / AGENTS.md / GEMINI.md). Returned by `AutoSourceDetector.scan`.
struct DetectedProject: Equatable {
    let dir: URL
    let detectedFiles: [SourceKind]   // any of claudeMd / agentsMd / geminiMd
    let lastModified: Date            // newest mtime among detected files
    let isGitRepo: Bool               // dir contains .git/ subdirectory
}

/// Scans common developer-folder roots to discover directories that contain
/// `CLAUDE.md`, `AGENTS.md`, or `GEMINI.md`. Used by public-version
/// onboarding to surface candidate projects.
///
/// Task 21: each root scans in its own concurrent Task; cooperative
/// cancellation via `Task.isCancelled`; per-root-completion progress callback.
struct AutoSourceDetector {
    /// Common developer-folder roots to scan. Each is HOME-relative.
    static let scanRoots: [URL] = [
        URL(fileURLWithPath: NSHomeDirectory() + "/Desktop"),
        URL(fileURLWithPath: NSHomeDirectory() + "/Projects"),
        URL(fileURLWithPath: NSHomeDirectory() + "/code"),
        URL(fileURLWithPath: NSHomeDirectory() + "/Developer"),
        URL(fileURLWithPath: NSHomeDirectory() + "/Documents"),
    ]
    /// Directory names to skip during traversal (large vendored / build / cache trees).
    /// Belt-and-suspenders alongside `.skipsHiddenFiles`: some of these are hidden
    /// (`.git`, `.venv`, etc.), but we list them explicitly in case a system
    /// doesn't treat them as hidden.
    static let skipDirNames: Set<String> = [
        "node_modules", ".git", ".venv", "venv", "__pycache__",
        "dist", "build", "target", "vendor", ".next", ".cache",
        "DerivedData", ".DS_Store", ".pytest_cache", ".tox",
    ]
    /// Filenames whose presence in a directory marks it as a "project".
    static let detectedFilenames = ["CLAUDE.md", "AGENTS.md", "GEMINI.md", "pulse.md"]

    /// Progress callback signature: `(scanned, total)` where `scanned` is the
    /// running count of projects yielded so far, and `total` is the upfront
    /// goal — unknown for BFS, so always `nil` in v0.1.
    typealias ProgressCallback = @Sendable (Int, Int?) -> Void

    let roots: [URL]
    let depth: Int

    init(roots: [URL] = AutoSourceDetector.scanRoots, depth: Int = 2) {
        self.roots = roots
        self.depth = depth
    }

    /// Scan `roots` to `depth` layers, returning all dirs that contain any
    /// `detectedFilenames` file. Each root scans in parallel (one Task per
    /// root). Cooperatively cancellable via `Task.cancel()`. Optional
    /// `progress` callback fires once per root as it completes.
    /// Deduped by canonical (symlink-resolved) path.
    func scan(progress: ProgressCallback? = nil) async -> [DetectedProject] {
        var results: [DetectedProject] = []
        var seen = Set<String>()
        var scanned = 0

        await withTaskGroup(of: [DetectedProject].self) { group in
            for root in roots {
                group.addTask {
                    await Self.scanRootParallel(root, depth: depth)
                }
            }
            for await rootResults in group {
                if Task.isCancelled { break }
                for project in rootResults {
                    let key = project.dir.standardizedFileURL.path
                    if seen.insert(key).inserted {
                        results.append(project)
                    }
                }
                scanned = results.count
                progress?(scanned, nil)
            }
        }

        return results
    }

    /// BFS within a single root. Sequential per-root (one queue, no
    /// intra-root parallelism — Desktop folders are typically O(100s),
    /// not big enough to justify it). Cooperatively cancellable.
    private static func scanRootParallel(_ root: URL, depth: Int) async -> [DetectedProject] {
        if Task.isCancelled { return [] }
        var local: [DetectedProject] = []
        var queue: [(URL, Int)] = [(root, 0)]
        let fm = FileManager.default

        while !queue.isEmpty {
            if Task.isCancelled { break }
            let (dir, currentDepth) = queue.removeFirst()
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: dir.path, isDirectory: &isDir), isDir.boolValue else { continue }
            if skipDirNames.contains(dir.lastPathComponent) { continue }

            if let project = inspect(dir: dir) {
                local.append(project)
            }

            if currentDepth < depth {
                if let contents = try? fm.contentsOfDirectory(
                    at: dir,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: [.skipsHiddenFiles]
                ) {
                    for entry in contents {
                        var subIsDir: ObjCBool = false
                        if fm.fileExists(atPath: entry.path, isDirectory: &subIsDir), subIsDir.boolValue {
                            queue.append((entry, currentDepth + 1))
                        }
                    }
                }
            }
        }
        return local
    }

    private static func inspect(dir: URL) -> DetectedProject? {
        let fm = FileManager.default
        var detectedFiles: [SourceKind] = []
        var newestMtime: Date? = nil

        for filename in detectedFilenames {
            let filePath = dir.appendingPathComponent(filename)
            guard fm.fileExists(atPath: filePath.path) else { continue }
            let kind: SourceKind = filename == "CLAUDE.md" ? .claudeMd
                                 : filename == "AGENTS.md" ? .agentsMd
                                 : .geminiMd
            detectedFiles.append(kind)
            if let attrs = try? fm.attributesOfItem(atPath: filePath.path),
               let mtime = attrs[.modificationDate] as? Date {
                if newestMtime == nil || mtime > newestMtime! {
                    newestMtime = mtime
                }
            }
        }
        guard !detectedFiles.isEmpty else { return nil }
        let isGitRepo = fm.fileExists(atPath: dir.appendingPathComponent(".git").path)
        return DetectedProject(
            dir: dir,
            detectedFiles: detectedFiles,
            lastModified: newestMtime ?? Date.distantPast,
            isGitRepo: isGitRepo
        )
    }
}
