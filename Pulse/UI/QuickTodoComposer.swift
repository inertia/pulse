import SwiftUI

/// Inline "+ 快速記" composer. Collapsed shows a single button; expanded shows
/// a TextField + add/cancel actions. Writes to QuickTodoStore.
struct QuickTodoComposer: View {
    @ObservedObject var store: QuickTodoStore
    @State private var expanded = false
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        if expanded {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(Color.accentColor)
                TextField("快速記一個 todo…", text: $draft)
                    .textFieldStyle(.plain)
                    .focused($focused)
                    .onSubmit { commit() }
                if !draft.isEmpty {
                    Button("加") { commit() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
                Button(action: cancel) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
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
                    Text("快速記")
                        .font(.system(.caption, weight: .medium))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule().fill(Color.primary.opacity(0.06))
                )
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.bottom, 6)
        }
    }

    private func commit() {
        let value = draft
        draft = ""
        store.add(title: value)
        // stay expanded for rapid multi-add; user closes via cancel button
        focused = true
    }

    private func cancel() {
        draft = ""
        expanded = false
    }
}
