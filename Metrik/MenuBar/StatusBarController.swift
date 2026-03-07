import AppKit
import SwiftUI
import SwiftData

extension Notification.Name {
    static let openSettings = Notification.Name("com.metrik.openSettings")
    static let openActivityDetail = Notification.Name("com.metrik.openActivityDetail")
}

final class StatusBarController {
    private var statusItem: NSStatusItem
    private var popover: NSPopover
    private let appState: AppState
    private var globalMonitor: Any?
    private var localMonitor: Any?

    init(appState: AppState) {
        self.appState = appState

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.autosaveName = "MetrikStatusItem"
        statusItem.isVisible = true

        popover = NSPopover()
        popover.contentSize = NSSize(width: 360, height: 520)
        popover.behavior = .transient
        popover.animates = true

        let contentView = PopoverContentView(appState: appState)
            .modelContainer(PersistenceController.sharedModelContainer)
            .frame(width: 360, height: 520)

        popover.contentViewController = NSHostingController(rootView: contentView)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "chart.line.uptrend.xyaxis", accessibilityDescription: "Metrik")
            button.image?.size = NSSize(width: 18, height: 18)
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
    }

    func closePopover() {
        popover.performClose(nil)
        removeMonitors()
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        if popover.isShown {
            closePopover()
        } else if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
            addMonitors()
        }
    }

    private func addMonitors() {
        // Clicks outside the app (other apps, desktop, etc.)
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePopover()
        }

        // Clicks inside the app but outside the popover (e.g. on the status item again)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if let self, self.popover.isShown,
               event.window != self.popover.contentViewController?.view.window {
                self.closePopover()
            }
            return event
        }
    }

    private func removeMonitors() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
    }
}
