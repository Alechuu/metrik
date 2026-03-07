import WidgetKit
import SwiftData

struct MetrikEntry: TimelineEntry {
    let date: Date
    let additionsToday: Int
    let deletionsToday: Int
    let linesPerHour: Double
    let commitCountToday: Int
    let topRepos: [(name: String, linesPerHour: Double)]

    static let placeholder = MetrikEntry(
        date: Date(),
        additionsToday: 0,
        deletionsToday: 0,
        linesPerHour: 0,
        commitCountToday: 0,
        topRepos: []
    )
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> MetrikEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (MetrikEntry) -> Void) {
        let entry = fetchCurrentEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MetrikEntry>) -> Void) {
        let entry = fetchCurrentEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func fetchCurrentEntry() -> MetrikEntry {
        do {
            let container = PersistenceController.sharedModelContainer
            let context = ModelContext(container)

            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: Date())

            let commitDescriptor = FetchDescriptor<MergedCommit>(
                predicate: #Predicate { $0.committedAt >= startOfDay }
            )
            let todayCommits = try context.fetch(commitDescriptor)

            let totalAdditions = todayCommits.reduce(0) { $0 + $1.additions }
            let totalDeletions = todayCommits.reduce(0) { $0 + $1.deletions }

            let settingsDescriptor = FetchDescriptor<UserSettings>()
            let settings = try context.fetch(settingsDescriptor).first ?? UserSettings()

            let now = Date()
            let elapsedHours = min(now.timeIntervalSince(startOfDay) / 3600, settings.hoursPerDay)
            let linesPerHour = elapsedHours > 0 ? Double(totalAdditions) / elapsedHours : 0

            let grouped = Dictionary(grouping: todayCommits) { $0.repoPath }
            let topRepos = grouped.map { (repoPath, commits) -> (String, Double) in
                let additions = commits.reduce(0) { $0 + $1.additions }
                let rate = elapsedHours > 0 ? Double(additions) / elapsedHours : 0
                let name = commits.first?.repoName ?? URL(fileURLWithPath: repoPath).lastPathComponent
                return (name, rate)
            }
            .sorted { $0.1 > $1.1 }
            .prefix(3)
            .map { ($0.0, $0.1) }

            return MetrikEntry(
                date: now,
                additionsToday: totalAdditions,
                deletionsToday: totalDeletions,
                linesPerHour: linesPerHour,
                commitCountToday: todayCommits.count,
                topRepos: topRepos
            )
        } catch {
            return .placeholder
        }
    }
}
