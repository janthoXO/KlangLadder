import KlangLadderCore
import SwiftUI

struct PopoverView: View {
    let engine: Engine
    @AppStorage("lastTab") private var scope: Scope = .output
    @State private var disabledExpanded: [Scope: Bool] = [:]

    private static let rowHeight: CGFloat = 28
    private static let maxListHeight: CGFloat = 12 * rowHeight

    var body: some View {
        let config = engine.config[scope]
        let connected = engine.connected[scope] ?? []
        let active = engine.active[scope]
        let all = config.priority + config.disabled
        let ambiguous = Set(Dictionary(grouping: all, by: \.displayName).filter { $0.value.count > 1 }.keys)
        let disabledOpen = disabledExpanded[scope] ?? config.isDisabled(active)
        // The popover sizes itself to the list, so the list needs an explicit height.
        let rows = config.priority.count + (config.disabled.isEmpty ? 0 : 1 + (disabledOpen ? config.disabled.count : 0))

        VStack(spacing: 8) {
            Picker("Scope", selection: $scope) {
                Text("Output").tag(Scope.output)
                Text("Input").tag(Scope.input)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .padding(.top, 12)

            List {
                ForEach(Array(config.priority.enumerated()), id: \.element.id) { index, entry in
                    DeviceRow(engine: engine, scope: scope, entry: entry, position: index + 1,
                              ambiguous: ambiguous.contains(entry.displayName),
                              isConnected: connected.contains(entry.uid), isActive: active == entry.uid)
                }
                .onMove { from, to in
                    engine.edit(scope) { $0.priority.move(fromOffsets: from, toOffset: to) }
                }

                // G11: open iff the active device is disabled, unless the user toggled it.
                if !config.disabled.isEmpty {
                    DisclosureGroup(isExpanded: Binding(
                        get: { disabledOpen },
                        set: { disabledExpanded[scope] = $0 }
                    )) {
                        ForEach(config.disabled) { entry in
                            DeviceRow(engine: engine, scope: scope, entry: entry, position: nil,
                                      ambiguous: ambiguous.contains(entry.displayName),
                                      isConnected: connected.contains(entry.uid), isActive: active == entry.uid)
                        }
                    } label: {
                        Text("Disabled (\(config.disabled.count))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .frame(height: min(CGFloat(rows) * Self.rowHeight, Self.maxListHeight))

            if let error = engine.lastError {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 12)
            }
        }
        .padding(.bottom, 8)
        .frame(width: 320)
        .onAppear { engine.lastError = nil }
    }
}

struct DeviceRow: View {
    let engine: Engine
    let scope: Scope
    let entry: DeviceEntry
    let position: Int?  // nil = in Disabled list
    let ambiguous: Bool
    let isConnected: Bool
    let isActive: Bool
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 8) {
            if let position {
                Text("\(position)")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
                    .frame(width: 12, alignment: .trailing)
            }

            Image(systemName: symbol)
                .font(.system(size: 11))
                .foregroundStyle(isActive ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
                .frame(width: 22, height: 22)
                .background(Circle().fill(isActive ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.quaternary)))

            Text(entry.displayName)
                .fontWeight(isActive ? .semibold : .regular)
                .lineLimit(1)

            Spacer(minLength: 8)

            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Menu { actions } label: { Image(systemName: "ellipsis") }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .opacity(hovering ? 1 : 0)
        }
        .padding(.horizontal, 6)
        .frame(height: 26)
        .opacity(isConnected ? 1 : 0.5)
        .contentShape(Rectangle())
        .background(RoundedRectangle(cornerRadius: 6).fill(hovering ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear)))
        .listRowInsets(EdgeInsets(top: 1, leading: 6, bottom: 1, trailing: 6))
        .listRowSeparator(.hidden)
        .help("\(isConnected ? "Connected" : "Disconnected") · \(entry.transport) · last seen \(entry.lastSeen.formatted(date: .abbreviated, time: .shortened)) · \(entry.uid)")
        .onHover { hovering = $0 }
        .onTapGesture { if isConnected { engine.makeActive(entry.uid, scope) } }
        .contextMenu { actions }
    }

    /// Only when two devices share a name (section 10). Disconnected shows as dimmed, like an unavailable menu item.
    private var subtitle: String? { ambiguous ? entry.transport : nil }

    private var symbol: String {
        switch entry.transport {
        case "Bluetooth": "headphones"
        case "HDMI", "DisplayPort": "display"
        case "AirPlay": "airplayaudio"
        case "Virtual", "Aggregate": "waveform"
        default: scope == .input ? "mic" : "hifispeaker"
        }
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
