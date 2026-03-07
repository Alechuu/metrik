import Testing
import Foundation
@testable import MetrikShared

@Suite("MetricsCalculator Tests")
struct MetricsCalculatorTests {
    let calculator = MetricsCalculator()

    @Test("Empty commits returns zero metrics")
    func emptyCommits() {
        let result = calculator.calculate(
            commits: [],
            timeRange: .today,
            hoursPerDay: 8,
            hoursPerWeek: 40
        )

        #expect(result.additions == 0)
        #expect(result.deletions == 0)
        #expect(result.commitCount == 0)
        #expect(result.linesPerHour == 0)
        #expect(result.repoBreakdown.isEmpty)
    }

    @Test("Calculates additions and deletions correctly")
    func calculatesCorrectly() {
        let commits = [
            makeCommit(additions: 100, deletions: 20, repoPath: "/repos/frontend"),
            makeCommit(additions: 50, deletions: 10, repoPath: "/repos/backend"),
            makeCommit(additions: 200, deletions: 30, repoPath: "/repos/frontend"),
        ]

        let result = calculator.calculate(
            commits: commits,
            timeRange: .today,
            hoursPerDay: 8,
            hoursPerWeek: 40
        )

        #expect(result.additions == 350)
        #expect(result.deletions == 60)
        #expect(result.commitCount == 3)
    }

    @Test("Groups by repository")
    func groupsByRepo() {
        let commits = [
            makeCommit(additions: 100, deletions: 20, repoPath: "/repos/frontend"),
            makeCommit(additions: 50, deletions: 10, repoPath: "/repos/backend"),
            makeCommit(additions: 200, deletions: 30, repoPath: "/repos/frontend"),
        ]

        let result = calculator.calculate(
            commits: commits,
            timeRange: .today,
            hoursPerDay: 8,
            hoursPerWeek: 40
        )

        #expect(result.repoBreakdown.count == 2)
        let frontendMetric = result.repoBreakdown.first { $0.repoName == "frontend" }
        #expect(frontendMetric?.additions == 300)
        #expect(frontendMetric?.commitCount == 2)
    }

    @Test("Repo breakdown sorted by lines per hour descending")
    func sortedByRate() {
        let commits = [
            makeCommit(additions: 10, deletions: 0, repoPath: "/repos/small"),
            makeCommit(additions: 500, deletions: 0, repoPath: "/repos/large"),
            makeCommit(additions: 100, deletions: 0, repoPath: "/repos/medium"),
        ]

        let result = calculator.calculate(
            commits: commits,
            timeRange: .today,
            hoursPerDay: 8,
            hoursPerWeek: 40
        )

        #expect(result.repoBreakdown[0].repoName == "large")
        #expect(result.repoBreakdown[1].repoName == "medium")
        #expect(result.repoBreakdown[2].repoName == "small")
    }

    private func makeCommit(
        additions: Int,
        deletions: Int,
        repoPath: String,
        committedAt: Date = Date()
    ) -> MergedCommit {
        MergedCommit(
            sha: UUID().uuidString,
            title: "Test commit",
            additions: additions,
            deletions: deletions,
            committedAt: committedAt,
            repoPath: repoPath,
            repoName: URL(fileURLWithPath: repoPath).lastPathComponent,
            authorEmail: "test@example.com"
        )
    }
}
