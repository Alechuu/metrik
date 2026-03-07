import SwiftUI
import SwiftData
import ServiceManagement

struct GeneralSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsList: [UserSettings]

    private var settings: UserSettings {
        settingsList.first ?? UserSettings()
    }

    var body: some View {
        Form {
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
