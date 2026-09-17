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
        item.button?.action = #selector(togglePopover)
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

    @objc func togglePopover() {
        popover.isShown ? popover.performClose(nil) : showPopover()
    }

    func showPopover() {
        guard !popover.isShown, let button = statusItem?.button else { return }
        // Fresh view each time, so manual expand/collapse state resets (8.1).
        let host = NSHostingController(rootView: PopoverView(engine: engine))
        host.sizingOptions = []  // List reports no stable ideal size; let the fixed frame win
        popover.contentViewController = host
        popover.contentSize = NSSize(width: 320, height: 380)
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
