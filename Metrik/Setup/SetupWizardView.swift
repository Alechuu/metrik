import SwiftUI
import SwiftData

struct SetupWizardView: View {
    @Bindable var appState: AppState
    @Environment(\.modelContext) private var modelContext

    @State private var step = 1
    @State private var rootDirectory = ""
    @State private var scannedRepos: [ScannedRepo] = []
    @State private var isScanning = false
    @State private var gitUserName = ""
    @State private var gitUserEmail = ""
    @State private var goalValue = 500.0
    @State private var goalUnit: GoalUnit = .perWeek
    @State private var isSaving = false

    struct ScannedRepo: Identifiable {
        let id = UUID()
        let path: String
        let name: String
        var isSelected: Bool
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Metrik Setup")
                    .font(.headline)
                Spacer()
                Text("Step \(step) of 4")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            // Content
            Group {
                switch step {
                case 1: selectDirectoryStep
                case 2: selectReposStep
                case 3: confirmIdentityStep
                case 4: codingGoalStep
                default: EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // Footer navigation
            HStack {
                if step > 1 {
                    Button("Back") {
                        step -= 1
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()

                switch step {
                case 1:
                    Button("Next") {
                        scanRepos()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(rootDirectory.isEmpty || isScanning)

                case 2:
                    Button("Next") {
                        detectIdentity()
                        step = 3
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(scannedRepos.filter(\.isSelected).isEmpty)

                case 3:
                    Button("Next") {
                        step = 4
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(gitUserName.isEmpty || gitUserEmail.isEmpty)

                case 4:
                    Button("Finish") {
                        saveConfiguration()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(goalValue <= 0 || isSaving)

                default:
                    EmptyView()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Step 1: Select Directory

    private var selectDirectoryStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.gearshape")
                .font(.system(size: 40))
                .foregroundStyle(.blue)

            Text("Select Your Projects Folder")
                .font(.title3.bold())

            Text("Choose the root directory where your git repos live. Metrik will scan up to 3 levels deep.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)

            if rootDirectory.isEmpty {
                Button("Choose Folder...") {
                    chooseDirectory()
                }
                .buttonStyle(.borderedProminent)
            } else {
                HStack {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(.blue)
                    Text(rootDirectory)
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.head)

                    Button {
                        chooseDirectory()
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                    .buttonStyle(.borderless)
                }
                .padding(8)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
            }

            if isScanning {
                ProgressView("Scanning...")
                    .controlSize(.small)
            }
        }
        .padding(40)
    }

    // MARK: - Step 2: Select Repos

    private var selectReposStep: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Select Repositories to Track")
                    .font(.title3.bold())
                Spacer()
                Text("\(scannedRepos.filter(\.isSelected).count) selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            if scannedRepos.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "questionmark.folder")
                        .font(.system(size: 30))
                        .foregroundStyle(.secondary)
                    Text("No git repositories found")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .frame(maxHeight: .infinity)
            } else {
                List($scannedRepos) { $repo in
                    Toggle(isOn: $repo.isSelected) {
                        VStack(alignment: .leading) {
                            Text(repo.name)
                                .font(.body)
                            Text(repo.path)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Step 3: Confirm Identity

    private var confirmIdentityStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.text.rectangle")
                .font(.system(size: 40))
                .foregroundStyle(.green)

            Text("Confirm Your Identity")
                .font(.title3.bold())

            Text("Metrik uses this to filter commits authored by you.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Name")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    TextField("Your Name", text: $gitUserName)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Email")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    TextField("your@email.com", text: $gitUserEmail)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .frame(maxWidth: 280)

            if isSaving {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(40)
    }

    // MARK: - Step 4: Coding Goal

    private var codingGoalStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "target")
                .font(.system(size: 40))
                .foregroundStyle(.orange)

            Text("Your Coding Goal")
                .font(.title3.bold())

            Text("Set how many lines you aim to merge. The menu bar will show your progress.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Expected lines")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    TextField("500", value: $goalValue, format: .number)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Per")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Picker("", selection: $goalUnit) {
                        ForEach(GoalUnit.allCases, id: \.self) { unit in
                            Text(unit.label).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .frame(maxWidth: 280)

            if isSaving {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(40)
    }

    // MARK: - Actions

    private func chooseDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Select your projects root folder"

        if panel.runModal() == .OK, let url = panel.url {
            rootDirectory = url.path
        }
    }

    private func scanRepos() {
        isScanning = true
        _ = Task {
            let results = await appState.syncService.scanForRepos(rootDirectory: rootDirectory)
            scannedRepos = results.map { ScannedRepo(path: $0.path, name: $0.name, isSelected: true) }
            isScanning = false
            if !scannedRepos.isEmpty {
                step = 2
            }
        }
    }

    private func detectIdentity() {
        guard let firstRepo = scannedRepos.first(where: \.isSelected) else { return }
        _ = Task {
            if let identity = await appState.syncService.detectGitIdentity(repoPath: firstRepo.path) {
                gitUserName = identity.name
                gitUserEmail = identity.email
            }
        }
    }

    private func saveConfiguration() {
        isSaving = true
        _ = Task {
            // Save config
            let config = LocalGitConfig(
                rootDirectory: rootDirectory,
                gitUserName: gitUserName,
                gitUserEmail: gitUserEmail,
                isConfigured: true
            )
            modelContext.insert(config)

            // Save tracked repos
            for repo in scannedRepos where repo.isSelected {
                let defaultBranch = await appState.syncService.detectDefaultBranch(repoPath: repo.path)
                let tracked = TrackedRepo(
                    localPath: repo.path,
                    name: repo.name,
                    defaultBranch: defaultBranch,
                    isTracked: true
                )
                modelContext.insert(tracked)
            }

            // Ensure UserSettings exists and set coding goal
            let settingsDescriptor = FetchDescriptor<UserSettings>()
            let settings = try? modelContext.fetch(settingsDescriptor).first
            let userSettings: UserSettings
            if let settings {
                userSettings = settings
            } else {
                userSettings = UserSettings()
                modelContext.insert(userSettings)
            }
            userSettings.goalValue = goalValue
            userSettings.goalUnitRawValue = goalUnit.rawValue

            try? modelContext.save()

            appState.isConfigured = true
            isSaving = false

            // Trigger first sync
            await appState.syncService.sync(modelContext: modelContext)
            appState.refreshMetrics(modelContext: modelContext)
        }
    }
}
