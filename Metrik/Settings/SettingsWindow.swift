import SwiftUI

enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case repositories
    case account
    case debug

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .repositories: "Repositories"
        case .account: "Account"
        case .debug: "Debug"
        }
    }

    var icon: String {
        switch self {
        case .general: "gearshape"
        case .repositories: "folder.fill"
        case .account: "person.fill"
        case .debug: "ladybug.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .general: Color.gray
        case .repositories: Color.mkAccent
        case .account: Color.mkPositive
        case .debug: Color.orange
        }
    }
}

struct SettingsWindow: View {
    @Bindable var appState: AppState
    @State private var selectedSection: SettingsSection = .general

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            VStack(spacing: 2) {
                ForEach(SettingsSection.allCases) { section in
                    Button {
                        selectedSection = section
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: section.icon)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 26, height: 26)
                                .background(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(section.iconColor)
                                )
                            Text(section.title)
                                .font(.body)
                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(selectedSection == section ? Color.mkAccent : Color.clear)
                        )
                        .foregroundStyle(selectedSection == section ? .white : .primary)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 16)
            .frame(width: 200)
            .background(Color.black.opacity(0.25))

            Divider()

            // Detail pane
            Group {
                switch selectedSection {
                case .general:
                    GeneralSettingsView(appState: appState)
                case .repositories:
                    RepoSelectionView(appState: appState)
                case .account:
                    AccountSettingsView(appState: appState)
                case .debug:
                    DebugSettingsView(appState: appState)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 680, height: 660)
        .preferredColorScheme(.dark)
    }
}

extension View {
    @ViewBuilder
    func glassEffectIfAvailable(cornerRadius: CGFloat) -> some View {
        if #available(macOS 26, *) {
            self.glassEffect(in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            self
        }
    }
}
