import SwiftUI

struct MetricsSummaryView: View {
    let metrics: MetricsSummary
    @State private var pulseTrigger = false

    var body: some View {
        Grid(horizontalSpacing: 16, verticalSpacing: 12) {
            GridRow {
                metricCell(
                    value: { AnimatedCounter(metrics.additions, prefix: "+") },
                    label: "lines added",
                    color: .green
                )

                metricCell(
                    value: { AnimatedDecimalCounter(value: metrics.linesPerHour) },
                    label: "lines/hour",
                    color: .blue
                )
            }

            GridRow {
                metricCell(
                    value: { AnimatedCounter(metrics.deletions, prefix: "-") },
                    label: "lines removed",
                    color: .red
                )

                metricCell(
                    value: {
                        HStack(spacing: 4) {
                            AnimatedCounter(metrics.commitCount)
                            Text("commits")
                                .font(.title2.bold())
                        }
                    },
                    label: "merged",
                    color: .purple
                )
            }
        }
        .pulseOnChange(pulseTrigger)
        .onChange(of: metrics.additions) { _, _ in
            pulseTrigger.toggle()
        }
    }

    private func metricCell<V: View>(
        @ViewBuilder value: () -> V,
        label: String,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            value()
                .font(.title2.bold())
                .foregroundStyle(color)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
