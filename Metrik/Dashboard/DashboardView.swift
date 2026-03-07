import SwiftUI
import SwiftData

struct DashboardView: View {
    @Bindable var appState: AppState
    @Environment(\.modelContext) private var modelContext

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

            ScrollView {
                VStack(spacing: 16) {
                    // Metrics Summary
                    MetricsSummaryView(metrics: appState.metrics)
                        .padding(.horizontal, 16)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))

                    Divider()
                        .padding(.horizontal, 16)

                    // Bar Chart
                    HorizontalBarChartView(repos: appState.metrics.repoBreakdown)
                        .padding(.horizontal, 16)

                    Divider()
                        .padding(.horizontal, 16)

                    // Recent Activity
                    RecentActivityList()
                        .padding(.horizontal, 16)
                }
                .padding(.vertical, 8)
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
                    Task {
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
}
