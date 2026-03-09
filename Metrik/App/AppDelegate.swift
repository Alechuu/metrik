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

            let hostingController = NSHostingController(rootView: activityView)

            let window = NSWindow(contentViewController: hostingController)
            window.title = "Activity"
            window.setContentSize(NSSize(width: 700, height: 600))
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.minSize = NSSize(width: 500, height: 400)
            window.level = .floating
            window.center()
            activityWindow = window
        }

        activityWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func presentSettingsWindow() {
        let settingsView = SettingsWindow(appState: appState)
            .modelContainer(PersistenceController.sharedModelContainer)

        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 450),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Metrik Settings"
            window.level = .floating
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }

        if settingsWindow?.contentViewController == nil || settingsWindow?.isVisible == false {
            settingsWindow?.contentViewController = NSHostingController(rootView: settingsView)
        }

        settingsWindow?.setContentSize(NSSize(width: 500, height: 450))
        settingsWindow?.contentView?.layoutSubtreeIfNeeded()
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
