import SwiftUI

/// Inline 快速記 composer for the popover. User can:
/// - Add to Pulse-internal store (default; shows under 📝 快速記 tab)
/// - OR pick a project: writes to `<project>/PULSE_QUICK.md` so Claude Code
///   reading that project sees the todo too.
struct QuickTodoComposer: View {
    @ObservedObject var store: QuickTodoStore
    /// Available project labels + their project directory (for PULSE_QUICK.md path).
    /// Empty list = picker hidden, only Pulse-internal mode available.
    let projects: [ProjectTarget]
    /// Called after a project-targeted write succeeds — caller can refresh.
    let onProjectWrite: (URL) -> Void

    struct ProjectTarget: Identifiable, Equatable {
        var id: String { label }
        let label: String
        let projectDir: URL
    }

    @State private var expanded = false
    @State private var draft = ""
    @State private var targetLabel: String = ""  // empty = Pulse-only
    @FocusState private var focused: Bool

    var body: some View {
        if expanded {
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Color.accentColor)
                    TextField(L.quickFieldPlaceholder, text: $draft)
                        .textFieldStyle(.plain)
                        .focused($focused)
                        .onSubmit { commit() }
                    Button(action: cancel) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
                HStack(spacing: 6) {
                    Picker("", selection: $targetLabel) {
                        Text(L.quickPulseOnly).tag("")
                        ForEach(projects) { p in
                            Text("→ \(p.label) (PULSE_QUICK.md)").tag(p.label)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .controlSize(.small)
                    Spacer()
                    Button(action: commit) {
                        Text(targetLabel.isEmpty ? L.quickAddButton : L.quickWriteToProject)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 6)
        } else {
            Button(action: { expanded = true; focused = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                    Text(L.quickHeader)
                        .font(.system(.caption, weight: .medium))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.primary.opacity(0.06)))
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.bottom, 6)
        }
    }

    private func commit() {
        let value = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }

        if targetLabel.isEmpty {
            // Pulse-only
            store.add(title: value)
        } else if let target = projects.first(where: { $0.label == targetLabel }) {
            // Write to project's PULSE_QUICK.md
            do {
                let url = try PulseQuickWriter.append(title: value, to: target.projectDir)
                onProjectWrite(url)
            } catch {
                // Fallback: store in Pulse-only on failure so user doesn't lose the todo.
                store.add(title: L.quickWriteFailed(value))
            }
        }

        draft = ""
        focused = true   // stay open for rapid multi-add
    }

    private func cancel() {
        draft = ""
        expanded = false
    }
}
