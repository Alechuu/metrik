import SwiftUI

struct TimeRangePickerView: View {
    @Binding var selection: TimeRange

    var body: some View {
        Picker("Time Range", selection: $selection) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Text(range.rawValue).tag(range)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }
}
