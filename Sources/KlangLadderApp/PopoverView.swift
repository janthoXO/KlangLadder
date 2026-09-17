import KlangLadderCore
import ServiceManagement
import SwiftUI

struct PopoverView: View {
    let engine: Engine
    @AppStorage("lastTab") private var scope: Scope = .output
    @State private var disabledExpanded: [Scope: Bool] = [:]
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        let config = engine.config[scope]
        let all = config.priority + config.disabled
        let ambiguous = Set(Dictionary(grouping: all, by: \.displayName).filter { $0.value.count > 1 }.keys)

        VStack(spacing: 8) {
            Picker("Scope", selection: $scope) {
                Text("Output").tag(Scope.output)
                Text("Input").tag(Scope.input)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            List {
                ForEach(Array(config.priority.enumerated()), id: \.element.id) { index, entry in
                    DeviceRow(engine: engine, scope: scope, entry: entry, position: index + 1, ambiguous: ambiguous.contains(entry.displayName))
                }
                .onMove { from, to in
                    engine.edit(scope) { $0.priority.move(fromOffsets: from, toOffset: to) }
                }

                // G11: open iff the active device is disabled, unless the user toggled it.
                DisclosureGroup("Disabled (\(config.disabled.count))", isExpanded: Binding(
                    get: { disabledExpanded[scope] ?? config.isDisabled(engine.active[scope]) },
                    set: { disabledExpanded[scope] = $0 }
                )) {
                    ForEach(config.disabled) { entry in
                        DeviceRow(engine: engine, scope: scope, entry: entry, position: nil, ambiguous: ambiguous.contains(entry.displayName))
                    }
                }
            }

            if let error = engine.lastError {
                Text(error).font(.caption).foregroundStyle(.red)
            }

            HStack {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        do {
                            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                        } catch {
                            engine.lastError = "Launch at login: \(error.localizedDescription)"
                        }
                    }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }
        }
        .padding(12)
        .frame(width: 380, height: 460)
        .onAppear { engine.lastError = nil }
    }
}

struct DeviceRow: View {
    let engine: Engine
    let scope: Scope
    let entry: DeviceEntry
    let position: Int?  // nil = in Disabled list
    let ambiguous: Bool
    @State private var hovering = false

    private var isConnected: Bool { engine.connected[scope]?.contains(entry.uid) ?? false }
    private var isActive: Bool { engine.active[scope] == entry.uid }

    var body: some View {
        HStack(spacing: 6) {
            if let position {
                Text("\(position).").monospacedDigit().foregroundStyle(.secondary)
            }
            Image(systemName: "checkmark").opacity(isActive ? 1 : 0)
            Text(ambiguous ? "\(entry.displayName) (\(entry.transport))" : entry.displayName)
                .fontWeight(isActive ? .semibold : .regular)
                .lineLimit(1)
            if !isConnected {
                Text("disconnected").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if hovering {
                if !isConnected {
                    Button { engine.delete(entry.uid, scope) } label: { Image(systemName: "trash") }
                        .buttonStyle(.borderless)
                        .help("Delete")
                }
                Menu { actions } label: { Image(systemName: "ellipsis.circle") }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
            }
        }
        .opacity(isConnected ? 1 : 0.5)
        .contentShape(Rectangle())
        .listRowBackground(isActive ? Color.accentColor.opacity(0.2) : Color.clear)
        .help("\(entry.transport) · last seen \(entry.lastSeen.formatted(date: .abbreviated, time: .shortened)) · \(entry.uid)")
        .onHover { hovering = $0 }
        .onTapGesture { if isConnected { engine.makeActive(entry.uid, scope) } }
        .contextMenu { actions }
    }

    @ViewBuilder private var actions: some View {
        let uid = entry.uid
        if position != nil {
            Button("Move to Top") { engine.edit(scope) { $0.moveToTop(uid) } }
            Button("Move to Bottom") { engine.edit(scope) { $0.moveToBottom(uid) } }
            Button("Disable") { engine.edit(scope) { $0.disable(uid) } }
        } else {
            Button("Enable") { engine.edit(scope) { $0.enable(uid) } }
        }
        if !isConnected {
            Button("Delete", role: .destructive) { engine.delete(uid, scope) }
        }
    }
}
