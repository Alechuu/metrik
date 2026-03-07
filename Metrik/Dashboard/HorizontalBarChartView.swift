import SwiftUI

struct HorizontalBarChartView: View {
    let repos: [RepoMetric]

    private let barColors: [Color] = [.blue, .green, .orange, .purple, .pink, .cyan]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Lines/Hour by Repository")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            if repos.isEmpty {
                Text("No data yet")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                let maxRate = repos.map(\.linesPerHour).max() ?? 1

                ForEach(Array(repos.prefix(5).enumerated()), id: \.element.id) { index, repo in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(repo.repoName)
                                .font(.caption)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Text(String(format: "%.1f/hr", repo.linesPerHour))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }

                        GeometryReader { geo in
                            let barWidth = maxRate > 0
                                ? CGFloat(repo.linesPerHour / maxRate) * geo.size.width
                                : 0

                            RoundedRectangle(cornerRadius: 3)
                                .fill(barColors[index % barColors.count].gradient)
                                .frame(width: max(barWidth, 2), height: geo.size.height)
                                .animation(.spring(duration: 0.6, bounce: 0.15), value: repo.linesPerHour)
                        }
                        .frame(height: 8)
                    }
                }
            }
        }
    }
}
