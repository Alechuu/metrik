import SwiftUI
import WidgetKit

struct SmallWidgetView: View {
    var entry: MetrikEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.caption)
                    .foregroundStyle(.blue)
                Text("Metrik")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .leading, spacing: 4) {
                Text("+\(entry.additionsToday.formatted())")
                    .font(.title.bold())
                    .foregroundStyle(.green)

                Text("lines today")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(format: "%.1f", entry.linesPerHour))
                        .font(.headline.monospacedDigit())

                    Text("lines/hr")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(entry.commitCountToday)")
                        .font(.headline.monospacedDigit())

                    Text("commits")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
