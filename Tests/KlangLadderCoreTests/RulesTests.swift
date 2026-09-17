import Testing
@testable import KlangLadderCore

/// Builds a ScopeConfig from uid lists. Priority order = array order.
private func cfg(_ priority: [String], disabled: [String] = []) -> ScopeConfig {
    func entry(_ uid: String) -> DeviceEntry {
        DeviceEntry(uid: uid, displayName: uid, transport: "usb", model: nil, lastSeen: .distantPast)
    }
    return ScopeConfig(priority: priority.map(entry), disabled: disabled.map(entry))
}

// MARK: - Rules.target (design 6.4)

@Test func connectRanksAboveActive_switches() {
    let c = cfg(["a", "b"])
    let r = Rules.target(config: c, connected: ["b", "a"], added: ["a"], removed: [], previous: "b", current: "b")
    #expect(r == "a")
}

@Test func connectRanksBelowActive_autoSwitched_restoresPrevious() {
    let c = cfg(["a", "b"])
    let r = Rules.target(config: c, connected: ["a", "b"], added: ["b"], removed: [], previous: "a", current: "b")
    #expect(r == "a")
}

@Test func connectRanksBelowActive_noAutoSwitch_none() {
    let c = cfg(["a", "b"])
    let r = Rules.target(config: c, connected: ["a", "b"], added: ["b"], removed: [], previous: "a", current: "a")
    #expect(r == nil)
}

@Test func disabledDeviceConnects_noEnabledConnected_none() {
    let c = cfg([], disabled: ["d"])
    let r = Rules.target(config: c, connected: ["d"], added: ["d"], removed: [], previous: nil, current: "d")
    #expect(r == nil)
}

@Test func activeDisconnects_switchesToBest() {
    let c = cfg(["a", "b", "c"])
    let r = Rules.target(config: c, connected: ["b", "c"], added: [], removed: ["a"], previous: "a", current: "a")
    #expect(r == "b")
}

@Test func activeDisconnects_noEnabledLeft_none() {
    let c = cfg(["a"], disabled: ["d"])
    let r = Rules.target(config: c, connected: ["d"], added: [], removed: ["a"], previous: "a", current: "a")
    #expect(r == nil)
}

@Test func nonActiveDisconnects_none() {
    let c = cfg(["a", "b"])
    let r = Rules.target(config: c, connected: ["a"], added: [], removed: ["b"], previous: "a", current: "a")
    #expect(r == nil)
}

@Test func mixedBatch_activeDisconnectsAndAnotherConnects_switchesToBest() {
    let c = cfg(["a", "b", "c"])
    // a (active) disconnects, c connects; b already connected. Best of {b, c} is b.
    let r = Rules.target(config: c, connected: ["b", "c"], added: ["c"], removed: ["a"], previous: "a", current: "a")
    #expect(r == "b")
}

@Test func enabledConnectsWhileDisabledActive_switches() {
    let c = cfg(["a"], disabled: ["d"])
    let r = Rules.target(config: c, connected: ["d", "a"], added: ["a"], removed: [], previous: "d", current: "d")
    #expect(r == "a")
}

@Test func disabledDeviceAutoSwitched_restoresPrevious() {
    let c = cfg(["a"], disabled: ["d"])
    let r = Rules.target(config: c, connected: ["a", "d"], added: ["d"], removed: [], previous: "a", current: "d")
    #expect(r == "a")
}

// MARK: - best(among:) — used by startup (6.6, G20)

@Test func bestPicksHighestRankedEnabledConnectedDevice() {
    let c = cfg(["a", "b", "c"], disabled: ["z"])
    #expect(c.best(among: ["c", "b", "z"]) == "b")
    #expect(c.best(among: ["z"]) == nil)
}

// MARK: - ScopeConfig.register (G14, 5.3)

@Test func registerAppendsUnknownDeviceToBottom() {
    var c = cfg(["a", "b"])
    c.register([LiveDevice(uid: "new", name: "New", transport: "usb")])
    #expect(c.priority.map(\.uid) == ["a", "b", "new"])
}

@Test func registerFallback_exactlyOneDisconnectedLookAlike_adoptsUIDKeepingPosition() {
    var c = ScopeConfig(priority: [
        DeviceEntry(uid: "a", displayName: "A", transport: "usb", model: nil, lastSeen: .distantPast),
        DeviceEntry(uid: "old", displayName: "DAC", transport: "usb", model: "m1", lastSeen: .distantPast),
        DeviceEntry(uid: "c", displayName: "C", transport: "usb", model: nil, lastSeen: .distantPast),
    ])
    c.register([LiveDevice(uid: "new", name: "DAC", transport: "usb", model: "m1")])
    #expect(c.priority.map(\.uid) == ["a", "new", "c"])
}

@Test func registerFallback_twoLookAlikes_treatedAsNew() {
    var c = ScopeConfig(priority: [
        DeviceEntry(uid: "old1", displayName: "DAC", transport: "usb", model: "m1", lastSeen: .distantPast),
        DeviceEntry(uid: "old2", displayName: "DAC", transport: "usb", model: "m1", lastSeen: .distantPast),
    ])
    c.register([LiveDevice(uid: "new", name: "DAC", transport: "usb", model: "m1")])
    #expect(c.priority.map(\.uid) == ["old1", "old2", "new"])
}

@Test func registerFallback_connectedLookAlike_notACandidate() {
    var c = ScopeConfig(priority: [
        DeviceEntry(uid: "old", displayName: "DAC", transport: "usb", model: "m1", lastSeen: .distantPast),
    ])
    // "old" is connected in this same batch, so it must not be treated as a fallback candidate for "new".
    c.register([
        LiveDevice(uid: "old", name: "DAC", transport: "usb", model: "m1"),
        LiveDevice(uid: "new", name: "DAC", transport: "usb", model: "m1"),
    ])
    #expect(c.priority.map(\.uid) == ["old", "new"])
}

@Test func registerFallback_disabledEntryStaysDisabledAfterAdopting() {
    var c = ScopeConfig(disabled: [
        DeviceEntry(uid: "old", displayName: "DAC", transport: "usb", model: "m1", lastSeen: .distantPast),
    ])
    c.register([LiveDevice(uid: "new", name: "DAC", transport: "usb", model: "m1")])
    #expect(c.disabled.map(\.uid) == ["new"])
    #expect(c.priority.isEmpty)
}

// MARK: - ScopeConfig mutations (5.1, 5, moves)

@Test func deleteClosesGap() {
    var c = cfg(["a", "b", "c"])
    c.delete("b")
    #expect(c.priority.map(\.uid) == ["a", "c"])
}

@Test func enableAppendsToBottom() {
    var c = cfg(["a", "b"], disabled: ["d"])
    c.enable("d")
    #expect(c.priority.map(\.uid) == ["a", "b", "d"])
    #expect(c.disabled.isEmpty)
}

@Test func disableMovesToDisabled() {
    var c = cfg(["a", "b", "c"])
    c.disable("b")
    #expect(c.priority.map(\.uid) == ["a", "c"])
    #expect(c.disabled.map(\.uid) == ["b"])
}

@Test func moveToTopMovesEntryToFront() {
    var c = cfg(["a", "b", "c"])
    c.moveToTop("c")
    #expect(c.priority.map(\.uid) == ["c", "a", "b"])
}

@Test func moveToBottomMovesEntryToEnd() {
    var c = cfg(["a", "b", "c"])
    c.moveToBottom("a")
    #expect(c.priority.map(\.uid) == ["b", "c", "a"])
}
