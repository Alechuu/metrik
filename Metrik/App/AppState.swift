import Foundation
import SwiftData

@Observable
final class AppState {
    var isConfigured = false
    var selectedTimeRange: TimeRange = .today
    var metrics: MetricsSummary = .empty
    var metricsToday: MetricsSummary = .empty
    var metricsWeek: MetricsSummary = .empty
    var metricsMonth: MetricsSummary = .empty
    var dayProgress: Double = 0
    var weekProgress: Double = 0
    var monthProgress: Double = 0
    var expectedDayLines: Int = 0
    var expectedWeekLines: Int = 0
    var expectedMonthLines: Int = 0
    var hasCodingGoal: Bool = false
    var workingDays: Set<Int> = [2, 3, 4, 5, 6]
    var isOffline = false

    let syncService = SyncService()
    let metricsCalculator = MetricsCalculator()

    init() {}

    @MainActor
    func checkConfiguration(modelContext: ModelContext) {
        do {
            let descriptor = FetchDescriptor<LocalGitConfig>()
            let config = try modelContext.fetch(descriptor).first
            isConfigured = config?.isConfigured ?? false
        } catch {
            isConfigured = false
        }
    }

    @MainActor
    func refreshMetrics(modelContext: ModelContext) {
        do {
            let settingsDescriptor = FetchDescriptor<UserSettings>()
            let settings = try modelContext.fetch(settingsDescriptor).first ?? UserSettings()

            let commitDescriptor = FetchDescriptor<MergedCommit>()
            let allCommits = try modelContext.fetch(commitDescriptor)

            metricsToday = metricsCalculator.calculate(
                commits: allCommits,
                timeRange: .today,
                hoursPerDay: settings.hoursPerDay,
                hoursPerWeek: settings.hoursPerWeek
            )
            metricsWeek = metricsCalculator.calculate(
                commits: allCommits,
                timeRange: .thisWeek,
                hoursPerDay: settings.hoursPerDay,
                hoursPerWeek: settings.hoursPerWeek
            )
            metricsMonth = metricsCalculator.calculate(
                commits: allCommits,
                timeRange: .thisMonth,
                hoursPerDay: settings.hoursPerDay,
                hoursPerWeek: settings.hoursPerWeek
            )
            metrics = metricsCalculator.calculate(
                commits: allCommits,
                timeRange: selectedTimeRange,
                hoursPerDay: settings.hoursPerDay,
                hoursPerWeek: settings.hoursPerWeek
            )

            let expectedDay: Double
            let expectedWeek: Double
            let expectedMonth: Double
            switch GoalUnit(rawValue: settings.goalUnitRawValue) ?? .perWeek {
            case .perWeek:
                expectedDay = settings.goalValue > 0 ? settings.goalValue / 5 : 0
                expectedWeek = settings.goalValue
                expectedMonth = settings.goalValue * 4
            case .perHour:
                expectedDay = settings.goalValue * settings.hoursPerDay
                expectedWeek = settings.goalValue * settings.hoursPerWeek
                expectedMonth = settings.goalValue * settings.hoursPerWeek * 4
            }

            dayProgress = expectedDay > 0 ? Double(metricsToday.additions) / expectedDay : 0
            weekProgress = expectedWeek > 0 ? Double(metricsWeek.additions) / expectedWeek : 0
            monthProgress = expectedMonth > 0 ? Double(metricsMonth.additions) / expectedMonth : 0
            expectedDayLines = Int(expectedDay)
            expectedWeekLines = Int(expectedWeek)
            expectedMonthLines = Int(expectedMonth)
            hasCodingGoal = settings.goalValue > 0
            workingDays = settings.workingDays

            NotificationCenter.default.post(name: .metricsDidUpdate, object: nil)
        } catch {
            print("Error refreshing metrics: \(error)")
        }
    }

    func resetConfiguration(modelContext: ModelContext) {
        isConfigured = false
        metrics = .empty

        do {
            try modelContext.delete(model: LocalGitConfig.self)
            try modelContext.delete(model: MergedCommit.self)
            try modelContext.delete(model: TrackedRepo.self)
            try modelContext.delete(model: DailySummary.self)
            try modelContext.save()
        } catch {
            print("Error clearing data on reset: \(error)")
        }
    }
}
