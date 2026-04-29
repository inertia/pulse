import SwiftUI

struct OnboardingScanResultsView: View {
    let projects: [DetectedProject]
    let selectedDirs: Set<URL>
    let onToggle: (URL) -> Void
    let onComplete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(L.onboardingFoundCount(projects.count))
                    .font(.headline)
                Spacer()
            }
            .padding()

            if projects.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "questionmark.folder")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text(L.onboardingNoMatches)
                        .foregroundStyle(.secondary)
                    Text(L.onboardingNoMatchesHint)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(projects, id: \.dir) { project in
                        HStack {
                            Toggle(isOn: Binding(
                                get: { selectedDirs.contains(project.dir) },
                                set: { _ in onToggle(project.dir) }
                            )) { EmptyView() }
                            .labelsHidden()

                            VStack(alignment: .leading, spacing: 2) {
                                Text(project.dir.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                                    .font(.system(.body, design: .monospaced))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                HStack(spacing: 4) {
                                    ForEach(project.detectedFiles, id: \.self) { kind in
                                        Text(kindLabel(kind))
                                            .font(.caption2)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(Color.secondary.opacity(0.2))
                                            .cornerRadius(3)
                                    }
                                    if project.isGitRepo {
                                        Text("git")
                                            .font(.caption2)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(Color.secondary.opacity(0.2))
                                            .cornerRadius(3)
                                    }
                                    Text(relativeDateString(project.lastModified))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                        }
                    }
                }
                .listStyle(.inset)
            }

            Divider()
            HStack {
                Spacer()
                Button(L.onboardingFinishButton, action: onComplete)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(selectedDirs.isEmpty)
            }
            .padding()
        }
        .frame(width: 520, height: 520)
    }

    private func kindLabel(_ kind: SourceKind) -> String {
        switch kind {
        case .claudeMd: return "CLAUDE.md"
        case .agentsMd: return "AGENTS.md"
        case .geminiMd: return "GEMINI.md"
        case .gitLog:   return "git"
        }
    }

    private func relativeDateString(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.locale = Locale(identifier: "zh_TW")
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
