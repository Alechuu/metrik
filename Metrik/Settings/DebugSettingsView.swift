import SwiftUI
import SwiftData

struct DebugSettingsView: View {
    @Bindable var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TrackedRepo.localPath) private var repos: [TrackedRepo]

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .medium
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Current error
            if let error = appState.syncService.syncError {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Last Sync Error", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.orange)

                    Text(error)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(10)
                .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                .glassEffectIfAvailable(cornerRadius: 8)
                .padding(.horizontal)
                .padding(.top, 12)
            }

            // Tracked repos status
            VStack(alignment: .leading, spacing: 4) {
                Text("Tracked Repositories")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.top, 12)

                List(repos, id: \.localPath) { repo in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Circle()
                                .fill(repo.isTracked ? .green : .gray)
                                .frame(width: 6, height: 6)
                            Text(repo.name)
                                .font(.caption.bold())
                            Spacer()
                            Text(repo.defaultBranch)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 4)
                                .background(.quaternary, in: Capsule())
                        }
                        Text(repo.localPath)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.head)
                        if let lastSync = repo.lastSyncDate {
                            Text("Last synced: \(lastSync.formatted(.dateTime))")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }

            Divider()

            // Sync log
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Sync Log")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Spacer()
                    if #available(macOS 26, *) {
                        Button("Clear") {
                            appState.syncService.clearLog()
                        }
                        .font(.caption)
                        .buttonStyle(.glass)
                        .disabled(appState.syncService.syncLog.isEmpty)
                    } else {
                        Button("Clear") {
                            appState.syncService.clearLog()
                        }
                        .font(.caption)
                        .buttonStyle(.borderless)
                        .disabled(appState.syncService.syncLog.isEmpty)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)

                if appState.syncService.syncLog.isEmpty {
                    Text("No log entries yet. Trigger a sync to see results.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                } else {
                    List(appState.syncService.syncLog) { entry in
                        HStack(spacing: 6) {
                            Image(systemName: entry.isError ? "xmark.circle.fill" : "checkmark.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(entry.isError ? .red : .green)

                            Text(entry.repoName)
                                .font(.caption.bold())
                                .frame(width: 80, alignment: .leading)
                                .lineLimit(1)

                            Text(entry.message)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(entry.isError ? .red : .secondary)
                                .lineLimit(2)
                                .textSelection(.enabled)

                            Spacer()

                            Text(timeFormatter.string(from: entry.date))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }

            Divider()

            // Actions
            HStack {
                if #available(macOS 26, *) {
                    Button("Sync Now") {
                        _ = Task {
                            await appState.syncService.sync(modelContext: modelContext)
                            appState.refreshMetrics(modelContext: modelContext)
                        }
                    }
                    .buttonStyle(.glass)
                    .disabled(appState.syncService.isSyncing)
                } else {
                    Button("Sync Now") {
                        _ = Task {
                            await appState.syncService.sync(modelContext: modelContext)
                            appState.refreshMetrics(modelContext: modelContext)
                        }
                    }
                    .disabled(appState.syncService.isSyncing)
                }

                if appState.syncService.isSyncing {
                    ProgressView()
                        .controlSize(.small)
                }

                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
}
