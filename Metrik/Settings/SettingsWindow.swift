import SwiftUI

struct SettingsWindow: View {
    @Bindable var appState: AppState

    var body: some View {
        Group {
            if #available(macOS 26, *) {
                ZStack {
                    tabViewContent
                }
                .padding(12)
                .glassEffectIfAvailable(cornerRadius: 24)
            } else {
                tabViewContent
            }
        }
        .frame(width: 500, height: 450)
    }

    private var tabViewContent: some View {
        TabView {
            GeneralSettingsView(appState: appState)
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
