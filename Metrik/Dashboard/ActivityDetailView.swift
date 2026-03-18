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
    @Query(sort: \TrackedRepo.localPath) private var trackedRepos: [TrackedRepo]

    @State private var remoteURLCache: [String: String] = [:]
    @State private var timeFilter: ActivityTimeFilter = .preset(.thisWeek)
    @State private var customStartDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    @State private var customEndDate = Date()
    @State private var selectedRepoName: String? = nil
    @State private var trendMonthCount: Int = 6
    @State private var currentPage: Int = 0
    @State private var pageSize: Int = 5
    @State private var showCustomRangeSheet = false
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

    private var totalPages: Int {
        max(1, Int(ceil(Double(filteredCommits.count) / Double(pageSize))))
    }

    private var pagedCommits: [MergedCommit] {
        let start = currentPage * pageSize
        guard start < filteredCommits.count else { return [] }
        let end = min(start + pageSize, filteredCommits.count)
        return Array(filteredCommits[start..<end])
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                MonthlyTrendChartView(
                    trendData: trendData,
                    monthCount: $trendMonthCount,
                    selectedRepoName: $selectedRepoName,
                    availableRepos: availableRepos,
                    gitUserName: gitUserName,
                    gitUserEmail: gitUserEmail,
                    customAvatarData: gitConfigs.first?.customAvatarData
                )
                activityCard
            }
            .padding(24)
        }
        .frame(minWidth: 520)
        .preferredColorScheme(.dark)
        .onAppear { timeFilter = .preset(appState.selectedTimeRange) }
    }

    // MARK: – Activity Card

    private var activityCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Card header
            HStack(alignment: .center) {
                Text(selectedRepoName.map { "Activity — \($0)" } ?? "Activity")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.mkTextPrimary)
                Spacer()
                Menu {
                    Button("Today") { timeFilter = .preset(.today) }
                    Button("This Week") { timeFilter = .preset(.thisWeek) }
                    Button("This Month") { timeFilter = .preset(.thisMonth) }
                    Button("All Time") { timeFilter = .preset(.allTime) }
                    Divider()
                    Button("Custom Range...") { showCustomRangeSheet = true }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.mkTextSecondary)
                        Text(timeFilter.label)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.mkTextPrimary)
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.mkTextTertiary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.mkBgInset)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.mkBorderLight, lineWidth: 0.5))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            .padding(.bottom, 12)

            // Commit list or empty state
            if filteredCommits.isEmpty {
                emptyActivityView
            } else {
                ForEach(Array(pagedCommits.enumerated()), id: \.1.sha) { idx, commit in
                    if idx > 0 {
                        Rectangle()
                            .fill(Color.mkSeparator)
                            .frame(height: 1)
                    }
                    commitRow(commit)
                }

                // Pagination footer
                Rectangle()
                    .fill(Color.mkSeparator)
                    .frame(height: 1)
                    .padding(.top, 4)

                HStack(spacing: 6) {
                    // Page size selector
                    Menu {
                        ForEach([5, 10, 20], id: \.self) { size in
                            Button("\(size) per page") {
                                pageSize = size
                                currentPage = 0
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text("\(pageSize) per page")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.mkTextSecondary)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(Color.mkTextTertiary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.1), lineWidth: 0.5))
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()

                    Spacer()

                    // Page buttons (only when multiple pages)
                    if totalPages > 1 {
                        paginationButtons
                    }
                }
                .padding(.top, 10)
            }
        }
        .onChange(of: timeFilter) { _, _ in currentPage = 0 }
        .onChange(of: selectedRepoName) { _, _ in currentPage = 0 }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.black.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.15), lineWidth: 0.5))
        .sheet(isPresented: $showCustomRangeSheet) {
            CustomRangeSheet(
                startDate: $customStartDate,
                endDate: $customEndDate
            ) {
                timeFilter = .custom(start: customStartDate, end: customEndDate)
            }
        }
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

    // MARK: – Pagination

    private var paginationButtons: some View {
        HStack(spacing: 4) {
            // Previous
            pageNavButton(icon: "chevron.left", disabled: currentPage == 0) {
                currentPage = max(0, currentPage - 1)
            }

            // Page numbers with ellipsis
            ForEach(visiblePages, id: \.self) { page in
                if page == -1 {
                    Text("...")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.mkTextTertiary)
                        .frame(width: 28, height: 28)
                } else {
                    pageNumberButton(page)
                }
            }

            // Next
            pageNavButton(icon: "chevron.right", disabled: currentPage >= totalPages - 1) {
                currentPage = min(totalPages - 1, currentPage + 1)
            }
        }
    }

    private var visiblePages: [Int] {
        guard totalPages > 1 else { return [0] }
        if totalPages <= 5 {
            return Array(0..<totalPages)
        }
        var pages: [Int] = []
        // Always show first page
        pages.append(0)
        // Ellipsis or page before current
        if currentPage > 2 { pages.append(-1) }
        // Pages around current
        for p in max(1, currentPage - 1)...min(totalPages - 2, currentPage + 1) {
            if !pages.contains(p) { pages.append(p) }
        }
        // Ellipsis or page after current
        if currentPage < totalPages - 3 { pages.append(-1) }
        // Always show last page
        if !pages.contains(totalPages - 1) { pages.append(totalPages - 1) }
        return pages
    }

    private func pageNumberButton(_ page: Int) -> some View {
        let isActive = page == currentPage
        return Button { currentPage = page } label: {
            Text("\(page + 1)")
                .font(.system(size: 12, weight: isActive ? .bold : .medium).monospacedDigit())
                .foregroundStyle(isActive ? .white : Color.mkTextSecondary)
                .frame(width: 28, height: 28)
                .background(isActive ? Color.mkAccent : Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(isActive ? Color.clear : Color.white.opacity(0.1), lineWidth: 0.5)
                )
        }
        .buttonStyle(.borderless)
    }

    private func pageNavButton(icon: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(disabled ? Color.mkTextMuted : Color.mkTextSecondary)
                .frame(width: 28, height: 28)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.white.opacity(0.1), lineWidth: 0.5))
        }
        .buttonStyle(.borderless)
        .disabled(disabled)
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
                .lineLimit(1)
                .fixedSize()
                .frame(width: 36, alignment: .trailing)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture { openCommit(commit) }
        .onHover { hovering in
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }

    private func openCommit(_ commit: MergedCommit) {
        let remoteURL: String
        if let cached = remoteURLCache[commit.repoPath] {
            remoteURL = cached
        } else if let fetched = gitService.getRemoteURL(repoPath: commit.repoPath) {
            remoteURLCache[commit.repoPath] = fetched
            remoteURL = fetched
        } else {
            return
        }

        if let url = LocalGitService.commitWebURL(remoteURL: remoteURL, sha: commit.sha) {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: – Custom Range Sheet

private struct CustomRangeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var startDate: Date
    @Binding var endDate: Date
    var onApply: () -> Void

    @State private var draftStart: Date
    @State private var draftEnd: Date
    @State private var displayedMonth: Date
    @State private var selectingEnd = false

    private let calendar = Calendar.current
    private let weekdays = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
    private static let monthYearFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }()
    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f
    }()

    init(startDate: Binding<Date>, endDate: Binding<Date>, onApply: @escaping () -> Void) {
        _startDate = startDate
        _endDate = endDate
        self.onApply = onApply
        _draftStart = State(initialValue: startDate.wrappedValue)
        _draftEnd = State(initialValue: endDate.wrappedValue)
        _displayedMonth = State(initialValue: startDate.wrappedValue)
    }

    private var isValid: Bool {
        calendar.startOfDay(for: draftStart) <= calendar.startOfDay(for: draftEnd)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            separator
            rangePills
            separator
            monthNavigation
            weekdayHeader
            calendarGrid
            separator
            footer
        }
        .frame(width: 340)
        .background(Color.mkBgCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .preferredColorScheme(.dark)
    }

    // MARK: – Header

    private var header: some View {
        HStack {
            Text("Custom Range")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.mkTextPrimary)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.mkTextMuted)
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }

    // MARK: – Range Pills

    private var rangePills: some View {
        HStack(spacing: 10) {
            rangePill(
                label: "From",
                date: draftStart,
                isActive: !selectingEnd
            ) {
                selectingEnd = false
                displayedMonth = draftStart
            }
            Image(systemName: "arrow.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.mkTextMuted)
            rangePill(
                label: "To",
                date: draftEnd,
                isActive: selectingEnd
            ) {
                selectingEnd = true
                displayedMonth = draftEnd
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private func rangePill(label: String, date: Date, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 3) {
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isActive ? Color.mkAccent : Color.mkTextMuted)
                    .tracking(0.8)
                Text(Self.shortDateFormatter.string(from: date))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.mkTextPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isActive ? Color.mkAccent.opacity(0.1) : Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isActive ? Color.mkAccent.opacity(0.5) : Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.borderless)
    }

    // MARK: – Month Navigation

    private var monthNavigation: some View {
        HStack {
            Button { shiftMonth(-1) } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.mkTextSecondary)
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)

            Spacer()
            Text(Self.monthYearFormatter.string(from: displayedMonth))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.mkTextPrimary)
            Spacer()

            Button { shiftMonth(1) } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.mkTextSecondary)
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(weekdays, id: \.self) { day in
                Text(day)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.mkTextMuted)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
    }

    // MARK: – Calendar Grid

    private var calendarGrid: some View {
        let days = calendarDays()
        let rows = stride(from: 0, to: days.count, by: 7).map { Array(days[$0..<min($0 + 7, days.count)]) }

        return VStack(spacing: 2) {
            ForEach(Array(rows.enumerated()), id: \.0) { _, row in
                HStack(spacing: 0) {
                    ForEach(Array(row.enumerated()), id: \.0) { _, day in
                        dayCell(day)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    @ViewBuilder
    private func dayCell(_ day: CalendarDay) -> some View {
        let isStart = calendar.isDate(day.date, inSameDayAs: draftStart)
        let isEnd = calendar.isDate(day.date, inSameDayAs: draftEnd)
        let isInRange = day.date >= calendar.startOfDay(for: draftStart)
            && day.date <= calendar.startOfDay(for: draftEnd)
            && day.isCurrentMonth
        let isToday = calendar.isDateInToday(day.date) && day.isCurrentMonth
        let isEdge = (isStart || isEnd) && day.isCurrentMonth

        Button {
            guard day.isCurrentMonth else { return }
            selectDate(day.date)
        } label: {
            Text("\(calendar.component(.day, from: day.date))")
                .font(.system(size: 13, weight: isEdge ? .bold : isToday ? .semibold : .regular))
                .foregroundStyle(
                    isEdge ? .white :
                    !day.isCurrentMonth ? Color.mkTextMuted.opacity(0.4) :
                    isInRange ? Color.mkAccent :
                    isToday ? Color.mkAccent :
                    Color.mkTextPrimary
                )
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background(
                    Group {
                        if isEdge {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.mkAccent)
                        } else if isInRange {
                            Rectangle()
                                .fill(Color.mkAccent.opacity(0.1))
                        }
                    }
                )
        }
        .buttonStyle(.borderless)
        .disabled(!day.isCurrentMonth)
    }

    // MARK: – Footer

    private var footer: some View {
        HStack(spacing: 10) {
            if !isValid {
                HStack(spacing: 5) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                    Text("Invalid range")
                        .font(.system(size: 11))
                }
                .foregroundStyle(Color.mkNegative)
            }
            Spacer()
            Button("Cancel") { dismiss() }
                .font(.system(size: 13, weight: .medium))
                .buttonStyle(.borderless)
                .foregroundStyle(Color.mkTextSecondary)

            Button {
                startDate = draftStart
                endDate = draftEnd
                onApply()
                dismiss()
            } label: {
                Text("Apply")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color.mkAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.borderless)
            .disabled(!isValid)
            .opacity(isValid ? 1 : 0.5)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: – Helpers

    private var separator: some View {
        Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)
    }

    private func shiftMonth(_ delta: Int) {
        if let next = calendar.date(byAdding: .month, value: delta, to: displayedMonth) {
            withAnimation(.easeInOut(duration: 0.2)) { displayedMonth = next }
        }
    }

    private func selectDate(_ date: Date) {
        let day = calendar.startOfDay(for: date)
        if !selectingEnd {
            draftStart = day
            if day > calendar.startOfDay(for: draftEnd) {
                draftEnd = day
            }
            selectingEnd = true
        } else {
            if day < calendar.startOfDay(for: draftStart) {
                draftStart = day
            } else {
                draftEnd = day
            }
            selectingEnd = false
        }
    }

    private struct CalendarDay {
        let date: Date
        let isCurrentMonth: Bool
    }

    private func calendarDays() -> [CalendarDay] {
        let comps = calendar.dateComponents([.year, .month], from: displayedMonth)
        guard let firstOfMonth = calendar.date(from: comps),
              let range = calendar.range(of: .day, in: .month, for: firstOfMonth) else { return [] }

        // Monday = 1 offset. Calendar weekday: Sun=1 Mon=2 ... Sat=7
        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
        let leadingBlanks = (firstWeekday + 5) % 7  // Mon-based offset

        var days: [CalendarDay] = []

        // Leading days from previous month
        for i in (0..<leadingBlanks).reversed() {
            if let date = calendar.date(byAdding: .day, value: -(i + 1), to: firstOfMonth) {
                days.append(CalendarDay(date: date, isCurrentMonth: false))
            }
        }

        // Current month days
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                days.append(CalendarDay(date: date, isCurrentMonth: true))
            }
        }

        // Trailing days to fill last row
        let remainder = days.count % 7
        if remainder > 0 {
            let trailing = 7 - remainder
            if let lastOfMonth = calendar.date(byAdding: .day, value: range.count - 1, to: firstOfMonth) {
                for i in 1...trailing {
                    if let date = calendar.date(byAdding: .day, value: i, to: lastOfMonth) {
                        days.append(CalendarDay(date: date, isCurrentMonth: false))
                    }
                }
            }
        }

        return days
    }
}
