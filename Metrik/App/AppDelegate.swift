import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    let appState = AppState()
    private var statusBarController: StatusBarController?
    private var settingsWindow: NSWindow?
    private var activityWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBarController = StatusBarController(appState: appState)

        let context = PersistenceController.sharedModelContainer.mainContext
        appState.checkConfiguration(modelContext: context)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenSettings),
            name: .openSettings,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenActivityDetail),
            name: .openActivityDetail,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleShowPopover),
            name: .showPopover,
            object: nil
        )
    }

    @objc private func handleShowPopover() {
        NSApp.activate(ignoringOtherApps: true)
        statusBarController?.showPopover()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        statusBarController?.showPopover()
        return false
    }

    @objc private func handleOpenSettings() {
        statusBarController?.closePopover()
        DispatchQueue.main.async { [weak self] in
            self?.presentSettingsWindow()
        }
    }

    @objc private func handleOpenActivityDetail() {
        statusBarController?.closePopover()

        if activityWindow == nil {
            let activityView = ActivityDetailView(appState: appState)
                .modelContainer(PersistenceController.sharedModelContainer)

            let hostingView = NSHostingView(rootView: activityView)

            let targetWidth: CGFloat = 700
            let fittingSize = hostingView.fittingSize
            let contentHeight = max(fittingSize.height, 400)

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: targetWidth, height: contentHeight),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Activity"
            window.minSize = NSSize(width: 500, height: 400)
            window.titlebarAppearsTransparent = true

            // Translucent blur background — same look as the menu popover
            let visualEffect = NSVisualEffectView()
            visualEffect.material = .popover
            visualEffect.blendingMode = .behindWindow
            visualEffect.state = .active
            visualEffect.autoresizingMask = [.width, .height]

            hostingView.autoresizingMask = [.width, .height]
            hostingView.frame = visualEffect.bounds

            visualEffect.addSubview(hostingView)
            window.contentView = visualEffect

            window.isReleasedWhenClosed = false
            window.center()
            activityWindow = window

            NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                self?.activityWindow = nil
            }
        }

        activityWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func presentSettingsWindow() {
        if settingsWindow == nil {
            let settingsView = SettingsWindow(appState: appState)
                .modelContainer(PersistenceController.sharedModelContainer)

            let hostingView = NSHostingView(rootView: settingsView)

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 680, height: 660),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Metrik Settings"
            window.titlebarAppearsTransparent = true
            window.isReleasedWhenClosed = false

            let visualEffect = NSVisualEffectView()
            visualEffect.material = .popover
            visualEffect.blendingMode = .behindWindow
            visualEffect.state = .active
            visualEffect.autoresizingMask = [.width, .height]

            hostingView.autoresizingMask = [.width, .height]
            hostingView.frame = visualEffect.bounds

            visualEffect.addSubview(hostingView)
            window.contentView = visualEffect

            window.center()
            settingsWindow = window

            NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                self?.settingsWindow = nil
            }
        }

        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
