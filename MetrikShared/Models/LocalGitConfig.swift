import Foundation
import SwiftData

@Model
public final class LocalGitConfig {
    public var rootDirectory: String
    public var gitUserName: String
    public var gitUserEmail: String
    public var isConfigured: Bool
    public var customAvatarData: Data?

    public init(
        rootDirectory: String,
        gitUserName: String,
        gitUserEmail: String,
        isConfigured: Bool = false,
        customAvatarData: Data? = nil
    ) {
        self.rootDirectory = rootDirectory
        self.gitUserName = gitUserName
        self.gitUserEmail = gitUserEmail
        self.isConfigured = isConfigured
        self.customAvatarData = customAvatarData
    }
}
