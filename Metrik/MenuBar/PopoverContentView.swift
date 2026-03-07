import SwiftUI
import SwiftData

struct PopoverContentView: View {
    @Bindable var appState: AppState
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        if appState.isConfigured {
            DashboardView(appState: appState)
        } else {
            SetupWizardView(appState: appState)
        }
    }

    func onAppearCheck() {
        appState.checkConfiguration(modelContext: modelContext)
    }
}
