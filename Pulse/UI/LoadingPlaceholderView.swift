import SwiftUI

struct LoadingPlaceholderView: View {
    let progress: (done: Int, total: Int)

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.regular)
            Text(L.loadingProgress(done: progress.done, total: progress.total))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
