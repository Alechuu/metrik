import Foundation
import SwiftData

@Model
public final class TrackedRepo {
    @Attribute(.unique) public var localPath: String
    public var name: String
    public var defaultBranch: String
    public var isTracked: Bool
    public var lastSyncDate: Date?
    public var lastSyncedSHA: String?

    public init(
        localPath: String,
        name: String,
        defaultBranch: String = "main",
        isTracked: Bool = false,
        lastSyncDate: Date? = nil,
        lastSyncedSHA: String? = nil
    ) {
        self.localPath = localPath
        self.name = name
        self.defaultBranch = defaultBranch
        self.isTracked = isTracked
        self.lastSyncDate = lastSyncDate
        self.lastSyncedSHA = lastSyncedSHA
    }
}
