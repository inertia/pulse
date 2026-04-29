import SwiftUI

/// Reusable section container inside `OverviewView`.
/// Use `collapsible: true` + an `isExpanded` binding to make the header a toggle
/// (e.g., for "完成 last 7d" which defaults to folded). Non-collapsible sections
/// always render their content and the chevron is omitted.
struct OverviewSection<Content: View>: View {
    let title: String
    let accent: Color
    let count: Int
    let collapsible: Bool
    @Binding var isExpanded: Bool
    let content: () -> Content

    init(
        title: String,
        accent: Color,
        count: Int,
        collapsible: Bool = false,
        isExpanded: Binding<Bool> = .constant(true),
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.accent = accent
        self.count = count
        self.collapsible = collapsible
        self._isExpanded = isExpanded
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            if isExpanded || !collapsible {
                VStack(spacing: 4) {
                    content()
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var header: some View {
        Button(action: {
            guard collapsible else { return }
            withAnimation(.easeInOut(duration: 0.18)) { isExpanded.toggle() }
        }) {
            HStack(spacing: 6) {
                if collapsible {
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                Text(title)
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(accent)
                Text("\(count)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
                Spacer(minLength: 0)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!collapsible)
    }
}
