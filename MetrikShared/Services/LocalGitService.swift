import Foundation

public struct CommitInfo: Sendable {
    public let sha: String
    public let title: String
    public let date: Date
    public let additions: Int
    public let deletions: Int
}

public struct RepoScanResult: Sendable {
    public let path: String
    public let name: String
}

public struct GitIdentity: Sendable {
    public let name: String
    public let email: String
}

public actor LocalGitService {
    public init() {}

    public func scanForRepos(rootDirectory: String, maxDepth: Int = 3) -> [RepoScanResult] {
        let fileManager = FileManager.default
        let rootURL = URL(fileURLWithPath: rootDirectory)
        var results: [RepoScanResult] = []

        scanDirectory(rootURL, fileManager: fileManager, currentDepth: 0, maxDepth: maxDepth, results: &results)

        return results.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func scanDirectory(
        _ url: URL,
        fileManager: FileManager,
        currentDepth: Int,
        maxDepth: Int,
        results: inout [RepoScanResult]
    ) {
        guard currentDepth <= maxDepth else { return }

        let gitDir = url.appendingPathComponent(".git")
        if fileManager.fileExists(atPath: gitDir.path) {
            let name = url.lastPathComponent
            results.append(RepoScanResult(path: url.path, name: name))
            return
        }

        guard let contents = try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return }

        for item in contents {
            guard let resourceValues = try? item.resourceValues(forKeys: [.isDirectoryKey]),
                  resourceValues.isDirectory == true else { continue }
            scanDirectory(item, fileManager: fileManager, currentDepth: currentDepth + 1, maxDepth: maxDepth, results: &results)
        }
    }

    public func detectGitIdentity(repoPath: String) -> GitIdentity? {
        let name = runGit(args: ["config", "user.name"], in: repoPath)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = runGit(args: ["config", "user.email"], in: repoPath)?.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let name, !name.isEmpty, let email, !email.isEmpty else { return nil }
        return GitIdentity(name: name, email: email)
    }

    public func detectDefaultBranch(repoPath: String) -> String {
        if let ref = runGit(args: ["symbolic-ref", "refs/remotes/origin/HEAD"], in: repoPath)?
            .trimmingCharacters(in: .whitespacesAndNewlines) {
            let prefix = "refs/remotes/origin/"
            if ref.hasPrefix(prefix) {
                return String(ref.dropFirst(prefix.count))
            }
        }

        // Fallback: check if main or master exists
        if let branches = runGit(args: ["branch", "-r"], in: repoPath) {
            if branches.contains("origin/main") {
                return "main"
            } else if branches.contains("origin/master") {
                return "master"
            }
        }

        return "main"
    }

    public func getRemoteURL(repoPath: String) -> String? {
        guard let url = runGit(args: ["config", "--get", "remote.origin.url"], in: repoPath)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !url.isEmpty else { return nil }
        return url
    }

    public static func commitWebURL(remoteURL: String, sha: String) -> URL? {
        var cleaned = remoteURL.trimmingCharacters(in: .whitespacesAndNewlines)

        // SSH format: git@github.com:owner/repo.git
        if cleaned.hasPrefix("git@") {
            cleaned = cleaned
                .replacingOccurrences(of: "git@github.com:", with: "https://github.com/")
        }

        // Remove trailing .git
        if cleaned.hasSuffix(".git") {
            cleaned = String(cleaned.dropLast(4))
        }

        // Remove trailing slash
        if cleaned.hasSuffix("/") {
            cleaned = String(cleaned.dropLast())
        }

        return URL(string: "\(cleaned)/commit/\(sha)")
    }

    public func resolveRemoteHead(repoPath: String, branch: String) -> String? {
        runGit(args: ["rev-parse", "origin/\(branch)"], in: repoPath)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func fetchOrigin(repoPath: String) async throws {
        let result = await runGitAsync(args: ["fetch", "origin", "--prune", "--quiet"], in: repoPath)
        if result.exitCode != 0 {
            throw LocalGitError.fetchFailed(repoPath: repoPath, message: result.output ?? "Unknown error")
        }
    }

    public func sampleRecentAuthors(repoPath: String, branch: String, limit: Int = 50) async -> [String] {
        let result = await runGitAsync(
            args: ["log", "origin/\(branch)", "--format=%ae", "-\(limit)"],
            in: repoPath
        )
        guard result.exitCode == 0, let output = result.output else { return [] }
        let emails = output
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
        return Array(Set(emails)).sorted()
    }

    public func fetchMergedCommits(
        repoPath: String,
        branch: String,
        authorEmail: String,
        since: Date
    ) async -> [CommitInfo] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let sinceStr = formatter.string(from: since)

        let format = "---COMMIT---%n%H%n%s%n%aI"
        let authorArg = "--author=\(authorEmail)"
        let sinceArg = "--since=\(sinceStr)"
        let refArg = "origin/\(branch)"

        let result = await runGitAsync(
            args: ["log", refArg, "--first-parent", authorArg, "--format=\(format)", "--numstat", sinceArg],
            in: repoPath
        )
        guard result.exitCode == 0, let output = result.output else { return [] }

        return parseGitLog(output)
    }

    private func parseGitLog(_ output: String) -> [CommitInfo] {
        let chunks = output.components(separatedBy: "---COMMIT---")
        var commits: [CommitInfo] = []

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]

        for chunk in chunks {
            let trimmed = chunk.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            let lines = trimmed.components(separatedBy: "\n")
            guard lines.count >= 3 else { continue }

            let sha = lines[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let title = lines[1].trimmingCharacters(in: .whitespacesAndNewlines)
            let dateStr = lines[2].trimmingCharacters(in: .whitespacesAndNewlines)

            guard !sha.isEmpty, let date = isoFormatter.date(from: dateStr) else { continue }

            var additions = 0
            var deletions = 0

            for i in 3..<lines.count {
                let statLine = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
                guard !statLine.isEmpty else { continue }
                let parts = statLine.split(separator: "\t")
                guard parts.count >= 2 else { continue }
                // Binary files show "-" for additions/deletions
                additions += Int(parts[0]) ?? 0
                deletions += Int(parts[1]) ?? 0
            }

            commits.append(CommitInfo(
                sha: sha,
                title: title,
                date: date,
                additions: additions,
                deletions: deletions
            ))
        }

        var seenSHAs = Set<String>()
        var seenWork = Set<String>()
        return commits.filter {
            guard seenSHAs.insert($0.sha).inserted else { return false }
            let workKey = "\($0.title)|\(Int($0.date.timeIntervalSince1970))"
            return seenWork.insert(workKey).inserted
        }
    }

    private func runGit(args: [String], in directory: String) -> String? {
        let result = runGitSync(args: args, in: directory)
        return result.exitCode == 0 ? result.output : nil
    }

    private static let processTimeout: TimeInterval = 60

    private func runGitSync(args: [String], in directory: String) -> (output: String?, exitCode: Int32) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args
        process.currentDirectoryURL = URL(fileURLWithPath: directory)

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()

            let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

            process.waitUntilExit()

            let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
            let stderr = String(data: stderrData, encoding: .utf8) ?? ""
            let combined = stdout.isEmpty ? stderr : stdout
            return (combined, process.terminationStatus)
        } catch {
            return (nil, -1)
        }
    }

    private func runGitAsync(args: [String], in directory: String) async -> (output: String?, exitCode: Int32) {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
                process.arguments = args
                process.currentDirectoryURL = URL(fileURLWithPath: directory)

                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()
                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe

                var didResume = false
                let resumeOnce: ((String?, Int32)) -> Void = { result in
                    guard !didResume else { return }
                    didResume = true
                    continuation.resume(returning: result)
                }

                let timer = DispatchSource.makeTimerSource(queue: .global())
                timer.schedule(deadline: .now() + Self.processTimeout)
                timer.setEventHandler {
                    if process.isRunning {
                        process.terminate()
                    }
                    resumeOnce(("Git process timed out after \(Int(Self.processTimeout))s", -2))
                }
                timer.resume()

                do {
                    try process.run()

                    let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                    let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

                    process.waitUntilExit()
                    timer.cancel()

                    let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
                    let stderr = String(data: stderrData, encoding: .utf8) ?? ""
                    let combined = stdout.isEmpty ? stderr : stdout
                    resumeOnce((combined, process.terminationStatus))
                } catch {
                    timer.cancel()
                    resumeOnce((nil, -1))
                }
            }
        }
    }
}

public enum LocalGitError: LocalizedError {
    case fetchFailed(repoPath: String, message: String)

    public var errorDescription: String? {
        switch self {
        case .fetchFailed(let path, let message):
            return "Failed to fetch \(URL(fileURLWithPath: path).lastPathComponent): \(message)"
        }
    }
}
