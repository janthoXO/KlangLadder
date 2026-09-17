import AppKit
import KlangLadderCore
import ServiceManagement
import SwiftUI

private let openNotification = Notification.Name("dev.klangladder.open")

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let engine = Engine()
    let popover = NSPopover()
    var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // G19: one instance. Hand over to the running copy and quit.
        if let id = Bundle.main.bundleIdentifier,
           NSRunningApplication.runningApplications(withBundleIdentifier: id).contains(where: { $0 != .current }) {
            DistributedNotificationCenter.default().postNotificationName(openNotification, object: nil, deliverImmediately: true)
            NSApp.terminate(nil)
            return
        }
        DistributedNotificationCenter.default().addObserver(forName: openNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.showPopover() }
        }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "hifispeaker.2", accessibilityDescription: "KlangLadder")
        item.button?.target = self
        item.button?.action = #selector(statusItemClicked)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem = item
        popover.behavior = .transient
        if CommandLine.arguments.contains("--register-login-item") {  // set by the Raycast installer (9.2)
            try? SMAppService.mainApp.register()
        }

        engine.start()
    }

    /// URL scheme (7.3). Untrusted input: only known commands, everything else ignored.
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme == "klangladder" && url.host == "open" {
            DispatchQueue.main.async { self.showPopover() }
        }
    }

    /// Left click: the device lists. Right click: settings (8.1).
    @objc func statusItemClicked() {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            showSettingsMenu()
        } else {
            popover.isShown ? popover.performClose(nil) : showPopover()
        }
    }

    private func showSettingsMenu() {
        popover.performClose(nil)
        let menu = NSMenu()
        let launch = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launch.target = self
        launch.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(launch)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit KlangLadder", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        // A menu set on the status item replaces the click action, so only attach it for this click.
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            engine.lastError = "Launch at login: \(error.localizedDescription)"
            showPopover()
        }
    }

    func showPopover() {
        guard !popover.isShown, let button = statusItem?.button else { return }
        // Fresh view each time, so manual expand/collapse state resets (8.1).
        let host = NSHostingController(rootView: PopoverView(engine: engine))
        // PopoverView gives the list an explicit height, so its ideal size is stable.
        host.sizingOptions = [.preferredContentSize]
        popover.contentViewController = host
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate()
    }
}

/// Runs the menu bar app. Never returns.
public func runApp() -> Never {
    MainActor.assumeIsolated {
        let delegate = AppDelegate()
        NSApplication.shared.delegate = delegate
        NSApplication.shared.setActivationPolicy(.accessory)
        NSApplication.shared.run()
    }
    exit(0)
}
