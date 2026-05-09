import CoreMIDI
import Darwin
import Foundation

public final class MIDIInputRecorder {
    private var client = MIDIClientRef()
    private var inputPort = MIDIPortRef()
    private var connectedSource: MIDIEndpointRef?
    private var activeBuilder: MIDIInputRecordingBuilder?
    private let lock = NSLock()

    public init() throws {
        var client = MIDIClientRef()
        var status = MIDIClientCreate("MIDIInputKit" as CFString, nil, nil, &client)
        guard status == noErr else {
            throw MIDIInputError.coreMIDIStatus(operation: "client create", status: Int32(status))
        }

        var inputPort = MIDIPortRef()
        status = MIDIInputPortCreate(
            client,
            "MIDIInputKit Input" as CFString,
            midiInputReadProc,
            Unmanaged.passUnretained(self).toOpaque(),
            &inputPort
        )
        guard status == noErr else {
            MIDIClientDispose(client)
            throw MIDIInputError.coreMIDIStatus(operation: "input port create", status: Int32(status))
        }

        self.client = client
        self.inputPort = inputPort
    }

    deinit {
        disconnect()
        if inputPort != 0 {
            MIDIPortDispose(inputPort)
        }
        if client != 0 {
            MIDIClientDispose(client)
        }
    }

    public func availableDevices() -> [MIDIInputDevice] {
        (0..<MIDIGetNumberOfSources()).compactMap { index in
            let endpoint = MIDIGetSource(index)
            guard endpoint != 0 else { return nil }
            return Self.device(for: endpoint)
        }
    }

    public func connect(to device: MIDIInputDevice) throws {
        guard let endpoint = Self.endpoint(for: device.id) else {
            throw MIDIInputError.deviceNotFound(device.id)
        }

        disconnect()
        let status = MIDIPortConnectSource(inputPort, endpoint, nil)
        guard status == noErr else {
            throw MIDIInputError.coreMIDIStatus(operation: "connect source", status: Int32(status))
        }
        connectedSource = endpoint
    }

    public func disconnect() {
        if let connectedSource {
            MIDIPortDisconnectSource(inputPort, connectedSource)
        }
        connectedSource = nil
    }

    public func startRecording(options: MIDIInputRecordingOptions) throws {
        try MIDIInputRecordingBuilder.validate(options)
        guard connectedSource != nil else {
            throw MIDIInputError.noDeviceConnected
        }

        lock.lock()
        activeBuilder = try MIDIInputRecordingBuilder(options: options)
        lock.unlock()
    }

    public func stopRecording() throws -> MIDIInputRecording {
        lock.lock()
        defer { lock.unlock() }

        guard let activeBuilder else {
            throw MIDIInputError.notRecording
        }
        self.activeBuilder = nil
        return activeBuilder.finish()
    }

    func receive(packetList: UnsafePointer<MIDIPacketList>) {
        var packet = packetList.pointee.packet
        for _ in 0..<packetList.pointee.numPackets {
            let timestampSeconds = Self.hostTimeSeconds(packet.timeStamp)
            let bytes = Self.bytes(from: packet)
            receive(bytes: bytes, timestampSeconds: timestampSeconds)
            packet = MIDIPacketNext(&packet).pointee
        }
    }

    private func receive(bytes: [UInt8], timestampSeconds: Double) {
        var index = 0
        while index < bytes.count {
            let status = bytes[index]
            guard status >= 0x80 else {
                index += 1
                continue
            }

            switch status & 0xF0 {
            case 0x80, 0x90:
                guard index + 2 < bytes.count else { return }
                let message = MIDIInputNoteMessage(
                    timestampSeconds: timestampSeconds,
                    status: status,
                    data1: bytes[index + 1],
                    data2: bytes[index + 2]
                )
                record(message)
                index += 3
            case 0xA0, 0xB0, 0xE0:
                index += 3
            case 0xC0, 0xD0:
                index += 2
            default:
                index += 1
            }
        }
    }

    private func record(_ message: MIDIInputNoteMessage) {
        lock.lock()
        activeBuilder?.record(message)
        lock.unlock()
    }

    private static func endpoint(for uniqueID: Int32) -> MIDIEndpointRef? {
        for index in 0..<MIDIGetNumberOfSources() {
            let endpoint = MIDIGetSource(index)
            if endpointUniqueID(endpoint) == uniqueID {
                return endpoint
            }
        }
        return nil
    }

    private static func device(for endpoint: MIDIEndpointRef) -> MIDIInputDevice? {
        guard let uniqueID = endpointUniqueID(endpoint) else { return nil }
        return MIDIInputDevice(
            id: uniqueID,
            name: stringProperty(kMIDIPropertyDisplayName, for: endpoint)
                ?? stringProperty(kMIDIPropertyName, for: endpoint)
                ?? "MIDI Source \(uniqueID)",
            manufacturer: stringProperty(kMIDIPropertyManufacturer, for: endpoint)
        )
    }

    private static func endpointUniqueID(_ endpoint: MIDIEndpointRef) -> Int32? {
        var uniqueID: Int32 = 0
        let status = MIDIObjectGetIntegerProperty(endpoint, kMIDIPropertyUniqueID, &uniqueID)
        return status == noErr ? uniqueID : nil
    }

    private static func stringProperty(_ property: CFString, for endpoint: MIDIEndpointRef) -> String? {
        var unmanaged: Unmanaged<CFString>?
        let status = MIDIObjectGetStringProperty(endpoint, property, &unmanaged)
        guard status == noErr, let unmanaged else { return nil }
        return unmanaged.takeRetainedValue() as String
    }

    private static func bytes(from packet: MIDIPacket) -> [UInt8] {
        withUnsafeBytes(of: packet.data) { rawBuffer in
            Array(rawBuffer.prefix(Int(packet.length)))
        }
    }

    private static func hostTimeSeconds(_ timestamp: MIDITimeStamp) -> Double {
        let hostTime = timestamp == 0 ? mach_absolute_time() : UInt64(timestamp)
        var timebase = mach_timebase_info_data_t()
        mach_timebase_info(&timebase)
        let nanos = Double(hostTime) * Double(timebase.numer) / Double(timebase.denom)
        return nanos / 1_000_000_000.0
    }
}

private let midiInputReadProc: MIDIReadProc = { packetList, _, refCon in
    guard let refCon else { return }
    let recorder = Unmanaged<MIDIInputRecorder>.fromOpaque(refCon).takeUnretainedValue()
    recorder.receive(packetList: packetList)
}
