import AppKit
import CryptoKit
import KlangLadderApp
import RaycastSwiftMacros

/// Installs or updates the bundled app if needed (9.2), then opens its popover.
@raycast func openKlangLadder() async throws {
    let fileManager = FileManager.default
    let home = fileManager.homeDirectoryForCurrentUser
    let ours = home.appending(path: "Applications/KlangLadder.app")
    let marker = home.appending(path: "Library/Application Support/KlangLadder/raycast-installed")
    let installedByUs = fileManager.fileExists(atPath: marker.path)
    let isOurs = { (url: URL) in installedByUs && url.standardizedFileURL.path == ours.standardizedFileURL.path }

    var app = ours
    var fresh = false
    if let standalone = NSWorkspace.shared.urlsForApplications(withBundleIdentifier: AppBundle.identifier).first(where: { !isOurs($0) })
        ?? (!installedByUs && fileManager.fileExists(atPath: ours.path) ? ours : nil) {
        app = standalone  // never touch a standalone install
    } else if let bundled = Bundle.main.executableURL,
              // codesign rewrites the installed binary, so compare against the hash recorded at install time.
              case let build = SHA256.hash(data: try Data(contentsOf: bundled)).description,
              !fileManager.fileExists(atPath: ours.path) || (try? String(contentsOf: marker, encoding: .utf8)) != build {
        fresh = !fileManager.fileExists(atPath: ours.path)
        await quitRunningCopies()
        try fileManager.createDirectory(at: ours.deletingLastPathComponent(), withIntermediateDirectories: true)
        try AppBundle.assemble(at: ours, executable: bundled)
        try fileManager.createDirectory(at: marker.deletingLastPathComponent(), withIntermediateDirectories: true)
        try build.write(to: marker, atomically: true, encoding: .utf8)
    }

    let configuration = NSWorkspace.OpenConfiguration()
    if fresh { configuration.arguments = ["--register-login-item"] }
    try await NSWorkspace.shared.open([URL(string: "klangladder://open")!], withApplicationAt: app, configuration: configuration)
}

private func quitRunningCopies() async {
    let pids = NSRunningApplication.runningApplications(withBundleIdentifier: AppBundle.identifier).map { app in
        app.terminate()
        return app.processIdentifier
    }
    // Poll the process table; NSRunningApplication only updates on a running main run loop.
    for _ in 0..<50 where pids.contains(where: { kill($0, 0) == 0 }) {
        try? await Task.sleep(for: .milliseconds(100))
    }
}
