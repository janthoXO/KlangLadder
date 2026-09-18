import Foundation

public enum Scope: String, Codable, CaseIterable, Sendable {
    case output, input
}

/// A device as currently reported by Core Audio.
public struct LiveDevice: Equatable, Sendable {
    public var uid: String
    public var name: String
    public var transport: String
    public var model: String?

    public init(uid: String, name: String, transport: String, model: String? = nil) {
        self.uid = uid
        self.name = name
        self.transport = transport
        self.model = model
    }
}

public struct DeviceEntry: Codable, Equatable, Identifiable, Sendable {
    public var uid: String
    public var displayName: String
    public var transport: String
    public var model: String?
    public var lastSeen: Date

    public var id: String { uid }
}

/// One scope's lists. Position = array index (5.1), a device is in exactly one of the two lists.
public struct ScopeConfig: Codable, Equatable, Sendable {
    public var priority: [DeviceEntry] = []
    public var disabled: [DeviceEntry] = []

    public init(priority: [DeviceEntry] = [], disabled: [DeviceEntry] = []) {
        self.priority = priority
        self.disabled = disabled
    }

    /// nil = disabled or unknown, i.e. rank −∞.
    public func rank(_ uid: String?) -> Int? {
        priority.firstIndex { $0.uid == uid }
    }

    public func isDisabled(_ uid: String?) -> Bool {
        disabled.contains { $0.uid == uid }
    }

    /// Highest-ranked enabled device among `uids`.
    public func best(among uids: Set<String>) -> String? {
        priority.first { uids.contains($0.uid) }?.uid
    }

    func outranks(_ a: String, _ b: String?) -> Bool {
        guard let ra = rank(a) else { return false }
        guard let rb = rank(b) else { return true }
        return ra < rb
    }

    /// Adds unknown devices at the bottom (G14), or lets a disconnected look-alike adopt a changed UID (5.3).
    /// Refreshes name, transport, model and lastSeen of every connected device.
    public mutating func register(_ live: [LiveDevice], now: Date = Date()) {
        let connected = Set(live.map(\.uid))
        for d in live {
            if rank(d.uid) == nil && !isDisabled(d.uid) {
                let matches = (priority + disabled).filter {
                    !connected.contains($0.uid) && $0.displayName == d.name && $0.transport == d.transport && $0.model == d.model
                }
                if matches.count == 1 {
                    let old = matches[0].uid
                    modify(old) { $0.uid = d.uid }
                } else {
                    priority.append(DeviceEntry(uid: d.uid, displayName: d.name, transport: d.transport, model: d.model, lastSeen: now))
                }
            }
            modify(d.uid) {
                $0.displayName = d.name
                $0.transport = d.transport
                $0.model = d.model
                $0.lastSeen = now
            }
        }
    }

    private mutating func modify(_ uid: String, _ change: (inout DeviceEntry) -> Void) {
        if let i = priority.firstIndex(where: { $0.uid == uid }) { change(&priority[i]) }
        if let i = disabled.firstIndex(where: { $0.uid == uid }) { change(&disabled[i]) }
    }

    /// Moves a priority entry to `index`, clamped to the list. Used by Move Up/Down and drag and drop.
    public mutating func move(_ uid: String, to index: Int) {
        guard let i = rank(uid) else { return }
        let entry = priority.remove(at: i)
        priority.insert(entry, at: min(max(index, 0), priority.count))
    }

    public mutating func disable(_ uid: String) {
        guard let i = rank(uid) else { return }
        disabled.append(priority.remove(at: i))
    }

    public mutating func enable(_ uid: String) {
        guard let i = disabled.firstIndex(where: { $0.uid == uid }) else { return }
        priority.append(disabled.remove(at: i))
    }

    /// Caller must ensure the device is disconnected (5.1).
    public mutating func delete(_ uid: String) {
        priority.removeAll { $0.uid == uid }
        disabled.removeAll { $0.uid == uid }
    }
}

public struct Config: Codable, Equatable, Sendable {
    public var version = 1
    public var output = ScopeConfig()
    public var input = ScopeConfig()

    public init() {}

    public subscript(scope: Scope) -> ScopeConfig {
        get { scope == .output ? output : input }
        set { if scope == .output { output = newValue } else { input = newValue } }
    }
}

public enum Rules {
    /// The device that should be default after a device-list change, or nil to leave the current default (6.0–6.2).
    /// `previous` is the default before the event, ignoring any macOS auto-switch (4.4).
    public static func target(
        config: ScopeConfig,
        connected: Set<String>,
        added: Set<String>,
        removed: Set<String>,
        previous: String?,
        current: String?
    ) -> String? {
        guard let best = config.best(among: connected) else { return nil }  // 6.0 guard: macOS decides
        if let previous, removed.contains(previous) { return best }        // 6.2, also covers mixed batches (10)
        if let x = config.best(among: added), config.outranks(x, previous) { return x }  // 6.1 G4
        if let current, let previous, current != previous, added.contains(current), connected.contains(previous) {
            return previous  // 6.1: undo macOS auto-switch to a lower-ranked device
        }
        return nil
    }
}
