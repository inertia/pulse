import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct SourcesTab: View {
    @State private var sources: [Source] = []
    private let sourceStore = SourceStore()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Sources").font(.headline)
                Spacer()
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
}
