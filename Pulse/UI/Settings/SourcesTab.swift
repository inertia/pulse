import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct SourcesTab: View {
    @State private var sources: [Source] = []
    @State private var rescanController: RescanWindowController?
    private let sourceStore = SourceStore()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Sources").font(.headline)
                Spacer()
                Button(L.settingsRescanButton) { startRescan() }
                Button(L.settingsAddMarkdownSource) { addMarkdownSource() }
                Button(L.settingsAddGitSource) { addGitSource() }
            }
            .padding()

            if sources.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text(L.emptyNoSources)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(sources) { source in
                        sourceRow(source)
                    }
                    .onDelete(perform: deleteRows)
                }
            }
        }
        .onAppear { reload() }
    }

    @ViewBuilder
    private func sourceRow(_ source: Source) -> some View {
        HStack(spacing: 8) {
            Toggle("", isOn: Binding(
                get: { source.enabled },
                set: { newValue in setEnabled(source.id, newValue) }
            ))
            .labelsHidden()

            VStack(alignment: .leading, spacing: 2) {
                TextField("Label", text: Binding(
                    get: { source.label },
                    set: { newValue in setLabel(source.id, newValue) }
                ))
                .textFieldStyle(.roundedBorder)
                Text("\(kindLabel(source.kind))：\(source.path.path)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Button(action: { delete(source.id) }) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }

    private func kindLabel(_ kind: SourceKind) -> String {
        switch kind {
        case .claudeMd: return "CLAUDE.md"
        case .agentsMd: return "AGENTS.md"
        case .geminiMd: return "GEMINI.md"
        case .gitLog:   return "git log"
        }
    }

    private func reload() {
        sources = sourceStore.load()
    }

    private func setEnabled(_ id: UUID, _ enabled: Bool) {
        var all = sourceStore.load()
        if let idx = all.firstIndex(where: { $0.id == id }) {
            let s = all[idx]
            all[idx] = Source(id: s.id, kind: s.kind, path: s.path, label: s.label, enabled: enabled)
            try? sourceStore.save(all)
            reload()
        }
    }

    private func setLabel(_ id: UUID, _ label: String) {
        var all = sourceStore.load()
        if let idx = all.firstIndex(where: { $0.id == id }) {
            let s = all[idx]
            all[idx] = Source(id: s.id, kind: s.kind, path: s.path, label: label, enabled: s.enabled)
            try? sourceStore.save(all)
            reload()
        }
    }

    private func delete(_ id: UUID) {
        var all = sourceStore.load()
        all.removeAll { $0.id == id }
        try? sourceStore.save(all)
        reload()
    }

    private func deleteRows(at offsets: IndexSet) {
        var all = sourceStore.load()
        for offset in offsets.sorted(by: >) {
            if offset < sources.count {
                let id = sources[offset].id
                all.removeAll { $0.id == id }
            }
        }
        try? sourceStore.save(all)
        reload()
    }

    private func addMarkdownSource() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.text, .plainText]
        if panel.runModal() == .OK, let url = panel.url {
            let kind: SourceKind
            let filename = url.lastPathComponent
            switch filename {
            case "CLAUDE.md":  kind = .claudeMd
            case "AGENTS.md":  kind = .agentsMd
            case "GEMINI.md":  kind = .geminiMd
            default:           kind = .claudeMd
            }
            let label = url.deletingLastPathComponent().lastPathComponent
            let new = Source(kind: kind, path: url, label: label, enabled: true)
            var all = sourceStore.load()
            all.append(new)
            try? sourceStore.save(all)
            reload()
        }
    }

    private func addGitSource() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            let label = url.lastPathComponent
            let new = Source(kind: .gitLog, path: url, label: label, enabled: true)
            var all = sourceStore.load()
            all.append(new)
            try? sourceStore.save(all)
            reload()
        }
    }

    /// Open a modal window that re-runs `AutoSourceDetector` on the standard
    /// dev folders and lets the user pick newly-discovered projects to add.
    /// Already-tracked dirs are filtered out so the list shows only adds.
    /// Result merges with existing sources — never replaces.
    private func startRescan() {
        let existingDirs = Self.existingDirs(from: sourceStore.load())
        let controller = RescanWindowController(existingDirs: existingDirs) { projects, selectedDirs in
            let newSources = AppDelegate.sourcesFromOnboarding(
                projects: projects,
                selectedDirs: selectedDirs
            )
            var all = sourceStore.load()
            all.append(contentsOf: newSources)
            try? sourceStore.save(all)
            reload()
            rescanController?.close()
            rescanController = nil
        }
        rescanController = controller
        controller.show()
    }

    /// Canonical path strings for project dirs covered by `sources` (markdown
    /// sources resolve to their parent dir; gitLog sources are dirs already).
    /// Returns `Set<String>` rather than `Set<URL>` because `URL.deletingLastPathComponent`
    /// adds a trailing slash whereas `URL(fileURLWithPath:)` does not — the
    /// difference makes URL Set membership unreliable. Comparing canonical
    /// `.path` strings dodges that. Public so unit tests can exercise the
    /// merge-filter logic.
    static func existingDirs(from sources: [Source]) -> Set<String> {
        Set(sources.map { source -> String in
            switch source.kind {
            case .gitLog:
                return source.path.path
            case .claudeMd, .agentsMd, .geminiMd:
                return source.path.deletingLastPathComponent().path
            }
        })
    }
}
