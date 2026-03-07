import SwiftUI

struct OffDayView: View {
    private static let messages = [
        ("hammock", "It's your day off!", "Go touch some grass."),
        ("cup.and.saucer.fill", "No commits today!", "Sip coffee, not merge conflicts."),
        ("gamecontroller.fill", "Day off mode: ON", "Your keyboard won't miss you. Maybe."),
        ("moon.zzz.fill", "Repos are sleeping too.", "Even main needs a break."),
        ("figure.walk", "Step away from the terminal.", "The bugs can wait until Monday."),
        ("party.popper.fill", "It's the weekend!", "Your CI/CD pipeline approves."),
    ]

    private let picked: (icon: String, title: String, subtitle: String)

    init() {
        picked = Self.messages[Calendar.current.component(.day, from: Date()) % Self.messages.count]
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: picked.icon)
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            VStack(spacing: 6) {
                Text(picked.title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(picked.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
    }
}
