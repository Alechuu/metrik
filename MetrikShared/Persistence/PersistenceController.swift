import Foundation
import SwiftData

public enum PersistenceController {
    public static var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            MergedCommit.self,
            TrackedRepo.self,
            DailySummary.self,
            LocalGitConfig.self,
            UserSettings.self
        ])

        let config = ModelConfiguration(
            "Metrik-v3",
            schema: schema,
            allowsSave: true
        )

        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
}
