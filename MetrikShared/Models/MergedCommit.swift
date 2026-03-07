import Foundation
import SwiftData

@Model
public final class MergedCommit {
    @Attribute(.unique) public var sha: String
    public var title: String
    public var additions: Int
    public var deletions: Int
    public var committedAt: Date
    public var repoPath: String
    public var repoName: String
    public var authorEmail: String

    public init(
        sha: String,
        title: String,
        additions: Int,
        deletions: Int,
        committedAt: Date,
        repoPath: String,
        repoName: String,
        authorEmail: String
    ) {
        self.sha = sha
        self.title = title
        self.additions = additions
        self.deletions = deletions
        self.committedAt = committedAt
        self.repoPath = repoPath
        self.repoName = repoName
        self.authorEmail = authorEmail
    }
}
