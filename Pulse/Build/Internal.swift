import Foundation

struct PreloadedProject {
    let path: String
    let label: String
}

enum HuangSunQuanProjects {
    #if INTERNAL_BUILD
    static let list: [PreloadedProject] = [
        .init(path: "/Users/sunquanhuang/Desktop/new_heterotopias", label: "Heterotopias"),
        .init(path: "/Users/sunquanhuang/Desktop/heterotopias-next", label: "Heterotopias Next"),
        .init(path: "/Users/sunquanhuang/Desktop/md-editor", label: "md-editor"),
        .init(path: "/Users/sunquanhuang/Desktop/pots-archive", label: "破週報"),
        .init(path: "/Users/sunquanhuang/Desktop/新大眾文藝", label: "新大眾文藝"),
        .init(path: "/Users/sunquanhuang/Desktop/矽盾週報", label: "矽盾週報"),
        .init(path: "/Users/sunquanhuang/Desktop/文化與技術三部曲", label: "文化與技術三部曲"),
        .init(path: "/Users/sunquanhuang/Desktop/writing-agent", label: "writing-agent"),
        .init(path: "/Users/sunquanhuang/Desktop/中國技術道路_2008_2028", label: "中國技術道路"),
    ]
    #else
    static let list: [PreloadedProject] = []
    #endif

    /// Materialize preloaded projects into Source rows.
    /// Each project gets up to 5 sources (claudeMd / agentsMd / geminiMd / pulse.md / gitLog).
    /// pulse.md is the Pulse-managed convention (todos + commit log per project).
    /// Sources with no matching file (or no .git for gitLog) are added but `enabled: false`.
    static func materialize() -> [Source] {
        var sources: [Source] = []
        let fm = FileManager.default
        for project in list {
            let dir = URL(fileURLWithPath: project.path)
            for (filename, kind) in [("CLAUDE.md", SourceKind.claudeMd),
                                       ("AGENTS.md", SourceKind.agentsMd),
                                       ("GEMINI.md", SourceKind.geminiMd),
                                       ("pulse.md", SourceKind.claudeMd)] {
                let filePath = dir.appendingPathComponent(filename)
                let exists = fm.fileExists(atPath: filePath.path)
                sources.append(Source(kind: kind, path: filePath, label: project.label, enabled: exists))
            }
            let gitDir = dir.appendingPathComponent(".git")
            let isGit = fm.fileExists(atPath: gitDir.path)
            sources.append(Source(kind: .gitLog, path: dir, label: project.label, enabled: isGit))
        }
        return sources
    }
}
