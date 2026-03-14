import Foundation

public struct MonthlyDataPoint: Identifiable, Sendable {
    public let id: String          // "2026-03" format
    public let month: Date         // First day of month
    public let additions: Int
    public let deletions: Int
    public let commitCount: Int
    public let workingHours: Double
    public let linesPerHour: Double
}

public struct MonthlyTrendData: Sendable {
    public let dataPoints: [MonthlyDataPoint]
    public let currentMonthLPH: Double
    public let previousMonthLPH: Double
    public let currentMonthAdditions: Int
    public let previousMonthAdditions: Int
    public let currentMonthDeletions: Int
    public let previousMonthDeletions: Int
    public let currentMonthCommits: Int
    public let previousMonthCommits: Int
    public let percentageChange: Double?

    public static let empty = MonthlyTrendData(
        dataPoints: [],
        currentMonthLPH: 0,
        previousMonthLPH: 0,
        currentMonthAdditions: 0,
        previousMonthAdditions: 0,
        currentMonthDeletions: 0,
        previousMonthDeletions: 0,
        currentMonthCommits: 0,
        previousMonthCommits: 0,
        percentageChange: nil
    )
}

public struct MonthlyTrendCalculator {
    private let calculator = MetricsCalculator()

    public init() {}

    public func calculateTrend(
        commits: [MergedCommit],
        repoFilter: String?,
        monthCount: Int,
        hoursPerDay: Double,
        workingDays: Set<Int>
    ) -> MonthlyTrendData {
        let calendar = Calendar.current
        let now = Date()

        let filtered: [MergedCommit] = repoFilter.map { name in
            commits.filter { $0.repoName == name }
        } ?? commits

        // Build monthly data points (full months for past, MTD for current)
        var dataPoints: [MonthlyDataPoint] = []

        for i in stride(from: monthCount - 1, through: 0, by: -1) {
            let anchor = calendar.date(byAdding: .month, value: -i, to: now)!
            let comps = calendar.dateComponents([.year, .month], from: anchor)
            let monthStart = calendar.date(from: comps)!
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart)!
            let monthEnd = i == 0 ? now : nextMonth

            let monthCommits = filtered.filter {
                $0.committedAt >= monthStart && $0.committedAt < monthEnd
            }

            let additions = monthCommits.reduce(0) { $0 + $1.additions }
            let deletions = monthCommits.reduce(0) { $0 + $1.deletions }
            let hours = calculator.calculateWorkingHours(
                start: monthStart,
                end: monthEnd,
                hoursPerDay: hoursPerDay,
                workingDays: workingDays
            )
            let lph = Double(additions) / hours

            let id = String(format: "%04d-%02d", comps.year ?? 0, comps.month ?? 0)
            dataPoints.append(MonthlyDataPoint(
                id: id,
                month: monthStart,
                additions: additions,
                deletions: deletions,
                commitCount: monthCommits.count,
                workingHours: hours,
                linesPerHour: lph
            ))
        }

        // MTD comparison: current month vs same day range in previous month
        let currentMonthStart = calendar.date(
            from: calendar.dateComponents([.year, .month], from: now)
        )!
        let dayOfMonth = calendar.component(.day, from: now)

        let prevAnchor = calendar.date(byAdding: .month, value: -1, to: now)!
        let prevMonthStart = calendar.date(
            from: calendar.dateComponents([.year, .month], from: prevAnchor)
        )!
        let prevMonthDays = calendar.range(of: .day, in: .month, for: prevAnchor)?.count ?? 28
        let equivDay = min(dayOfMonth, prevMonthDays)
        let prevEquivEnd = calendar.date(
            byAdding: .day, value: equivDay, to: prevMonthStart
        )!

        let currentMTDCommits = filtered.filter {
            $0.committedAt >= currentMonthStart && $0.committedAt <= now
        }
        let currentAdditions = currentMTDCommits.reduce(0) { $0 + $1.additions }
        let currentHours = calculator.calculateWorkingHours(
            start: currentMonthStart,
            end: now,
            hoursPerDay: hoursPerDay,
            workingDays: workingDays
        )
        let currentLPH = Double(currentAdditions) / currentHours

        let currentDeletions = currentMTDCommits.reduce(0) { $0 + $1.deletions }

        let prevMTDCommits = filtered.filter {
            $0.committedAt >= prevMonthStart && $0.committedAt < prevEquivEnd
        }
        let prevAdditions = prevMTDCommits.reduce(0) { $0 + $1.additions }
        let prevDeletions = prevMTDCommits.reduce(0) { $0 + $1.deletions }
        let prevHours = calculator.calculateWorkingHours(
            start: prevMonthStart,
            end: prevEquivEnd,
            hoursPerDay: hoursPerDay,
            workingDays: workingDays
        )
        let prevLPH = Double(prevAdditions) / prevHours

        let percentageChange: Double? = prevAdditions > 0
            ? ((currentLPH - prevLPH) / prevLPH) * 100
            : nil

        return MonthlyTrendData(
            dataPoints: dataPoints,
            currentMonthLPH: currentLPH,
            previousMonthLPH: prevLPH,
            currentMonthAdditions: currentAdditions,
            previousMonthAdditions: prevAdditions,
            currentMonthDeletions: currentDeletions,
            previousMonthDeletions: prevDeletions,
            currentMonthCommits: currentMTDCommits.count,
            previousMonthCommits: prevMTDCommits.count,
            percentageChange: percentageChange
        )
    }
}
