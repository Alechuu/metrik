import SwiftUI
import SwiftData

struct AccountSettingsView: View {
    @Bindable var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Query private var configs: [LocalGitConfig]

    private var config: LocalGitConfig? { configs.first }

    var body: some View {
        VStack(spacing: 20) {
            if let config = config, config.isConfigured {
                if #available(macOS 26, *) {
                    configuredInfo(config)
                        .padding(24)
                        .glassEffectIfAvailable(cornerRadius: 16)
                } else {
                    configuredInfo(config)
                }

                Spacer()

                if #available(macOS 26, *) {
                    Button(role: .destructive) {
                        appState.resetConfiguration(modelContext: modelContext)
                    } label: {
                        Label("Reset Configuration", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(.glass)
                } else {
                    Button(role: .destructive) {
                        appState.resetConfiguration(modelContext: modelContext)
                    } label: {
                        Label("Reset Configuration", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "gearshape.circle")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("Not configured")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Open the main window to run setup.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func configuredInfo(_ config: LocalGitConfig) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.system(size: 50))
                .foregroundStyle(.green)

            VStack(spacing: 4) {
                Text(config.gitUserName)
                    .font(.title2.bold())

                Text(config.gitUserEmail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 4) {
                Text("Projects Folder")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Text(config.rootDirectory)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }
}
