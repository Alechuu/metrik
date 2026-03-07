import Foundation
import SwiftData

public enum GoalUnit: Int, CaseIterable, Sendable {
    case perWeek = 0
    case perHour = 1

    public var label: String {
        switch self {
        case .perWeek: return "Per week"
        case .perHour: return "Per hour"
        }
    }
}

@Model
public final class UserSettings {
    public var hoursPerDay: Double
    public var hoursPerWeek: Double
    public var syncIntervalMinutes: Int
    public var launchAtLogin: Bool
    public var goalValue: Double = 500.0
    public var goalUnitRawValue: Int = 0
    public var workingDaysRaw: String = "2,3,4,5,6"

    public init(
        hoursPerDay: Double = 8.0,
        hoursPerWeek: Double = 40.0,
        syncIntervalMinutes: Int = 15,
        launchAtLogin: Bool = false,
        goalValue: Double = 500.0,
        goalUnitRawValue: Int = 0,
        workingDaysRaw: String = "2,3,4,5,6"
    ) {
        self.hoursPerDay = hoursPerDay
        self.hoursPerWeek = hoursPerWeek
        self.syncIntervalMinutes = syncIntervalMinutes
        self.launchAtLogin = launchAtLogin
        self.goalValue = goalValue
        self.goalUnitRawValue = goalUnitRawValue
        self.workingDaysRaw = workingDaysRaw
    }

    /// Weekday numbers matching Calendar: 1=Sun, 2=Mon, 3=Tue, 4=Wed, 5=Thu, 6=Fri, 7=Sat
    @Transient
    public var workingDays: Set<Int> {
        get {
            Set(workingDaysRaw.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) })
        }
        set {
            workingDaysRaw = newValue.sorted().map(String.init).joined(separator: ",")
        }
    }

    public func isWorkingDay(_ weekday: Int) -> Bool {
        workingDays.contains(weekday)
    }
}
