import SwiftUI
import SwiftData
import ServiceManagement

struct GeneralSettingsView: View {
    var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsList: [UserSettings]

    private var settings: UserSettings {
        settingsList.first ?? UserSettings()
    }

    var body: some View {
        Form {
            Section("Coding Goal") {
                HStack {
                    Text("Expected lines")
                    Spacer()
                    TextField("", value: Binding(
                        get: { settings.goalValue },
                        set: { newValue in
                            settings.goalValue = newValue
                            try? modelContext.save()
                            appState.refreshMetrics(modelContext: modelContext)
                        }
                    ), format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .multilineTextAlignment(.trailing)
                }

                Picker("Per", selection: Binding(
                    get: { GoalUnit(rawValue: settings.goalUnitRawValue) ?? .perWeek },
                    set: { newValue in
                        settings.goalUnitRawValue = newValue.rawValue
                        try? modelContext.save()
                        appState.refreshMetrics(modelContext: modelContext)
                    }
                )) {
                    Text("Per week").tag(GoalUnit.perWeek)
                    Text("Per hour").tag(GoalUnit.perHour)
                }
            }

            Section("Working Days") {
                workingDaysPicker
            }

            Section("Working Hours") {
                HStack {
                    Text("Hours per day")
                    Spacer()
                    TextField("", value: Binding(
                        get: { settings.hoursPerDay },
                        set: { newValue in
                            settings.hoursPerDay = newValue
                            try? modelContext.save()
                        }
                    ), format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .multilineTextAlignment(.trailing)
                }

                HStack {
                    Text("Hours per week")
                    Spacer()
                    TextField("", value: Binding(
                        get: { settings.hoursPerWeek },
                        set: { newValue in
                            settings.hoursPerWeek = newValue
                            try? modelContext.save()
                        }
                    ), format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .multilineTextAlignment(.trailing)
                }
            }

            Section("Sync") {
                Picker("Sync interval", selection: Binding(
                    get: { settings.syncIntervalMinutes },
                    set: { newValue in
                        settings.syncIntervalMinutes = newValue
                        try? modelContext.save()
                    }
                )) {
                    Text("5 minutes").tag(5)
                    Text("15 minutes").tag(15)
                    Text("30 minutes").tag(30)
                    Text("1 hour").tag(60)
                }
            }

            Section("System") {
                Toggle("Launch at login", isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { newValue in
                        settings.launchAtLogin = newValue
                        try? modelContext.save()
                        updateLaunchAtLogin(newValue)
                    }
                ))
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            ensureSettings()
        }
    }

    private static let weekdaySymbols: [(id: Int, short: String)] = {
        let cal = Calendar.current
        return (1...7).map { ($0, cal.shortWeekdaySymbols[$0 - 1]) }
    }()

    private var workingDaysPicker: some View {
        HStack(spacing: 6) {
            ForEach(Self.weekdaySymbols, id: \.id) { day in
                let isOn = settings.workingDays.contains(day.id)
                Button {
                    var days = settings.workingDays
                    if isOn { days.remove(day.id) } else { days.insert(day.id) }
                    settings.workingDays = days
                    try? modelContext.save()
                } label: {
                    Text(day.short)
                        .font(.caption.bold())
                        .frame(width: 36, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(isOn ? Color.accentColor : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(isOn ? Color.clear : Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                        .foregroundStyle(isOn ? .white : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func ensureSettings() {
        if settingsList.isEmpty {
            modelContext.insert(UserSettings())
            try? modelContext.save()
        }
    }

    private func updateLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to update launch at login: \(error)")
        }
    }
}
