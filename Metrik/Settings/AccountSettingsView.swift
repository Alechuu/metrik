import SwiftUI
import SwiftData
import AppKit

struct AccountSettingsView: View {
    @Bindable var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Query private var configs: [LocalGitConfig]
    @State private var isHoveringAvatar = false

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
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func configuredInfo(_ config: LocalGitConfig) -> some View {
        VStack(spacing: 16) {
            // Avatar with upload overlay
            ZStack(alignment: .bottom) {
                ProfileAvatarView(
                    userName: config.gitUserName,
                    userEmail: config.gitUserEmail,
                    size: 80,
                    customAvatarData: config.customAvatarData
                )

                // Edit overlay on hover
                if isHoveringAvatar {
                    Circle()
                        .fill(.black.opacity(0.5))
                        .frame(width: 80, height: 80)
                        .overlay {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(.white)
                        }
                }
            }
            .onHover { hovering in
                isHoveringAvatar = hovering
            }
            .onTapGesture {
                pickAvatarImage(for: config)
            }
            .help("Click to change profile photo")

            // Remove custom avatar button
            if config.customAvatarData != nil {
                Button("Remove custom photo") {
                    config.customAvatarData = nil
                    try? modelContext.save()
                }
                .font(.caption)
                .buttonStyle(.plain)
                .foregroundStyle(Color.mkTextSecondary)
            }

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

    private func pickAvatarImage(for config: LocalGitConfig) {
        let panel = NSOpenPanel()
        panel.title = "Choose Profile Photo"
        panel.allowedContentTypes = [.png, .jpeg, .heic, .webP]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let image = NSImage(contentsOf: url) else { return }

        // Resize to 256x256 max and store as JPEG
        let targetSize = NSSize(width: 256, height: 256)
        let resized = NSImage(size: targetSize)
        resized.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: targetSize),
                   from: NSRect(origin: .zero, size: image.size),
                   operation: .copy,
                   fraction: 1.0)
        resized.unlockFocus()

        guard let tiff = resized.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let jpegData = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.85]) else { return }

        config.customAvatarData = jpegData
        try? modelContext.save()
    }
}
