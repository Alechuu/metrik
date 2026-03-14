import SwiftUI

struct MonthlyTrendChartView: View {
    let trendData: MonthlyTrendData
    @Binding var monthCount: Int
    @Binding var selectedRepoName: String?
    let availableRepos: [String]
    let gitUserName: String
    let gitUserEmail: String
    @State private var hoveredBarId: String?

    // Round max up to a clean axis ceiling
    private var yMax: Double {
        let m = trendData.dataPoints.map(\.linesPerHour).max() ?? 0
        guard m > 0 else { return 150 }
        let steps: [Double] = [30, 50, 60, 90, 100, 120, 150, 200, 300, 500, 1000]
        return steps.first { $0 >= m * 1.15 } ?? (ceil(m * 1.15 / 50) * 50)
    }

    // Six evenly-spaced labels from top (yMax) to bottom (0)
    private var yLabels: [Double] {
        let step = yMax / 5
        return (0...5).map { Double(5 - $0) * step }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            headerRow
            chartArea
            metricsRow
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .padding(.top, 12)
        .background(Color.black.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.15), lineWidth: 0.5))
    }

    // MARK: – Header

    private var headerRow: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                ProfileAvatarView(userName: gitUserName, userEmail: gitUserEmail, size: 30)
                Text(gitUserName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.mkTextPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
            HStack {
                Text("Lines / Hour")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.mkTextSecondary)
                Spacer()
                HStack(spacing: 8) {
                    mkMenu(icon: "arrow.triangle.branch", label: selectedRepoName ?? "All Repos") {
                        Button("All Repos") { selectedRepoName = nil }
                        if !availableRepos.isEmpty {
                            Divider()
                            ForEach(availableRepos, id: \.self) { repo in
                                Button(repo) { selectedRepoName = repo }
                            }
                        }
                    }
                    mkMenu(icon: "calendar", label: monthCount == 6 ? "Last 6 months" : "Last 12 months", fontSize: 12) {
                        Button("Last 6 months") { monthCount = 6 }
                        Button("Last 12 months") { monthCount = 12 }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func mkMenu<Content: View>(
        icon: String, label: String, fontSize: CGFloat = 13,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Menu { content() } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: fontSize - 1))
                    .foregroundStyle(Color.mkTextSecondary)
                Text(label)
                    .font(.system(size: fontSize, weight: .medium))
                    .foregroundStyle(Color.mkTextPrimary)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.mkTextTertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.mkBgInset)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.mkBorderLight, lineWidth: 0.5))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    // MARK: – Chart Area

    private var chartArea: some View {
        HStack(alignment: .bottom, spacing: 0) {
            yAxisColumn
            barsColumn
        }
        .frame(height: 260)
        .animation(.easeInOut(duration: 0.3), value: monthCount)
        .animation(.easeInOut(duration: 0.3), value: selectedRepoName)
    }

    private var yAxisColumn: some View {
        VStack(alignment: .trailing, spacing: 0) {
            ForEach(yLabels, id: \.self) { v in
                Text(v == 0 ? "0" : String(Int(v)))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.mkTextMuted)
                    .frame(maxHeight: .infinity, alignment: .top)
            }
            Color.clear.frame(height: 20) // x-label row padding
        }
        .frame(width: 40)
        .padding(.trailing, 8)
    }

    private var barsColumn: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if trendData.dataPoints.isEmpty {
                Text("No data")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.mkTextTertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                ForEach(Array(trendData.dataPoints.enumerated()), id: \.1.id) { i, point in
                    let isCurrent = i == trendData.dataPoints.count - 1
                    barColumn(point: point, isCurrent: isCurrent)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                }
            }
        }
    }

    @ViewBuilder
    private func barColumn(point: MonthlyDataPoint, isCurrent: Bool) -> some View {
        // 220pt for bars, leaving ~40pt headroom for value labels + x-labels
        let barH: CGFloat = yMax > 0 && point.linesPerHour > 0
            ? max(CGFloat(point.linesPerHour / yMax) * 220, 6)
            : 0

        VStack(spacing: 4) {
            Spacer(minLength: 0)
            if point.linesPerHour > 0 {
                Text(String(format: "%.1f", point.linesPerHour))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(isCurrent ? Color.mkAccent : Color.mkTextSecondary)
                    .opacity(hoveredBarId == point.id ? 1 : 0)
                    .offset(y: hoveredBarId == point.id ? 0 : 4)
                    .animation(.easeOut(duration: 0.2), value: hoveredBarId)
            }
            if barH > 0 {
                RoundedRectangle(cornerRadius: 6)
                    .fill(LinearGradient(
                        colors: isCurrent
                            ? [Color.mkAccent.opacity(0.33), Color.mkAccent]
                            : [Color.mkAccent.opacity(0.2), Color.mkAccent],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .frame(width: 40, height: barH)
            } else {
                Color.clear.frame(width: 40, height: 2)
            }
            Text(monthAbbrev(point.month))
                .font(.system(size: 10, weight: isCurrent ? .semibold : .medium))
                .foregroundStyle(isCurrent ? Color.mkAccent : Color.mkTextTertiary)
                .frame(height: 14)
        }
        .onHover { hovering in
            hoveredBarId = hovering ? point.id : nil
        }
    }

    // MARK: – Metrics Footer

    private var metricsRow: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("THIS MONTH (MTD)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.mkTextTertiary)
                    .tracking(1)
                Text(String(format: "%.1f/hr", trendData.currentMonthLPH))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.mkTextPrimary)
            }
            Spacer()
            if let pct = trendData.percentageChange {
                let positive = pct >= 0
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Text(positive ? "↗" : "↙")
                            .font(.system(size: 12, weight: .bold))
                        Text(String(format: "%+.0f%%", pct))
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(positive ? Color.mkPositive : Color.mkNegative)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background((positive ? Color.mkPositive : Color.mkNegative).opacity(0.13))
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                    Text("vs last month")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.mkTextSecondary)
                }
            }
        }
    }

    private func monthAbbrev(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f.string(from: date)
    }
}
