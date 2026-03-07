import Foundation
import SwiftUI

struct GoalProgressMetric: Identifiable {
    let title: String
    let subtitle: String
    let progress: Double
    let color: Color
    let currentLines: Int
    let expectedLines: Int

    var id: String { title }
    var clampedProgress: Double { min(max(progress, 0), 1) }
    var percentageLabel: String { "\(Int(progress * 100))%" }
    var linesLabel: String {
        let current = NumberFormatter.localizedString(from: NSNumber(value: currentLines), number: .decimal)
        let expected = NumberFormatter.localizedString(from: NSNumber(value: expectedLines), number: .decimal)
        return "\(current) / \(expected) lines"
    }
}

struct MetricsSummaryView: View {
    let metrics: MetricsSummary
    let goalMetric: GoalProgressMetric?

    var body: some View {
        VStack(spacing: 10) {
            if let goalMetric {
                goalCard(goalMetric)
            }
            statsGrid
        }
    }

    // MARK: - Goal card

    private func goalCard(_ metric: GoalProgressMetric) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text(metric.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                Text(metric.percentageLabel)
                    .font(.subheadline.bold())
                    .foregroundStyle(metric.color)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.quaternary)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(metric.color.gradient)
                        .frame(width: geo.size.width * metric.clampedProgress)

                    Text(metric.linesLabel)
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.7), radius: 1, x: 0, y: 0.5)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 20)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(metric.color.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(metric.color.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - Stats grid

    private var statsGrid: some View {
        Grid(horizontalSpacing: 10, verticalSpacing: 10) {
            GridRow {
                metricCard(
                    icon: "plus.circle.fill",
                    value: { AnimatedCounter(metrics.additions, prefix: "+") },
                    label: "lines added",
                    color: .green
                )
                metricCard(
                    icon: "gauge.with.dots.needle.33percent",
                    value: { AnimatedDecimalCounter(value: metrics.linesPerHour) },
                    label: "lines/hour",
                    color: .blue
                )
            }
            GridRow {
                metricCard(
                    icon: "minus.circle.fill",
                    value: { AnimatedCounter(metrics.deletions, prefix: "-") },
                    label: "lines removed",
                    color: .red
                )
                metricCard(
                    icon: "arrow.triangle.branch",
                    value: { AnimatedCounter(metrics.commitCount) },
                    label: "commits merged",
                    color: .purple
                )
            }
        }
    }

    // MARK: - Metric card

    private func metricCard<V: View>(
        icon: String? = nil,
        @ViewBuilder value: () -> V,
        label: String,
        color: Color
    ) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 3) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 13))
                        .foregroundStyle(color)
                }
                value()
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }

            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(color.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}
