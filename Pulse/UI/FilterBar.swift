import SwiftUI

struct FilterBar: View {
    @Binding var filter: CardFilter

    var body: some View {
        Picker("", selection: $filter) {
            ForEach(CardFilter.allCases) { f in
                Text(f.label).tag(f)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}
