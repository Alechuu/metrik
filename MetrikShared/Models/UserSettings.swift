import Foundation
import SwiftData

@Model
public final class UserSettings {
    public var hoursPerDay: Double
    public var hoursPerWeek: Double
    public var syncIntervalMinutes: Int
    public var launchAtLogin: Bool

    public init(
        hoursPerDay: Double = 8.0,
        hoursPerWeek: Double = 40.0,
        syncIntervalMinutes: Int = 15,
        launchAtLogin: Bool = false
    ) {
        self.hoursPerDay = hoursPerDay
        self.hoursPerWeek = hoursPerWeek
        self.syncIntervalMinutes = syncIntervalMinutes
        self.launchAtLogin = launchAtLogin
    }
}
