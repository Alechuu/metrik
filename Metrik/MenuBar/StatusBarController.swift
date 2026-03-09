import AppKit
import SwiftUI
import SwiftData

extension Notification.Name {
    static let openSettings = Notification.Name("com.metrik.openSettings")
    static let openActivityDetail = Notification.Name("com.metrik.openActivityDetail")
    static let metricsDidUpdate = Notification.Name("com.metrik.metricsDidUpdate")
    /// Re-show the menu bar popover (e.g. after a file panel closes so the user sees the setup wizard again).
    static let showPopover = Notification.Name("com.metrik.showPopover")
}

final class StatusBarController {
    private static let iconSize: CGFloat = 18
    private static let ringLineWidth: CGFloat = 2

    private var statusItem: NSStatusItem
    private var popover: NSPopover
    private let appState: AppState
    private var globalMonitor: Any?
    private var localMonitor: Any?

    init(appState: AppState) {
        self.appState = appState

        statusItem = NSStatusBar.system.statusItem(withLength: Self.iconSize + 4)
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
            button.action = #selector(togglePopover(_:))
            button.target = self
        }

        updateStatusIcon()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMetricsDidUpdate),
            name: .metricsDidUpdate,
            object: nil
        )
    }

    @objc private func handleMetricsDidUpdate() {
        DispatchQueue.main.async { [weak self] in
            self?.updateStatusIcon()
        }
    }

    private func updateStatusIcon() {
        let weekday = Calendar.current.component(.weekday, from: Date())
        let isWorkDay = appState.workingDays.contains(weekday)
        let progress = isWorkDay ? appState.dayProgress : appState.weekProgress

        guard let button = statusItem.button else { return }
        button.image = Self.makeRingImage(progress: progress)
    }

    private static func makeRingImage(progress: Double) -> NSImage {
        let size = iconSize
        let lineWidth = ringLineWidth
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()

        let center = NSPoint(x: size / 2, y: size / 2)
        let radius = (size - lineWidth) / 2

        let trackPath = NSBezierPath()
        trackPath.appendArc(
            withCenter: center, radius: radius,
            startAngle: 0, endAngle: 360
        )
        trackPath.lineWidth = lineWidth
        NSColor.tertiaryLabelColor.setStroke()
        trackPath.stroke()

        let clamped = min(max(progress, 0), 1.0)
        if clamped > 0 {
            let startAngle: CGFloat = 90
            let endAngle = startAngle - CGFloat(clamped) * 360
            let progressPath = NSBezierPath()
            progressPath.appendArc(
                withCenter: center, radius: radius,
                startAngle: startAngle, endAngle: endAngle, clockwise: true
            )
            progressPath.lineWidth = lineWidth
            progressPath.lineCapStyle = .round
            NSColor.labelColor.setStroke()
            progressPath.stroke()
        }

        let letterFont = NSFont.systemFont(ofSize: 9, weight: .bold)
        let letterAttr = NSAttributedString(
            string: "M",
            attributes: [.font: letterFont, .foregroundColor: NSColor.labelColor]
        )
        let letterSize = letterAttr.size()
        letterAttr.draw(at: NSPoint(
            x: center.x - letterSize.width / 2,
            y: center.y - letterSize.height / 2
        ))

        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    func showPopover() {
        guard !popover.isShown, let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        NSApp.activate(ignoringOtherApps: true)
        addMonitors()
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
