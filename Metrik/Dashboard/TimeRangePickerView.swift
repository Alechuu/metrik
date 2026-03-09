import SwiftUI

struct TimeRangePickerView: View {
    @Binding var selection: TimeRange

    var body: some View {
        Group {
            if #available(macOS 26, *) {
                glassRangePicker
            } else {
                Picker("Time Range", selection: $selection) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
        }
    }

    @available(macOS 26, *)
    private var glassRangePicker: some View {
        HStack(spacing: 0) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                let isSelected = selection == range

                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        selection = range
                    }
                } label: {
                    Text(range.compactLabel)
                        .font(.system(size: 13, weight: .medium))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .foregroundStyle(isSelected ? .white : .primary)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.accentColor)
                            .glassEffectIfAvailable(cornerRadius: 10)
                            .padding(2)
                    }
                }
            }
        }
        .frame(height: 32)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.secondary.opacity(0.12))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        }
        .glassEffectIfAvailable(cornerRadius: 12)
    }
}

private extension TimeRange {
    var compactLabel: String {
        switch self {
        case .today: "Today"
        case .thisWeek: "Week"
        case .thisMonth: "Month"
        case .allTime: "All"
        }
    }
}
