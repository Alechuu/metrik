import SwiftUI

struct SettingsWindow: View {
    @Bindable var appState: AppState

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            RepoSelectionView(appState: appState)
                .tabItem {
                    Label("Repositories", systemImage: "folder")
                }

            AccountSettingsView(appState: appState)
                .tabItem {
                    Label("Account", systemImage: "person.circle")
                }

            DebugSettingsView(appState: appState)
                .tabItem {
                    Label("Debug", systemImage: "ladybug")
                }
        }
        .frame(width: 500, height: 450)
    }
}
