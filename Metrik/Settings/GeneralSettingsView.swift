import AppKit
import ServiceManagement
import SwiftData
import SwiftUI

struct GeneralSettingsView: View {
    private enum RequiredField: Hashable {
        case goalValue
        case hoursPerDay
        case hoursPerWeek
    }

    var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsList: [UserSettings]
    @State private var goalValueText = ""
    @State private var hoursPerDayText = ""
    @State private var hoursPerWeekText = ""
    @State private var hasLoadedDraftValues = false
    @FocusState private var focusedField: RequiredField?

    private var settings: UserSettings {
        settingsList.first ?? UserSettings()
    }

    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = .autoupdatingCurrent
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    var body: some View {
        Form {
            Section("Coding Goal") {
                requiredNumberRow(title: "Expected lines", text: goalValueBinding, field: .goalValue)

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
                requiredNumberRow(title: "Hours per day", text: hoursPerDayBinding, field: .hoursPerDay)
                requiredNumberRow(title: "Hours per week", text: hoursPerWeekBinding, field: .hoursPerWeek)
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
            loadDraftValues()
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
                if #available(macOS 26, *) {
                    if isOn {
                        Button {
                            toggleWorkingDay(day.id)
                        } label: {
                            weekdayButtonLabel(day.short)
                        }
                        .buttonStyle(.glassProminent)
                        .glassEffectIfAvailable(cornerRadius: 8)
                    } else {
                        Button {
                            toggleWorkingDay(day.id)
                        } label: {
                            weekdayButtonLabel(day.short)
                        }
                        .buttonStyle(.glass)
                        .glassEffectIfAvailable(cornerRadius: 8)
                    }
                } else {
                    Button {
                        toggleWorkingDay(day.id)
                    } label: {
                        weekdayButtonLabel(day.short)
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
        }
        .frame(maxWidth: .infinity)
    }

    private func ensureSettings() {
        if settingsList.isEmpty {
            modelContext.insert(UserSettings())
            try? modelContext.save()
        }
    }

    private var goalValueBinding: Binding<String> {
        requiredNumberBinding(for: $goalValueText, keyPath: \.goalValue)
    }

    private var hoursPerDayBinding: Binding<String> {
        requiredNumberBinding(for: $hoursPerDayText, keyPath: \.hoursPerDay)
    }

    private var hoursPerWeekBinding: Binding<String> {
        requiredNumberBinding(for: $hoursPerWeekText, keyPath: \.hoursPerWeek)
    }

    private func requiredNumberBinding(
        for text: Binding<String>,
        keyPath: ReferenceWritableKeyPath<UserSettings, Double>
    ) -> Binding<String> {
        Binding(
            get: { text.wrappedValue },
            set: { newValue in
                text.wrappedValue = newValue
                saveRequiredNumberIfValid(newValue, keyPath: keyPath)
            }
        )
    }

    @ViewBuilder
    private func requiredNumberRow(title: String, text: Binding<String>, field: RequiredField) -> some View {
        let showsError = hasLoadedDraftValues && trimmedText(text.wrappedValue).isEmpty

        HStack(alignment: .top) {
            Text(title)
            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                TextField("", text: text)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
                    .focused($focusedField, equals: field)
                    .frame(width: 80)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color(nsColor: .controlBackgroundColor))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(borderColor(for: field, showsError: showsError), lineWidth: 1.5)
                    }

                if showsError {
                    Text("Required")
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private func borderColor(for field: RequiredField, showsError: Bool) -> Color {
        if showsError {
            return .red
        }
        if focusedField == field {
            return .accentColor
        }
        return Color.secondary.opacity(0.2)
    }

    private func loadDraftValues() {
        goalValueText = Self.formattedNumber(settings.goalValue)
        hoursPerDayText = Self.formattedNumber(settings.hoursPerDay)
        hoursPerWeekText = Self.formattedNumber(settings.hoursPerWeek)
        hasLoadedDraftValues = true
    }

    private func saveRequiredNumberIfValid(
        _ rawText: String,
        keyPath: ReferenceWritableKeyPath<UserSettings, Double>
    ) {
        let trimmed = trimmedText(rawText)
        guard !trimmed.isEmpty else { return }
        guard let value = Self.numberFormatter.number(from: trimmed)?.doubleValue else { return }
        guard settings[keyPath: keyPath] != value else { return }

        settings[keyPath: keyPath] = value
        try? modelContext.save()
        appState.refreshMetrics(modelContext: modelContext)
    }

    private func trimmedText(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func formattedNumber(_ value: Double) -> String {
        numberFormatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    private func weekdayButtonLabel(_ short: String) -> some View {
        Text(short)
            .font(.caption.bold())
            .frame(width: 36, height: 28)
    }

    private func toggleWorkingDay(_ dayID: Int) {
        var days = settings.workingDays
        if days.contains(dayID) {
            days.remove(dayID)
        } else {
            days.insert(dayID)
        }
        settings.workingDays = days
        try? modelContext.save()
        appState.refreshMetrics(modelContext: modelContext)
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
