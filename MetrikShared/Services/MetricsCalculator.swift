import Foundation
import SwiftData

public enum TimeRange: String, CaseIterable, Sendable {
    case today = "Today"
    case thisWeek = "This Week"
    case thisMonth = "This Month"
    case allTime = "All Time"

    public var dateRange: (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()

        switch self {
        case .today:
            return (calendar.startOfDay(for: now), now)
        case .thisWeek:
            let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
            return (weekStart, now)
        case .thisMonth:
            let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
            return (monthStart, now)
        case .allTime:
            let distantPast = calendar.date(byAdding: .year, value: -10, to: now)!
            return (distantPast, now)
        }
    }
}

public struct MetricsSummary: Sendable {
    public let additions: Int
    public let deletions: Int
    public let commitCount: Int
    public let linesPerHour: Double
    public let repoBreakdown: [RepoMetric]

    public init(additions: Int, deletions: Int, commitCount: Int, linesPerHour: Double, repoBreakdown: [RepoMetric]) {
        self.additions = additions
        self.deletions = deletions
        self.commitCount = commitCount
        self.linesPerHour = linesPerHour
        self.repoBreakdown = repoBreakdown
    }

    public static let empty = MetricsSummary(additions: 0, deletions: 0, commitCount: 0, linesPerHour: 0, repoBreakdown: [])
}

public struct RepoMetric: Identifiable, Sendable {
    public let id: String
    public let repoName: String
    public let additions: Int
    public let deletions: Int
    public let commitCount: Int
    public let linesPerHour: Double

    public init(id: String = UUID().uuidString, repoName: String, additions: Int, deletions: Int, commitCount: Int, linesPerHour: Double) {
        self.id = id
        self.repoName = repoName
        self.additions = additions
        self.deletions = deletions
        self.commitCount = commitCount
        self.linesPerHour = linesPerHour
    }
}

public struct MetricsCalculator {
    public init() {}

    public func calculate(
        commits: [MergedCommit],
        timeRange: TimeRange,
        hoursPerDay: Double,
        hoursPerWeek: Double
    ) -> MetricsSummary {
        let range = timeRange.dateRange
        let filtered = commits.filter { $0.committedAt >= range.start && $0.committedAt <= range.end }

        let totalAdditions = filtered.reduce(0) { $0 + $1.additions }
        let totalDeletions = filtered.reduce(0) { $0 + $1.deletions }

        let workingHours = calculateWorkingHours(
            timeRange: timeRange,
            hoursPerDay: hoursPerDay,
            hoursPerWeek: hoursPerWeek
        )

        let linesPerHour = workingHours > 0 ? Double(totalAdditions) / workingHours : 0

        let grouped = Dictionary(grouping: filtered) { $0.repoPath }
        let breakdown = grouped.map { (repoPath, repoCommits) -> RepoMetric in
            let repoAdditions = repoCommits.reduce(0) { $0 + $1.additions }
            let repoDeletions = repoCommits.reduce(0) { $0 + $1.deletions }
            let repoLPH = workingHours > 0 ? Double(repoAdditions) / workingHours : 0
            let repoName = repoCommits.first?.repoName ?? URL(fileURLWithPath: repoPath).lastPathComponent

            return RepoMetric(
                repoName: repoName,
                additions: repoAdditions,
                deletions: repoDeletions,
                commitCount: repoCommits.count,
                linesPerHour: repoLPH
            )
        }
        .sorted { $0.linesPerHour > $1.linesPerHour }

        return MetricsSummary(
            additions: totalAdditions,
            deletions: totalDeletions,
            commitCount: filtered.count,
            linesPerHour: linesPerHour,
            repoBreakdown: breakdown
        )
    }

    private func calculateWorkingHours(
        timeRange: TimeRange,
        hoursPerDay: Double,
        hoursPerWeek: Double
    ) -> Double {
        let calendar = Calendar.current

        switch timeRange {
        case .today:
            let now = Date()
            let startOfDay = calendar.startOfDay(for: now)
            let elapsed = now.timeIntervalSince(startOfDay) / 3600
            return min(elapsed, hoursPerDay)

        case .thisWeek:
            let weekday = calendar.component(.weekday, from: Date())
            let workingDaysSoFar = max(1, weekday - 1)
            return min(Double(workingDaysSoFar) * hoursPerDay, hoursPerWeek)

        case .thisMonth:
            let day = calendar.component(.day, from: Date())
            let weekCount = Double(day) / 7.0
            return weekCount * hoursPerWeek

        case .allTime:
            let range = timeRange.dateRange
            let days = calendar.dateComponents([.day], from: range.start, to: range.end).day ?? 1
            let weeks = Double(max(days, 1)) / 7.0
            return weeks * hoursPerWeek
        }
    }
}
