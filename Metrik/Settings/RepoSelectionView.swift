import SwiftUI
import SwiftData
import AppKit

struct RepoSelectionView: View {
    @Bindable var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TrackedRepo.localPath) private var repos: [TrackedRepo]
    @State private var searchText = ""
    @State private var isScanning = false
    @State private var scanError: String?

    private var filteredRepos: [TrackedRepo] {
        if searchText.isEmpty { return repos }
        return repos.filter { $0.name.localizedCaseInsensitiveContains(searchText) || $0.localPath.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Search repositories...", text: $searchText)
                    .textFieldStyle(.roundedBorder)

                Button {
                    rescanRepos()
                } label: {
                    if isScanning {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(isScanning)
            }
            .padding()

            if let error = scanError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
            }

            Divider()

            if repos.isEmpty {
                VStack(spacing: 12) {
                    Text("No repositories found")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Button("Scan for Repositories") {
                        rescanRepos()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxHeight: .infinity)
            } else {
                List(filteredRepos, id: \.localPath) { repo in
                    Toggle(isOn: Binding(
                        get: { repo.isTracked },
                        set: { newValue in
                            repo.isTracked = newValue
                            try? modelContext.save()
                            if newValue {
                                _ = Task {
                                    await appState.syncService.sync(modelContext: modelContext)
                                    appState.refreshMetrics(modelContext: modelContext)
                                }
                            }
                        }
                    )) {
                        VStack(alignment: .leading) {
                            Text(repo.name)
                                .font(.body)
                            Text(repo.localPath)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                }
            }

            Divider()

            HStack {
                Text("\(repos.filter(\.isTracked).count) tracked")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    addReposManually()
                } label: {
                    Label("Add Repositories", systemImage: "plus")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
        .onAppear {
            if repos.isEmpty {
                rescanRepos()
            }
        }
    }

    private func addReposManually() {
        let panel = NSOpenPanel()
        panel.title = "Select Git Repositories"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.message = "Select one or more folders that contain a .git directory."

        guard panel.runModal() == .OK else { return }

        _ = Task {
            for url in panel.urls {
                let path = url.path
                let gitDir = url.appendingPathComponent(".git")
                guard FileManager.default.fileExists(atPath: gitDir.path) else { continue }

                let existingDescriptor = FetchDescriptor<TrackedRepo>(
                    predicate: #Predicate { $0.localPath == path }
                )
                let existing = try? modelContext.fetch(existingDescriptor)
                guard existing?.isEmpty ?? true else { continue }

                let defaultBranch = await appState.syncService.detectDefaultBranch(repoPath: path)
                let repo = TrackedRepo(
                    localPath: path,
                    name: url.lastPathComponent,
                    defaultBranch: defaultBranch,
                    isTracked: true
                )
                modelContext.insert(repo)
            }

            try? modelContext.save()
            await appState.syncService.sync(modelContext: modelContext)
            appState.refreshMetrics(modelContext: modelContext)
        }
    }

    private func rescanRepos() {
        isScanning = true
        scanError = nil
        _ = Task {
            do {
                let configDescriptor = FetchDescriptor<LocalGitConfig>()
                guard let config = try modelContext.fetch(configDescriptor).first else {
                    scanError = "No configuration found. Run setup first."
                    isScanning = false
                    return
                }

                let results = await appState.syncService.scanForRepos(rootDirectory: config.rootDirectory)

                for result in results {
                    let path = result.path
                    let existingDescriptor = FetchDescriptor<TrackedRepo>(
                        predicate: #Predicate { $0.localPath == path }
                    )
                    let existing = try modelContext.fetch(existingDescriptor)

                    if existing.isEmpty {
                        let defaultBranch = await appState.syncService.detectDefaultBranch(repoPath: result.path)
                        let repo = TrackedRepo(
                            localPath: result.path,
                            name: result.name,
                            defaultBranch: defaultBranch
                        )
                        modelContext.insert(repo)
                    }
                }

                try modelContext.save()
            } catch {
                scanError = error.localizedDescription
            }
            isScanning = false
        }
    }
}
