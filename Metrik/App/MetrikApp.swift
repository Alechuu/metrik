import SwiftUI
import SwiftData

@main
struct MetrikApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Settings window is managed by AppDelegate via NSWindow.
        // This empty Settings scene satisfies SwiftUI's requirement for at least one scene.
        Settings {
            EmptyView()
        }
    }
}
