import Foundation
import SwiftData

@Model
public final class DailySummary {
    public var date: Date
    public var repoPath: String
    public var additions: Int
    public var deletions: Int
    public var commitCount: Int

    public init(
        date: Date,
        repoPath: String,
        additions: Int,
        deletions: Int,
        commitCount: Int
    ) {
        self.date = date
        self.repoPath = repoPath
        self.additions = additions
        self.deletions = deletions
        self.commitCount = commitCount
    }
}
