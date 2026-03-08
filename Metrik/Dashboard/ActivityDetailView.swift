import SwiftUI
import SwiftData
import AppKit

// Time range for the Activity window (presets + custom range).
private enum ActivityTimeFilter: Equatable {
    case preset(TimeRange)
    case custom(start: Date, end: Date)

    var label: String {
        switch self {
        case .preset(let range): return range.rawValue
        case .custom: return "Custom Range"
        }
    }

    func dateRange(now: Date = Date()) -> (start: Date, end: Date) {
        switch self {
        case .preset(let range): return range.dateRange
        case .custom(let start, let end): return (start, end)
        }
    }
}

struct ActivityDetailView: View {
    var appState: AppState

    @Query(
        sort: \MergedCommit.committedAt,
        order: .reverse
    ) private var commits: [MergedCommit]

    @State private var remoteURLCache: [String: String] = [:]
    @State private var timeFilter: ActivityTimeFilter = .preset(.thisWeek)
    @State private var customStartDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    @State private var customEndDate = Date()
    @State private var selectedRepoName: String? = nil
    private let gitService = LocalGitService()

    private var timeFilteredCommits: [MergedCommit] {
        let range = timeFilter.dateRange()
        return commits.filter { $0.committedAt >= range.start && $0.committedAt <= range.end }
    }

    private var availableRepos: [String] {
        Array(Set(timeFilteredCommits.map(\.repoName))).sorted()
    }

    private var filteredCommits: [MergedCommit] {
        guard let name = selectedRepoName else { return timeFilteredCommits }
        return timeFilteredCommits.filter { $0.repoName == name }
    }

    private var totalAdditions: Int {
        filteredCommits.reduce(0) { $0 + $1.additions }
    }

    private var totalDeletions: Int {
        filteredCommits.reduce(0) { $0 + $1.deletions }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: title + time range dropdown + repo dropdown
            HStack(alignment: .center, spacing: 12) {
                Text("Activity")
                    .font(.title2.bold())

                Spacer()

                Menu {
                    Button("Today") { timeFilter = .preset(.today) }
                    Button("This Week") { timeFilter = .preset(.thisWeek) }
                    Button("This Month") { timeFilter = .preset(.thisMonth) }
                    Button("All Time") { timeFilter = .preset(.allTime) }
                    Divider()
                    Button("Custom Range...") { timeFilter = .custom(start: customStartDate, end: customEndDate) }
                } label: {
                    HStack(spacing: 4) {
                        Text(timeFilter.label)
                            .font(.subheadline)
                        Image(systemName: "chevron.down")
                            .font(.caption2.bold())
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                Menu {
                    Button("All repos") { selectedRepoName = nil }
                    if !availableRepos.isEmpty {
                        Divider()
                        ForEach(availableRepos, id: \.self) { repo in
                            Button(repo) { selectedRepoName = repo }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(selectedRepoName ?? "All repos")
                            .font(.subheadline)
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.caption2.bold())
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .menuStyle(.borderlessButton)
                .frame(maxWidth: 140)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Custom date range row (when Custom Range is selected)
            if case .custom = timeFilter {
                HStack(spacing: 12) {
                    DatePicker("From", selection: $customStartDate, displayedComponents: .date)
                        .labelsHidden()
                    DatePicker("To", selection: $customEndDate, displayedComponents: .date)
                        .labelsHidden()
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
                .onChange(of: customStartDate) { _, newValue in
                    timeFilter = .custom(start: newValue, end: customEndDate)
                }
                .onChange(of: customEndDate) { _, newValue in
                    timeFilter = .custom(start: customStartDate, end: newValue)
                }
            }

            Divider()

            if filteredCommits.isEmpty {
                ContentUnavailableView(
                    "No Activity",
                    systemImage: "tray",
                    description: Text(emptyDescription)
                )
            } else {
                List(filteredCommits, id: \.sha) { commit in
                    commitRow(commit)
                }
                .listStyle(.plain)

                Divider()

                HStack(spacing: 16) {
                    Text("Total")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                    Text("+\(totalAdditions)")
                        .font(.subheadline.monospacedDigit().bold())
                        .foregroundStyle(.green)
                    Text("-\(totalDeletions)")
                        .font(.subheadline.monospacedDigit().bold())
                        .foregroundStyle(.red)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.quaternary.opacity(0.5))
            }
        }
        .frame(minWidth: 500, minHeight: 400)
        .onAppear {
            timeFilter = .preset(appState.selectedTimeRange)
        }
    }

    private var emptyDescription: String {
        if selectedRepoName != nil {
            return "No merged commits in \(timeFilter.label) for this repo."
        }
        return "No merged commits in \(timeFilter.label)."
    }

    @ViewBuilder
    private func commitRow(_ commit: MergedCommit) -> some View {
        HStack(spacing: 10) {
            Text(commit.repoName)
                .font(.caption2.bold())
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 4))

            VStack(alignment: .leading, spacing: 2) {
                Text(commit.title)
                    .font(.body)
                    .lineLimit(2)

                Text(commit.committedAt.relativeDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                Text("+\(commit.additions)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.green)

                Text("-\(commit.deletions)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.red)
            }

            Button {
                openCommitInBrowser(commit)
            } label: {
                Image(systemName: "arrow.up.right.square")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Open on GitHub")
        }
        .padding(.vertical, 4)
    }

    private func openCommitInBrowser(_ commit: MergedCommit) {
        _ = Task {
            let remote: String?
            if let cached = remoteURLCache[commit.repoPath] {
                remote = cached
            } else {
                let fetched = await gitService.getRemoteURL(repoPath: commit.repoPath)
                if let fetched {
                    await MainActor.run {
                        remoteURLCache[commit.repoPath] = fetched
                    }
                }
                remote = fetched
            }

            guard let remote,
                  let url = LocalGitService.commitWebURL(remoteURL: remote, sha: commit.sha) else { return }

            await MainActor.run {
                _ = NSWorkspace.shared.open(url)
            }
        }
    }
}
