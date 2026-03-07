import Foundation
import SwiftData

public enum PersistenceController {
    public static let appGroupID = "group.com.metrik"

    public static var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            MergedCommit.self,
            TrackedRepo.self,
            DailySummary.self,
            LocalGitConfig.self,
            UserSettings.self
        ])

        let config: ModelConfiguration
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            config = ModelConfiguration(
                "Metrik-v2",
                schema: schema,
                url: containerURL.appendingPathComponent("Metrik-v2.store"),
                allowsSave: true
            )
        } else {
            config = ModelConfiguration(
                "Metrik-v2",
                schema: schema,
                allowsSave: true
            )
        }

        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
}
