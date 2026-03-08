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

            // (1) Parallel: gather repo metadata then fetch all origins concurrently
            let repoInfos = trackedRepos.map { repo in
                RepoSyncInfo(
                    localPath: repo.localPath,
                    name: repo.name,
                    defaultBranch: repo.defaultBranch,
                    lastSyncDate: repo.lastSyncDate,
                    lastSyncedSHA: repo.lastSyncedSHA
                )
            }

            let results = await fetchAllRepos(
                repos: repoInfos,
                authorEmail: config.gitUserEmail
            )

            // Apply results back to the model context on the main actor
            var repoErrors: [String] = []
            for (index, result) in results.enumerated() {
                let repo = trackedRepos[index]
                switch result {
                case .skipped:
                    appendLog(repo: repo.name, message: "Unchanged, skipped", isError: false)
                case .success(let commits, let newHeadSHA):
                    do {
                        try mergeCommits(commits, for: repo, authorEmail: config.gitUserEmail, modelContext: modelContext)
                        repo.lastSyncDate = Date()
                        if let sha = newHeadSHA { repo.lastSyncedSHA = sha }
                        appendLog(repo: repo.name, message: "Synced \(commits.count) commits", isError: false)
                    } catch {
                        let msg = error.localizedDescription
                        repoErrors.append("\(repo.name): \(msg)")
                        appendLog(repo: repo.name, message: msg, isError: true)
                    }
                case .failure(let message):
                    repoErrors.append("\(repo.name): \(message)")
                    appendLog(repo: repo.name, message: message, isError: true)
                }
            }

            // (4) Incremental daily summaries
            try aggregateDailySummaries(trackedRepos: trackedRepos, modelContext: modelContext)

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

    // -- (1) Parallel fetch + (3) skip-when-unchanged + (5) async git --

    private struct RepoSyncInfo: Sendable {
        let localPath: String
        let name: String
        let defaultBranch: String
        let lastSyncDate: Date?
        let lastSyncedSHA: String?
    }

    private enum RepoSyncResult: Sendable {
        case skipped
        case success(commits: [CommitInfo], headSHA: String?)
        case failure(String)
    }

    private func fetchAllRepos(repos: [RepoSyncInfo], authorEmail: String) async -> [RepoSyncResult] {
        await withTaskGroup(of: (Int, RepoSyncResult).self, returning: [RepoSyncResult].self) { group in
            for (index, repo) in repos.enumerated() {
                group.addTask { [gitService] in
                    // (3) Check if remote HEAD changed before doing a network fetch
                    let preHeadSHA = await gitService.resolveRemoteHead(
                        repoPath: repo.localPath,
                        branch: repo.defaultBranch
                    )

                    if let preSHA = preHeadSHA, let lastSynced = repo.lastSyncedSHA, preSHA == lastSynced {
                        return (index, .skipped)
                    }

                    // Network fetch
                    do {
                        try await gitService.fetchOrigin(repoPath: repo.localPath)
                    } catch {
                        return (index, .failure(error.localizedDescription))
                    }

                    // (3) Check again after fetch to capture new head
                    let postHeadSHA = await gitService.resolveRemoteHead(
                        repoPath: repo.localPath,
                        branch: repo.defaultBranch
                    )

                    // If head is still the same after fetch, skip the log parse
                    if let postSHA = postHeadSHA, let lastSynced = repo.lastSyncedSHA, postSHA == lastSynced {
                        return (index, .skipped)
                    }

                    let sinceDate: Date
                    if let lastSync = repo.lastSyncDate {
                        sinceDate = Calendar.current.date(byAdding: .day, value: -1, to: lastSync) ?? lastSync
                    } else {
                        sinceDate = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
                    }

                    let commits = await gitService.fetchMergedCommits(
                        repoPath: repo.localPath,
                        branch: repo.defaultBranch,
                        authorEmail: authorEmail,
                        since: sinceDate
                    )

                    return (index, .success(commits: commits, headSHA: postHeadSHA))
                }
            }

            var results = Array(repeating: RepoSyncResult.skipped, count: repos.count)
            for await (index, result) in group {
                results[index] = result
            }
            return results
        }
    }

    // -- (2) Batch SHA lookup --

    private func mergeCommits(
        _ commits: [CommitInfo],
        for repo: TrackedRepo,
        authorEmail: String,
        modelContext: ModelContext
    ) throws {
        guard !commits.isEmpty else { return }

        let repoPath = repo.localPath
        let commitDescriptor = FetchDescriptor<MergedCommit>(
            predicate: #Predicate { $0.repoPath == repoPath }
        )
        let existingCommits = try modelContext.fetch(commitDescriptor)
        let existingBySHA = Dictionary(uniqueKeysWithValues: existingCommits.map { ($0.sha, $0) })

        for commit in commits {
            if let existing = existingBySHA[commit.sha] {
                existing.additions = commit.additions
                existing.deletions = commit.deletions
                existing.title = commit.title
            } else {
                modelContext.insert(MergedCommit(
                    sha: commit.sha,
                    title: commit.title,
                    additions: commit.additions,
                    deletions: commit.deletions,
                    committedAt: commit.date,
                    repoPath: repo.localPath,
                    repoName: repo.name,
                    authorEmail: authorEmail
                ))
            }
        }
    }

    // -- (4) Incremental daily summaries --

    private func aggregateDailySummaries(trackedRepos: [TrackedRepo], modelContext: ModelContext) throws {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        for repo in trackedRepos {
            let repoPath = repo.localPath

            let summaryDescriptor = FetchDescriptor<DailySummary>(
                predicate: #Predicate { $0.repoPath == repoPath },
                sortBy: [SortDescriptor(\DailySummary.date, order: .reverse)]
            )
            let latestSummary = try modelContext.fetch(summaryDescriptor).first
            let cutoff = latestSummary?.date ?? Date.distantPast

            let commitDescriptor = FetchDescriptor<MergedCommit>(
                predicate: #Predicate { $0.repoPath == repoPath && $0.committedAt >= cutoff }
            )
            let recentCommits = try modelContext.fetch(commitDescriptor)
            guard !recentCommits.isEmpty else { continue }

            let grouped = Dictionary(grouping: recentCommits) { commit in
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
                    modelContext.insert(DailySummary(
                        date: date,
                        repoPath: repoPath,
                        additions: totalAdditions,
                        deletions: totalDeletions,
                        commitCount: dayCommits.count
                    ))
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
