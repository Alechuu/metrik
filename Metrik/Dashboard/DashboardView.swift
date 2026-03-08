import SwiftUI
import SwiftData

struct DashboardView: View {
    @Bindable var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsList: [UserSettings]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Metrik")
                    .font(.headline)
                Spacer()
                Button {
                    NotificationCenter.default.post(name: .openSettings, object: nil)
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 14))
                }
                .buttonStyle(.borderless)
                .keyboardShortcut(",", modifiers: .command)

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 14))
                }
                .buttonStyle(.borderless)
                .keyboardShortcut("q", modifiers: .command)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            // Time Range Picker
            TimeRangePickerView(selection: Binding(
                get: { appState.selectedTimeRange },
                set: { newValue in
                    appState.selectedTimeRange = newValue
                    appState.refreshMetrics(modelContext: modelContext)
                }
            ))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider()

            if isOffDay {
                OffDayView()
                    .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        MetricsSummaryView(
                            metrics: appState.metrics,
                            goalMetric: selectedGoalMetric
                        )
                            .padding(.horizontal, 16)

                        Divider()
                            .padding(.horizontal, 16)

                        HorizontalBarChartView(repos: appState.metrics.repoBreakdown)
                            .padding(.horizontal, 16)

                        Divider()
                            .padding(.horizontal, 16)

                        RecentActivityList()
                            .padding(.horizontal, 16)
                    }
                    .padding(.vertical, 8)
                }
            }

            Divider()

            // Footer
            HStack {
                if appState.syncService.isSyncing {
                    ProgressView()
                        .controlSize(.small)
                    Text("Syncing...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let error = appState.syncService.syncError {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                } else if let lastSync = appState.syncService.lastSyncDate {
                    Text("Last synced: \(lastSync.relativeDescription) ago")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Not synced yet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Sync Now") {
                    _ = Task {
                        await appState.syncService.sync(modelContext: modelContext)
                        appState.refreshMetrics(modelContext: modelContext)
                    }
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .disabled(appState.syncService.isSyncing)
                .keyboardShortcut("r", modifiers: .command)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .task {
            appState.refreshMetrics(modelContext: modelContext)

            let settingsDescriptor = FetchDescriptor<UserSettings>()
            let interval = (try? modelContext.fetch(settingsDescriptor).first?.syncIntervalMinutes) ?? 15
            appState.syncService.startScheduledSync(modelContext: modelContext, intervalMinutes: interval)
        }
    }

    private var isOffDay: Bool {
        guard appState.selectedTimeRange == .today else { return false }
        let weekday = Calendar.current.component(.weekday, from: Date())
        let settings = settingsList.first ?? UserSettings()
        return !settings.isWorkingDay(weekday)
    }

    private var selectedGoalMetric: GoalProgressMetric? {
        guard appState.hasCodingGoal else { return nil }

        switch appState.selectedTimeRange {
        case .today:
            return GoalProgressMetric(
                title: "Daily Contribution Goal",
                subtitle: "Daily goal",
                progress: appState.dayProgress,
                color: .green,
                currentLines: appState.metricsToday.additions,
                expectedLines: appState.expectedDayLines
            )
        case .thisWeek:
            return GoalProgressMetric(
                title: "Weekly Contribution Goal",
                subtitle: "Weekly goal",
                progress: appState.weekProgress,
                color: .green,
                currentLines: appState.metricsWeek.additions,
                expectedLines: appState.expectedWeekLines
            )
        case .thisMonth:
            return GoalProgressMetric(
                title: "Monthly Contribution Goal",
                subtitle: "Monthly goal",
                progress: appState.monthProgress,
                color: .green,
                currentLines: appState.metricsMonth.additions,
                expectedLines: appState.expectedMonthLines
            )
        case .allTime:
            return nil
        }
    }
}
