import Foundation
import SwiftData

@Model
public final class LocalGitConfig {
    public var rootDirectory: String
    public var gitUserName: String
    public var gitUserEmail: String
    public var isConfigured: Bool

    public init(
        rootDirectory: String,
        gitUserName: String,
        gitUserEmail: String,
        isConfigured: Bool = false
    ) {
        self.rootDirectory = rootDirectory
        self.gitUserName = gitUserName
        self.gitUserEmail = gitUserEmail
        self.isConfigured = isConfigured
    }
}
