import SwiftUI
import SwiftData
import AppKit

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

    @Query(sort: \MergedCommit.committedAt, order: .reverse) private var commits: [MergedCommit]
    @Query private var userSettingsList: [UserSettings]
    @Query private var gitConfigs: [LocalGitConfig]

    @State private var remoteURLCache: [String: String] = [:]
    @State private var timeFilter: ActivityTimeFilter = .preset(.thisWeek)
    @State private var customStartDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    @State private var customEndDate = Date()
    @State private var selectedRepoName: String? = nil
    @State private var trendMonthCount: Int = 6
    private let gitService = LocalGitService()
    private let trendCalculator = MonthlyTrendCalculator()

    private var userSettings: UserSettings { userSettingsList.first ?? UserSettings() }
    private var gitUserName: String { gitConfigs.first?.gitUserName ?? "You" }
    private var gitUserEmail: String { gitConfigs.first?.gitUserEmail ?? "" }

    private var availableRepos: [String] {
        Array(Set(commits.map(\.repoName))).sorted()
    }

    private var trendData: MonthlyTrendData {
        trendCalculator.calculateTrend(
            commits: commits,
            repoFilter: selectedRepoName,
            monthCount: trendMonthCount,
            hoursPerDay: userSettings.hoursPerDay,
            workingDays: userSettings.workingDays
        )
    }

    private var timeFilteredCommits: [MergedCommit] {
        let range = timeFilter.dateRange()
        return commits.filter { $0.committedAt >= range.start && $0.committedAt <= range.end }
    }

    private var filteredCommits: [MergedCommit] {
        guard let name = selectedRepoName else { return timeFilteredCommits }
        return timeFilteredCommits.filter { $0.repoName == name }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Solid titlebar backing behind traffic lights
            Color.mkBgPage
                .frame(height: 28)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    MonthlyTrendChartView(
                        trendData: trendData,
                        monthCount: $trendMonthCount,
                        selectedRepoName: $selectedRepoName,
                        availableRepos: availableRepos,
                        gitUserName: gitUserName,
                        gitUserEmail: gitUserEmail
                    )
                    activityCard
                }
                .padding(24)
            }
        }
        .frame(minWidth: 520, minHeight: 580)
        .preferredColorScheme(.dark)
        .onAppear { timeFilter = .preset(appState.selectedTimeRange) }
    }

    // MARK: – Activity Card

    private var activityCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Card header
            HStack(alignment: .center) {
                Text("Recent Activity")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.mkTextPrimary)
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
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.mkTextSecondary)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.mkTextTertiary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.mkBgInset)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.mkBorderLight, lineWidth: 0.5))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            .padding(.bottom, 12)

            // Custom date range row
            if case .custom = timeFilter {
                HStack(spacing: 12) {
                    DatePicker("From", selection: $customStartDate, displayedComponents: .date)
                        .labelsHidden()
                    DatePicker("To", selection: $customEndDate, displayedComponents: .date)
                        .labelsHidden()
                    Spacer()
                }
                .padding(.bottom, 12)
                .onChange(of: customStartDate) { _, v in timeFilter = .custom(start: v, end: customEndDate) }
                .onChange(of: customEndDate) { _, v in timeFilter = .custom(start: customStartDate, end: v) }
            }

            // Commit list or empty state
            if filteredCommits.isEmpty {
                emptyActivityView
            } else {
                ForEach(Array(filteredCommits.enumerated()), id: \.1.sha) { idx, commit in
                    if idx > 0 {
                        Rectangle()
                            .fill(Color.mkSeparator)
                            .frame(height: 1)
                    }
                    commitRow(commit)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.black.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.15), lineWidth: 0.5))
    }

    // MARK: – Empty State

    private var emptyActivityView: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.triangle.merge")
                .font(.system(size: 28))
                .foregroundStyle(Color.mkTextMuted)
            Text("No Activity")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.mkTextSecondary)
            Text("No merged commits \(timeFilter.label.lowercased()).")
                .font(.system(size: 13))
                .foregroundStyle(Color.mkTextTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: – Commit Row

    private func commitRow(_ commit: MergedCommit) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(commit.additions > 0 ? Color.mkPositive : Color.mkTextMuted)
                .frame(width: 7, height: 7)

            Text(commit.title)
                .font(.system(size: 13))
                .foregroundStyle(Color.mkTextPrimary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 6) {
                Text("+\(commit.additions)")
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .foregroundStyle(commit.additions > 0 ? Color.mkPositive : Color.mkTextTertiary)
                Text("-\(commit.deletions)")
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .foregroundStyle(commit.deletions > 0 ? Color.mkNegative : Color.mkTextTertiary)
            }

            Text(commit.committedAt.relativeDescription)
                .font(.system(size: 12))
                .foregroundStyle(Color.mkTextMuted)
                .frame(width: 28, alignment: .trailing)
        }
        .padding(.vertical, 10)
    }
}
