import Foundation
import Observation

@MainActor @Observable
public final class Engine {
    public private(set) var config: Config
    public private(set) var connected: [Scope: Set<String>] = [:]
    /// Recorded default per scope. Excludes macOS auto-switches still under evaluation (4.4).
    public private(set) var active: [Scope: String] = [:]
    public var lastError: String?

    // Calibration knobs (4.4, 10).
    @ObservationIgnored public var debounceDelay: TimeInterval = 0.4
    @ObservationIgnored public var autoSwitchWindow: TimeInterval = 2

    @ObservationIgnored private let audio = CoreAudio()
    @ObservationIgnored private var pendingEvaluation: DispatchWorkItem?
    @ObservationIgnored private var recentConnect: [Scope: (at: Date, added: Set<String>, previous: String?)] = [:]

    public init() {
        config = ConfigStore.load()
    }

    public func start() {
        let firstStartThisSession = LoginSession.claim()
        for scope in Scope.allCases {
            let current = audio.defaultUID(scope)
            var devices = audio.devices(scope)
            if config[scope] == ScopeConfig() {
                // Very first run: seed the current default at #1 so we don't switch to an arbitrary device.
                devices.sort { $0.uid == current && $1.uid != current }
            }
            config[scope].register(devices)
            connected[scope] = Set(devices.map(\.uid))
            // 6.6 / G20
            apply(firstStartThisSession ? config[scope].best(among: connected[scope]!) : nil, current: current, scope)
        }
        save()
        audio.listen(
            devicesChanged: { [weak self] in MainActor.assumeIsolated { self?.scheduleEvaluation() } },
            defaultChanged: { [weak self] scope in MainActor.assumeIsolated { self?.defaultChanged(scope) } }
        )
    }

    // MARK: Events

    private func scheduleEvaluation() {
        pendingEvaluation?.cancel()
        let work = DispatchWorkItem { [weak self] in MainActor.assumeIsolated { self?.evaluate() } }
        pendingEvaluation = work
        DispatchQueue.main.asyncAfter(deadline: .now() + debounceDelay, execute: work)
    }

    private func evaluate() {
        pendingEvaluation = nil
        for scope in Scope.allCases {
            let devices = audio.devices(scope)
            config[scope].register(devices)
            let before = connected[scope] ?? []
            let now = Set(devices.map(\.uid))
            let added = now.subtracting(before)
            let removed = before.subtracting(now)
            connected[scope] = now
            let current = audio.defaultUID(scope)
            let previous = active[scope]

            let target = Rules.target(config: config[scope], connected: now, added: added, removed: removed, previous: previous, current: current)
            apply(target, current: current, scope)
            if !added.isEmpty { recentConnect[scope] = (Date(), added, previous) }
        }
        save()
    }

    private func defaultChanged(_ scope: Scope) {
        guard pendingEvaluation == nil else { return }  // evaluate() reads the default itself
        let current = audio.defaultUID(scope)
        guard current != active[scope] else { return }   // our own switch, or no change

        // macOS auto-switch that arrived after the device-list evaluation (4.4)
        if let recent = recentConnect[scope], let current, recent.added.contains(current),
           Date().timeIntervalSince(recent.at) < autoSwitchWindow {
            let target = Rules.target(config: config[scope], connected: connected[scope] ?? [], added: recent.added,
                                      removed: [], previous: recent.previous, current: current)
            apply(target, current: current, scope)
            return
        }
        active[scope] = current  // manual choice, respected (G6)
    }

    private func apply(_ target: String?, current: String?, _ scope: Scope) {
        if let target, target != current, !audio.setDefault(target, scope) {
            active[scope] = current
            return
        }
        active[scope] = target ?? current
    }

    // MARK: User actions (never switch on their own, 6.0)

    public func edit(_ scope: Scope, _ change: (inout ScopeConfig) -> Void) {
        change(&config[scope])
        save()
    }

    public func makeActive(_ uid: String, _ scope: Scope) {
        if audio.setDefault(uid, scope) { active[scope] = uid }
    }

    public func delete(_ uid: String, _ scope: Scope) {
        // Re-check against Core Audio, the UI may be stale (5.1 race).
        if audio.devices(scope).contains(where: { $0.uid == uid }) {
            lastError = "Can't delete a connected device."
            return
        }
        edit(scope) { $0.delete(uid) }
    }

    private func save() {
        do { try ConfigStore.save(config) } catch { lastError = "Couldn't save config: \(error.localizedDescription)" }
    }
}

enum ConfigStore {
    static let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("KlangLadder", isDirectory: true)
    static let file = directory.appendingPathComponent("config.json")

    static func load() -> Config {
        guard let data = try? Data(contentsOf: file) else { return Config() }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let config = try? decoder.decode(Config.self, from: data), config.version <= 1 { return config }
        // Unreadable or from a newer version: keep it aside instead of overwriting it.
        let backup = directory.appendingPathComponent("config.unreadable-\(Int(Date().timeIntervalSince1970)).json")
        try? FileManager.default.moveItem(at: file, to: backup)
        return Config()
    }

    static func save(_ config: Config) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(config).write(to: file, options: .atomic)
    }
}

enum LoginSession {
    /// ponytail: boot time + audit session ID, unverified across logout/login (S7). Swap source here if it misfires.
    static var current: String {
        var boot = timeval()
        var size = MemoryLayout<timeval>.size
        var mib = [CTL_KERN, KERN_BOOTTIME]
        sysctl(&mib, 2, &boot, &size, nil, 0)
        var info = auditinfo_addr()
        getaudit_addr(&info, Int32(MemoryLayout<auditinfo_addr>.size))
        return "\(boot.tv_sec)-\(info.ai_asid)"
    }

    /// True on the first call in this login session.
    static func claim() -> Bool {
        let marker = ConfigStore.directory.appendingPathComponent("session")
        let id = current
        if (try? String(contentsOf: marker, encoding: .utf8)) == id { return false }
        try? FileManager.default.createDirectory(at: ConfigStore.directory, withIntermediateDirectories: true)
        try? id.write(to: marker, atomically: true, encoding: .utf8)
        return true
    }
}
