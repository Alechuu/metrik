import SwiftUI
import WidgetKit

struct MediumWidgetView: View {
    var entry: MetrikEntry

    private let barColors: [Color] = [.blue, .green, .orange]

    var body: some View {
        HStack(spacing: 16) {
            // Left side: summary
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

                VStack(alignment: .leading, spacing: 2) {
                    Text("+\(entry.additionsToday.formatted())")
                        .font(.title2.bold())
                        .foregroundStyle(.green)

                    Text("lines today")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(String(format: "%.1f/hr", entry.linesPerHour))
                            .font(.caption.bold().monospacedDigit())

                        Text("rate")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(entry.commitCountToday) commits")
                            .font(.caption.bold().monospacedDigit())

                        Text("merged")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Divider()

            // Right side: mini bar chart
            VStack(alignment: .leading, spacing: 6) {
                Text("Top Repos")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)

                if entry.topRepos.isEmpty {
                    Spacer()
                    Text("No data")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                    Spacer()
                } else {
                    let maxRate = entry.topRepos.map(\.linesPerHour).max() ?? 1

                    ForEach(Array(entry.topRepos.enumerated()), id: \.offset) { index, repo in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(repo.name)
                                    .font(.caption2)
                                    .lineLimit(1)
                                Spacer()
                                Text(String(format: "%.1f/hr", repo.linesPerHour))
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }

                            GeometryReader { geo in
                                let width = maxRate > 0
                                    ? CGFloat(repo.linesPerHour / maxRate) * geo.size.width
                                    : 0

                                RoundedRectangle(cornerRadius: 2)
                                    .fill(barColors[index % barColors.count].gradient)
                                    .frame(width: max(width, 2), height: geo.size.height)
                            }
                            .frame(height: 8)
                        }
                    }

                    Spacer()
                }
            }
        }
    }
}
