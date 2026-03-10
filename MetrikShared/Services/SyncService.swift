import Foundation
import SwiftData
import os.log

private let syncLogger = Logger(subsystem: "com.metrik.app", category: "SyncService")

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
    private static let syncTimeout: TimeInterval = 300

    public init() {}

    public func startScheduledSync(modelContext: ModelContext, intervalMinutes: Int) {
        scheduledTask?.cancel()
        syncLogger.info("Starting scheduled sync with interval: \(intervalMinutes) min")
        appendLog(repo: "scheduler", message: "Scheduled sync every \(intervalMinutes) min", isError: false)
        scheduledTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.sync(modelContext: modelContext)
                try? await Task.sleep(for: .seconds(intervalMinutes * 60))
            }
            syncLogger.info("Scheduled sync loop exited (cancelled=\(Task.isCancelled))")
        }
    }

    public func stopScheduledSync() {
        syncLogger.info("Stopping scheduled sync")
        scheduledTask?.cancel()
        scheduledTask = nil
    }

    @MainActor
    public func sync(modelContext: ModelContext) async {
        guard !isSyncing else {
            syncLogger.warning("Sync skipped — already in progress")
            appendLog(repo: "sync", message: "Skipped: already syncing", isError: false)
            return
        }
        isSyncing = true
        syncError = nil
        let syncStart = Date()
        syncLogger.info("=== Sync started ===")
        appendLog(repo: "sync", message: "Starting sync…", isError: false)

        defer {
            isSyncing = false
            let elapsed = Date().timeIntervalSince(syncStart)
            syncLogger.info("=== Sync finished in \(String(format: "%.1f", elapsed))s ===")
            appendLog(repo: "sync", message: "Finished in \(String(format: "%.1f", elapsed))s", isError: false)
        }

        do {
            let configDescriptor = FetchDescriptor<LocalGitConfig>()
            guard let config = try modelContext.fetch(configDescriptor).first, config.isConfigured else {
                syncError = "Not configured. Open setup wizard."
                syncLogger.error("Sync aborted: not configured")
                appendLog(repo: "sync", message: "Aborted: not configured", isError: true)
                return
            }
            syncLogger.info("Config loaded, author: \(config.gitUserEmail)")
            appendLog(repo: "sync", message: "Author filter: \(config.gitUserEmail)", isError: false)

            let repoDescriptor = FetchDescriptor<TrackedRepo>(
                predicate: #Predicate { $0.isTracked }
            )
            let trackedRepos = try modelContext.fetch(repoDescriptor)
            syncLogger.info("Found \(trackedRepos.count) tracked repo(s)")
            appendLog(repo: "sync", message: "Found \(trackedRepos.count) tracked repo(s)", isError: false)

            guard !trackedRepos.isEmpty else {
                syncLogger.info("No tracked repos, nothing to sync")
                appendLog(repo: "sync", message: "No tracked repos", isError: false)
                lastSyncDate = Date()
                return
            }

            let repoInfos = trackedRepos.map { repo in
                RepoSyncInfo(
                    localPath: repo.localPath,
                    name: repo.name,
                    defaultBranch: repo.defaultBranch,
                    lastSyncDate: repo.lastSyncDate,
                    lastSyncedSHA: repo.lastSyncedSHA
                )
            }

            syncLogger.info("Step 1/4: Fetching all repos…")
            appendLog(repo: "sync", message: "Step 1/4: Fetching repos from remotes…", isError: false)
            let fetchStart = Date()

            let results = await withTimeout(seconds: Self.syncTimeout) {
                await self.fetchAllRepos(repos: repoInfos, authorEmail: config.gitUserEmail)
            }

            let fetchElapsed = Date().timeIntervalSince(fetchStart)
            syncLogger.info("Fetch completed in \(String(format: "%.1f", fetchElapsed))s")

            guard let results else {
                let msg = "Sync timed out after \(Int(Self.syncTimeout))s during fetch"
                syncError = msg
                syncLogger.error("\(msg)")
                appendLog(repo: "sync", message: msg, isError: true)
                return
            }

            syncLogger.info("Step 2/4: Merging commits…")
            appendLog(repo: "sync", message: "Step 2/4: Merging commits…", isError: false)
            var repoErrors: [String] = []
            for (index, result) in results.enumerated() {
                let repo = trackedRepos[index]
                switch result {
                case .skipped:
                    syncLogger.info("[\(repo.name)] Unchanged, skipped")
                    appendLog(repo: repo.name, message: "Unchanged, skipped", isError: false)
                case .success(let commits, let newHeadSHA, let emailWarning):
                    if let warning = emailWarning {
                        appendLog(repo: repo.name, message: warning, isError: true)
                    }
                    do {
                        syncLogger.info("[\(repo.name)] Merging \(commits.count) commit(s), head=\(newHeadSHA ?? "nil")")
                        try mergeCommits(commits, for: repo, authorEmail: config.gitUserEmail, modelContext: modelContext)
                        repo.lastSyncDate = Date()
                        if let sha = newHeadSHA { repo.lastSyncedSHA = sha }
                        appendLog(repo: repo.name, message: "Synced \(commits.count) commits", isError: false)
                    } catch {
                        let msg = error.localizedDescription
                        repoErrors.append("\(repo.name): \(msg)")
                        syncLogger.error("[\(repo.name)] Merge failed: \(msg)")
                        appendLog(repo: repo.name, message: msg, isError: true)
                    }
                case .failure(let message):
                    repoErrors.append("\(repo.name): \(message)")
                    syncLogger.error("[\(repo.name)] Fetch failed: \(message)")
                    appendLog(repo: repo.name, message: message, isError: true)
                }
            }

            syncLogger.info("Step 3/4: Deduplicating commits…")
            appendLog(repo: "sync", message: "Step 3/4: Deduplicating commits…", isError: false)
            try deduplicateCommits(modelContext: modelContext)

            syncLogger.info("Step 4/4: Aggregating daily summaries…")
            appendLog(repo: "sync", message: "Step 4/4: Aggregating daily summaries…", isError: false)
            try aggregateDailySummaries(trackedRepos: trackedRepos, modelContext: modelContext)

            lastSyncDate = Date()
            try modelContext.save()
            syncLogger.info("Model context saved")

            if !repoErrors.isEmpty {
                syncError = repoErrors.joined(separator: "; ")
            }

        } catch {
            syncError = error.localizedDescription
            syncLogger.error("Sync error: \(error.localizedDescription)")
            appendLog(repo: "global", message: error.localizedDescription, isError: true)
        }
    }

    private func withTimeout<T: Sendable>(seconds: TimeInterval, operation: @escaping @Sendable () async -> T) async -> T? {
        await withTaskGroup(of: T?.self) { group in
            group.addTask {
                await operation()
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(seconds))
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
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
        case success(commits: [CommitInfo], headSHA: String?, emailWarning: String?)
        case failure(String)
    }

    private func fetchAllRepos(repos: [RepoSyncInfo], authorEmail: String) async -> [RepoSyncResult] {
        await withTaskGroup(of: (Int, RepoSyncResult).self, returning: [RepoSyncResult].self) { group in
            for (index, repo) in repos.enumerated() {
                group.addTask { [gitService] in
                    let repoStart = Date()
                    syncLogger.info("[\(repo.name)] git fetch origin starting… (branch: \(repo.defaultBranch))")

                    do {
                        try await gitService.fetchOrigin(repoPath: repo.localPath)
                    } catch {
                        let elapsed = Date().timeIntervalSince(repoStart)
                        syncLogger.error("[\(repo.name)] git fetch failed after \(String(format: "%.1f", elapsed))s: \(error.localizedDescription)")
                        return (index, .failure(error.localizedDescription))
                    }

                    let fetchElapsed = Date().timeIntervalSince(repoStart)
                    syncLogger.info("[\(repo.name)] git fetch completed in \(String(format: "%.1f", fetchElapsed))s")

                    let postHeadSHA = await gitService.resolveRemoteHead(
                        repoPath: repo.localPath,
                        branch: repo.defaultBranch
                    )
                    syncLogger.info("[\(repo.name)] Remote HEAD: \(postHeadSHA ?? "nil"), last synced SHA: \(repo.lastSyncedSHA ?? "nil")")

                    if let postSHA = postHeadSHA, let lastSynced = repo.lastSyncedSHA, postSHA == lastSynced {
                        syncLogger.info("[\(repo.name)] No new commits, skipping")
                        return (index, .skipped)
                    }

                    let sinceDate: Date
                    if let lastSync = repo.lastSyncDate {
                        sinceDate = Calendar.current.date(byAdding: .day, value: -1, to: lastSync) ?? lastSync
                    } else {
                        sinceDate = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
                    }
                    syncLogger.info("[\(repo.name)] Fetching commits since \(sinceDate.formatted(.iso8601))")

                    let repoIdentity = await gitService.detectGitIdentity(repoPath: repo.localPath)
                    let repoEmail = repoIdentity?.email ?? "(not set)"
                    var emailWarning: String?
                    if repoEmail.lowercased() != authorEmail.lowercased() {
                        syncLogger.warning("[\(repo.name)] Email mismatch — config: \(authorEmail), repo git config: \(repoEmail)")
                        emailWarning = "Email mismatch: Metrik uses '\(authorEmail)' but repo git config has '\(repoEmail)'"
                    }

                    let logStart = Date()
                    let commits = await gitService.fetchMergedCommits(
                        repoPath: repo.localPath,
                        branch: repo.defaultBranch,
                        authorEmail: authorEmail,
                        since: sinceDate
                    )
                    let logElapsed = Date().timeIntervalSince(logStart)
                    syncLogger.info("[\(repo.name)] git log --author='\(authorEmail)' found \(commits.count) commit(s) in \(String(format: "%.1f", logElapsed))s")

                    if commits.isEmpty {
                        let recentAuthors = await gitService.sampleRecentAuthors(
                            repoPath: repo.localPath,
                            branch: repo.defaultBranch
                        )
                        if !recentAuthors.isEmpty {
                            let authorsList = recentAuthors.joined(separator: ", ")
                            syncLogger.warning("[\(repo.name)] 0 commits for '\(authorEmail)' but branch has commits by: \(authorsList)")
                            emailWarning = "No commits for '\(authorEmail)'. Found authors: \(authorsList)"
                        } else {
                            syncLogger.info("[\(repo.name)] Branch has no recent commits from any author")
                        }
                    }

                    let totalElapsed = Date().timeIntervalSince(repoStart)
                    syncLogger.info("[\(repo.name)] Repo sync finished in \(String(format: "%.1f", totalElapsed))s")
                    return (index, .success(commits: commits, headSHA: postHeadSHA, emailWarning: emailWarning))
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

        let allDescriptor = FetchDescriptor<MergedCommit>()
        let allExisting = try modelContext.fetch(allDescriptor)
        let existingBySHA = Dictionary(uniqueKeysWithValues: allExisting.map { ($0.sha, $0) })

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

    private func deduplicateCommits(modelContext: ModelContext) throws {
        let descriptor = FetchDescriptor<MergedCommit>()
        let allCommits = try modelContext.fetch(descriptor)

        var seenSHAs = Set<String>()
        var seenWork = Set<String>()
        for commit in allCommits {
            let dupeSHA = !seenSHAs.insert(commit.sha).inserted
            let workKey = "\(commit.title)|\(Int(commit.committedAt.timeIntervalSince1970))"
            let dupeWork = !seenWork.insert(workKey).inserted
            if dupeSHA || dupeWork {
                modelContext.delete(commit)
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
