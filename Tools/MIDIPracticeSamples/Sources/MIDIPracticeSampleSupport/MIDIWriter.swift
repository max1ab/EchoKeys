import Foundation

public struct SampleMIDINote: Equatable {
    public var pitch: UInt8
    public var startTick: Int
    public var durationTick: Int
    public var velocity: UInt8

    public init(
        pitch: UInt8,
        startTick: Int,
        durationTick: Int,
        velocity: UInt8 = 80
    ) {
        self.pitch = pitch
        self.startTick = startTick
        self.durationTick = durationTick
        self.velocity = velocity
    }
}

public struct SimpleMIDIWriter {
    public var ticksPerQuarter: Int

    public init(ticksPerQuarter: Int = 480) {
        self.ticksPerQuarter = ticksPerQuarter
    }

    public func makeFile(notes: [SampleMIDINote]) -> Data {
        let track = makeTrack(notes: notes)
        var bytes: [UInt8] = []
        bytes.append(contentsOf: Array("MThd".utf8))
        bytes.append(contentsOf: be32(6))
        bytes.append(contentsOf: be16(0))
        bytes.append(contentsOf: be16(1))
        bytes.append(contentsOf: be16(ticksPerQuarter))
        bytes.append(contentsOf: Array("MTrk".utf8))
        bytes.append(contentsOf: be32(track.count))
        bytes.append(contentsOf: track)
        return Data(bytes)
    }

    private func makeTrack(notes: [SampleMIDINote]) -> [UInt8] {
        struct Message {
            var tick: Int
            var bytes: [UInt8]
            var order: Int
        }

        var messages: [Message] = []
        for (index, note) in notes.enumerated() {
            messages.append(Message(
                tick: note.startTick,
                bytes: [0x90, note.pitch, note.velocity],
                order: index * 2
            ))
            messages.append(Message(
                tick: note.startTick + note.durationTick,
                bytes: [0x80, note.pitch, 0],
                order: index * 2 + 1
            ))
        }

        messages.sort {
            if $0.tick != $1.tick { return $0.tick < $1.tick }
            return $0.order < $1.order
        }

        var track: [UInt8] = []
        var previousTick = 0
        for message in messages {
            track.append(contentsOf: varLen(message.tick - previousTick))
            track.append(contentsOf: message.bytes)
            previousTick = message.tick
        }
        track.append(contentsOf: [0x00, 0xFF, 0x2F, 0x00])
        return track
    }

    private func be16(_ value: Int) -> [UInt8] {
        [UInt8((value >> 8) & 0xFF), UInt8(value & 0xFF)]
    }

    private func be32(_ value: Int) -> [UInt8] {
        [
            UInt8((value >> 24) & 0xFF),
            UInt8((value >> 16) & 0xFF),
            UInt8((value >> 8) & 0xFF),
            UInt8(value & 0xFF),
        ]
    }

    private func varLen(_ value: Int) -> [UInt8] {
        var value = value
        var buffer = [UInt8(value & 0x7F)]
        value >>= 7
        while value > 0 {
            buffer.append(UInt8((value & 0x7F) | 0x80))
            value >>= 7
        }
        return buffer.reversed()
    }
}
