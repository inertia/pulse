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
/// Task 20: sequential / single-thread. Task 21 will add parallel + cancellable.
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
    static let detectedFilenames = ["CLAUDE.md", "AGENTS.md", "GEMINI.md"]

    let roots: [URL]
    let depth: Int

    init(roots: [URL] = AutoSourceDetector.scanRoots, depth: Int = 2) {
        self.roots = roots
        self.depth = depth
    }

    /// Scan `roots` to `depth` layers (DFS bounded by depth), returning all
    /// dirs that contain any `detectedFilenames` file. Deduped by canonical
    /// (symlink-resolved) path.
    func scan() async -> [DetectedProject] {
        var results: [DetectedProject] = []
        var seen = Set<String>()
        for root in roots {
            scanDirectory(root, currentDepth: 0, results: &results, seen: &seen)
        }
        return results
    }

    private func scanDirectory(_ dir: URL,
                                 currentDepth: Int,
                                 results: inout [DetectedProject],
                                 seen: inout Set<String>) {
        guard currentDepth <= depth else { return }
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: dir.path, isDirectory: &isDir), isDir.boolValue else { return }
        if Self.skipDirNames.contains(dir.lastPathComponent) { return }

        // Detect project files in this directory
        if let project = inspect(dir: dir),
           seen.insert(dir.standardizedFileURL.path).inserted {
            results.append(project)
        }

        // Recurse into subdirectories (DFS bounded by depth)
        if currentDepth < depth {
            guard let contents = try? fm.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { return }
            for entry in contents {
                var subIsDir: ObjCBool = false
                if fm.fileExists(atPath: entry.path, isDirectory: &subIsDir), subIsDir.boolValue {
                    scanDirectory(entry, currentDepth: currentDepth + 1,
                                  results: &results, seen: &seen)
                }
            }
        }
    }

    private func inspect(dir: URL) -> DetectedProject? {
        let fm = FileManager.default
        var detectedFiles: [SourceKind] = []
        var newestMtime: Date? = nil

        for filename in Self.detectedFilenames {
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
