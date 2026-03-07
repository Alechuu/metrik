import Foundation
import SwiftData
import WidgetKit

public struct SyncLogEntry: Identifiable, Sendable {
    public let id = UUID()
    public let date: Date
    public let repoName: String
    public let message: String
    public let isError: Bool
}

@Observable
public final class SyncService {
    public var isSyncing = false
    public var lastSyncDate: Date?
    public var syncError: String?
    public var syncLog: [SyncLogEntry] = []

    private let gitService = LocalGitService()
    private var syncTask: Task<Void, Never>?
    private var scheduledTask: Task<Void, Never>?

    public init() {}

    public func startScheduledSync(modelContext: ModelContext, intervalMinutes: Int) {
        scheduledTask?.cancel()
        scheduledTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.sync(modelContext: modelContext)
                try? await Task.sleep(for: .seconds(intervalMinutes * 60))
            }
        }
    }

    public func stopScheduledSync() {
        scheduledTask?.cancel()
        scheduledTask = nil
    }

    @MainActor
    public func sync(modelContext: ModelContext) async {
        guard !isSyncing else { return }
        isSyncing = true
        syncError = nil

        do {
            let configDescriptor = FetchDescriptor<LocalGitConfig>()
            guard let config = try modelContext.fetch(configDescriptor).first, config.isConfigured else {
                syncError = "Not configured. Open setup wizard."
                isSyncing = false
                return
            }

            let repoDescriptor = FetchDescriptor<TrackedRepo>(
                predicate: #Predicate { $0.isTracked }
            )
            let trackedRepos = try modelContext.fetch(repoDescriptor)

            var repoErrors: [String] = []
            for repo in trackedRepos {
                do {
                    try await syncRepo(repo, authorEmail: config.gitUserEmail, modelContext: modelContext)
                    appendLog(repo: repo.name, message: "Synced OK", isError: false)
                } catch {
                    let msg = error.localizedDescription
                    repoErrors.append("\(repo.name): \(msg)")
                    appendLog(repo: repo.name, message: msg, isError: true)
                }
            }

            try await aggregateDailySummaries(modelContext: modelContext)

            lastSyncDate = Date()
            try modelContext.save()

            if !repoErrors.isEmpty {
                syncError = repoErrors.joined(separator: "; ")
            }

            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            syncError = error.localizedDescription
            appendLog(repo: "global", message: error.localizedDescription, isError: true)
        }

        isSyncing = false
    }

    private func syncRepo(_ repo: TrackedRepo, authorEmail: String, modelContext: ModelContext) async throws {
        // Fetch latest from origin (non-disruptive)
        try await gitService.fetchOrigin(repoPath: repo.localPath)

        let sinceDate: Date
        if let lastSync = repo.lastSyncDate {
            let calendar = Calendar.current
            sinceDate = calendar.date(byAdding: .day, value: -1, to: lastSync) ?? lastSync
        } else {
            let calendar = Calendar.current
            sinceDate = calendar.date(byAdding: .year, value: -1, to: Date()) ?? Date()
        }

        let commits = await gitService.fetchMergedCommits(
            repoPath: repo.localPath,
            branch: repo.defaultBranch,
            authorEmail: authorEmail,
            since: sinceDate
        )

        for commit in commits {
            let sha = commit.sha
            let existingDescriptor = FetchDescriptor<MergedCommit>(
                predicate: #Predicate { $0.sha == sha }
            )
            let existing = try modelContext.fetch(existingDescriptor)

            if let existingCommit = existing.first {
                existingCommit.additions = commit.additions
                existingCommit.deletions = commit.deletions
                existingCommit.title = commit.title
            } else {
                let merged = MergedCommit(
                    sha: commit.sha,
                    title: commit.title,
                    additions: commit.additions,
                    deletions: commit.deletions,
                    committedAt: commit.date,
                    repoPath: repo.localPath,
                    repoName: repo.name,
                    authorEmail: authorEmail
                )
                modelContext.insert(merged)
            }
        }

        repo.lastSyncDate = Date()
        if let lastCommit = commits.first {
            repo.lastSyncedSHA = lastCommit.sha
        }
    }

    private func aggregateDailySummaries(modelContext: ModelContext) async throws {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let repoDescriptor = FetchDescriptor<TrackedRepo>(
            predicate: #Predicate { $0.isTracked }
        )
        let trackedRepos = try modelContext.fetch(repoDescriptor)

        for repo in trackedRepos {
            let repoPath = repo.localPath
            let commitDescriptor = FetchDescriptor<MergedCommit>(
                predicate: #Predicate { $0.repoPath == repoPath }
            )
            let commits = try modelContext.fetch(commitDescriptor)

            let grouped = Dictionary(grouping: commits) { commit in
                calendar.startOfDay(for: commit.committedAt)
            }

            for (date, dayCommits) in grouped {
                guard date <= today else { continue }

                let summaryDate = date
                let existingDescriptor = FetchDescriptor<DailySummary>(
                    predicate: #Predicate {
                        $0.repoPath == repoPath && $0.date == summaryDate
                    }
                )
                let existing = try modelContext.fetch(existingDescriptor)

                let totalAdditions = dayCommits.reduce(0) { $0 + $1.additions }
                let totalDeletions = dayCommits.reduce(0) { $0 + $1.deletions }

                if let summary = existing.first {
                    summary.additions = totalAdditions
                    summary.deletions = totalDeletions
                    summary.commitCount = dayCommits.count
                } else {
                    let summary = DailySummary(
                        date: date,
                        repoPath: repoPath,
                        additions: totalAdditions,
                        deletions: totalDeletions,
                        commitCount: dayCommits.count
                    )
                    modelContext.insert(summary)
                }
            }
        }
    }

    public func scanForRepos(rootDirectory: String) async -> [RepoScanResult] {
        await gitService.scanForRepos(rootDirectory: rootDirectory)
    }

    public func detectGitIdentity(repoPath: String) async -> GitIdentity? {
        await gitService.detectGitIdentity(repoPath: repoPath)
    }

    public func detectDefaultBranch(repoPath: String) async -> String {
        await gitService.detectDefaultBranch(repoPath: repoPath)
    }

    public func clearLog() {
        syncLog.removeAll()
    }

    private func appendLog(repo: String, message: String, isError: Bool) {
        syncLog.append(SyncLogEntry(date: Date(), repoName: repo, message: message, isError: isError))
    }
}
