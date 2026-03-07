import Foundation
import SwiftData

@Observable
final class AppState {
    var isConfigured = false
    var selectedTimeRange: TimeRange = .today
    var metrics: MetricsSummary = .empty
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

            metrics = metricsCalculator.calculate(
                commits: allCommits,
                timeRange: selectedTimeRange,
                hoursPerDay: settings.hoursPerDay,
                hoursPerWeek: settings.hoursPerWeek
            )
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
