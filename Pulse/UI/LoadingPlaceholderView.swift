import SwiftUI

struct LoadingPlaceholderView: View {
    let progress: (done: Int, total: Int)

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.regular)
            Text("掃描中 \(progress.done) / \(progress.total) 專案")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
