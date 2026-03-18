import SwiftUI
import SwiftData

struct DebugSettingsView: View {
    @Bindable var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TrackedRepo.localPath) private var repos: [TrackedRepo]
    @Query private var gitConfigs: [LocalGitConfig]
    @State private var repoEmails: [String: String] = [:]

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

            // Configured identity
            if let config = gitConfigs.first {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sync Identity")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(config.gitUserName) <\(config.gitUserEmail)>")
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                    }
                    Text("Commits are filtered by this email via git log --author")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
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

                        repoEmailRow(for: repo)

                        if let lastSync = repo.lastSyncDate {
                            Text("Last synced: \(lastSync.formatted(.dateTime))")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .task {
                await loadRepoEmails()
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
                    List(appState.syncService.syncLog.reversed()) { entry in
                        let isStep = entry.repoName == "sync" || entry.repoName == "scheduler"
                        HStack(spacing: 6) {
                            Image(systemName: logIcon(for: entry, isStep: isStep))
                                .font(.caption2)
                                .foregroundStyle(logColor(for: entry, isStep: isStep))

                            Text(entry.repoName)
                                .font(.caption.bold())
                                .foregroundStyle(isStep ? .blue : .primary)
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
                    .scrollContentBackground(.hidden)
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

    @ViewBuilder
    private func repoEmailRow(for repo: TrackedRepo) -> some View {
        if let repoEmail = repoEmails[repo.localPath] {
            let matches = repoEmail.lowercased() == (gitConfigs.first?.gitUserEmail ?? "").lowercased()
            HStack(spacing: 3) {
                Image(systemName: matches ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .foregroundColor(matches ? .green : .orange)
                Text("git email: \(repoEmail)")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(matches ? .gray : .orange)
            }
        }
    }

    private func loadRepoEmails() async {
        for repo in repos where repo.isTracked {
            if let identity = await appState.syncService.detectGitIdentity(repoPath: repo.localPath) {
                repoEmails[repo.localPath] = identity.email
            }
        }
    }

    private func logIcon(for entry: SyncLogEntry, isStep: Bool) -> String {
        if entry.isError { return "xmark.circle.fill" }
        if isStep { return "arrow.triangle.2.circlepath" }
        return "checkmark.circle.fill"
    }

    private func logColor(for entry: SyncLogEntry, isStep: Bool) -> Color {
        if entry.isError { return .red }
        if isStep { return .blue }
        return .green
    }
}
