import SwiftUI
import SwiftData

struct RecentActivityList: View {
    @Query(
        sort: \MergedCommit.committedAt,
        order: .reverse
    ) private var recentCommits: [MergedCommit]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recent Activity")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                Spacer()

                if !recentCommits.isEmpty {
                    Button {
                        NotificationCenter.default.post(name: .openActivityDetail, object: nil)
                    } label: {
                        HStack(spacing: 3) {
                            Text("See All")
                                .underline()
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 10))
                        }
                        .font(.caption)
                        .foregroundStyle(Color.mkTextSecondary)
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                    }
                }
            }

            if recentCommits.isEmpty {
                Text("No merged commits yet")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 4)
            } else {
                ForEach(recentCommits.prefix(3), id: \.sha) { commit in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(.green)
                            .frame(width: 6, height: 6)

                        Text(commit.title)
                            .font(.caption)
                            .lineLimit(1)
                            .truncationMode(.tail)

                        Spacer()

                        HStack(spacing: 6) {
                            Text("+\(commit.additions)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.green)

                            Text("-\(commit.deletions)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.red)

                            Text(commit.committedAt.relativeDescription)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .frame(width: 30, alignment: .trailing)
                        }
                    }
                }
            }
        }
    }
}

extension Date {
    var relativeDescription: String {
        let interval = Date().timeIntervalSince(self)
        if interval < 3600 {
            return "\(Int(interval / 60))m"
        } else if interval < 86400 {
            return "\(Int(interval / 3600))h"
        } else {
            return "\(Int(interval / 86400))d"
        }
    }
}
