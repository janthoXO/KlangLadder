import CoreAudio
import Foundation

/// Thin adapter over the Core Audio HAL (4.2).
struct CoreAudio {
    private let system = AudioObjectID(kAudioObjectSystemObject)

    private func address(_ selector: AudioObjectPropertySelector, _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    private func uint32(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector, _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> UInt32? {
        var addr = address(selector, scope)
        var result: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        return AudioObjectGetPropertyData(object, &addr, 0, nil, &size, &result) == noErr ? result : nil
    }

    private func string(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector) -> String? {
        var addr = address(selector)
        var result: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(object, &addr, 0, nil, &size, &result) == noErr else { return nil }
        return result?.takeRetainedValue() as String?
    }

    private func deviceIDs() -> [AudioObjectID] {
        var addr = address(kAudioHardwarePropertyDevices)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &addr, 0, nil, &size) == noErr else { return [] }
        var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(system, &addr, 0, nil, &size, &ids) == noErr else { return [] }
        return ids
    }

    private func caScope(_ scope: Scope) -> AudioObjectPropertyScope {
        scope == .output ? kAudioObjectPropertyScopeOutput : kAudioObjectPropertyScopeInput
    }

    private func defaultSelector(_ scope: Scope) -> AudioObjectPropertySelector {
        scope == .output ? kAudioHardwarePropertyDefaultOutputDevice : kAudioHardwarePropertyDefaultInputDevice
    }

    /// Devices that have streams in `scope` and may become its default.
    func devices(_ scope: Scope) -> [LiveDevice] {
        deviceIDs().compactMap { id in
            var streams = address(kAudioDevicePropertyStreams, caScope(scope))
            var size: UInt32 = 0
            guard AudioObjectGetPropertyDataSize(id, &streams, 0, nil, &size) == noErr, size > 0,
                  uint32(id, kAudioDevicePropertyDeviceCanBeDefaultDevice, caScope(scope)) == 1,
                  let uid = string(id, kAudioDevicePropertyDeviceUID)
            else { return nil }
            return LiveDevice(
                uid: uid,
                name: string(id, kAudioObjectPropertyName) ?? uid,
                transport: transportName(uint32(id, kAudioDevicePropertyTransportType) ?? 0),
                model: string(id, kAudioDevicePropertyModelUID)
            )
        }
    }

    func defaultUID(_ scope: Scope) -> String? {
        guard let id = uint32(system, defaultSelector(scope)), id != 0 else { return nil }
        return string(id, kAudioDevicePropertyDeviceUID)
    }

    @discardableResult
    func setDefault(_ uid: String, _ scope: Scope) -> Bool {
        guard var id = deviceIDs().first(where: { string($0, kAudioDevicePropertyDeviceUID) == uid }) else { return false }
        var addr = address(defaultSelector(scope))
        return AudioObjectSetPropertyData(system, &addr, 0, nil, UInt32(MemoryLayout<AudioObjectID>.size), &id) == noErr
    }

    /// Callbacks run on the main queue.
    func listen(devicesChanged: @escaping () -> Void, defaultChanged: @escaping (Scope) -> Void) {
        var addr = address(kAudioHardwarePropertyDevices)
        AudioObjectAddPropertyListenerBlock(system, &addr, .main) { _, _ in devicesChanged() }
        for scope in Scope.allCases {
            var addr = address(defaultSelector(scope))
            AudioObjectAddPropertyListenerBlock(system, &addr, .main) { _, _ in defaultChanged(scope) }
        }
    }

    private func transportName(_ type: UInt32) -> String {
        switch type {
        case kAudioDeviceTransportTypeBuiltIn: "Built-in"
        case kAudioDeviceTransportTypeUSB: "USB"
        case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE: "Bluetooth"
        case kAudioDeviceTransportTypeHDMI: "HDMI"
        case kAudioDeviceTransportTypeDisplayPort: "DisplayPort"
        case kAudioDeviceTransportTypeAirPlay: "AirPlay"
        case kAudioDeviceTransportTypeThunderbolt: "Thunderbolt"
        case kAudioDeviceTransportTypeVirtual: "Virtual"
        case kAudioDeviceTransportTypeAggregate, kAudioDeviceTransportTypeAutoAggregate: "Aggregate"
        default: "Other"
        }
    }
}
