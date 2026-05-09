import Foundation

struct MIDIRecordingExporter {
    func export(recording: MIDIInputRecording) throws -> Data {
        try MIDIInputRecordingBuilder.validate(recording.options)

        var events: [(tick: Int, order: Int, bytes: [UInt8])] = []
        let tempoMicroseconds = Int((60_000_000.0 / recording.tempoBPM).rounded())
        events.append((0, 0, [
            0xFF, 0x51, 0x03,
            UInt8((tempoMicroseconds >> 16) & 0xFF),
            UInt8((tempoMicroseconds >> 8) & 0xFF),
            UInt8(tempoMicroseconds & 0xFF),
        ]))

        for note in recording.notes {
            let noteOnTick = max(0, Int((note.onsetBeat * Double(recording.ticksPerBeat)).rounded()))
            let noteOffTick = max(noteOnTick, Int(((note.onsetBeat + note.durationBeat) * Double(recording.ticksPerBeat)).rounded()))
            let channel = UInt8(note.channel & 0x0F)
            let pitch = UInt8(clamping: note.pitch)
            let velocity = UInt8(clamping: note.velocity)

            events.append((noteOnTick, 1, [0x90 | channel, pitch, velocity]))
            events.append((noteOffTick, 2, [0x80 | channel, pitch, 0]))
        }

        events.sort {
            if $0.tick != $1.tick { return $0.tick < $1.tick }
            return $0.order < $1.order
        }

        var track: [UInt8] = []
        var previousTick = 0
        for event in events {
            track.append(contentsOf: encodeVariableLength(event.tick - previousTick))
            track.append(contentsOf: event.bytes)
            previousTick = event.tick
        }
        track.append(contentsOf: [0x00, 0xFF, 0x2F, 0x00])

        var data = Data()
        data.append(contentsOf: [0x4D, 0x54, 0x68, 0x64])
        data.append(contentsOf: encodeUInt32(6))
        data.append(contentsOf: encodeUInt16(0))
        data.append(contentsOf: encodeUInt16(1))
        data.append(contentsOf: encodeUInt16(recording.ticksPerBeat))
        data.append(contentsOf: [0x4D, 0x54, 0x72, 0x6B])
        data.append(contentsOf: encodeUInt32(track.count))
        data.append(contentsOf: track)
        return data
    }

    private func encodeUInt16(_ value: Int) -> [UInt8] {
        [
            UInt8((value >> 8) & 0xFF),
            UInt8(value & 0xFF),
        ]
    }

    private func encodeUInt32(_ value: Int) -> [UInt8] {
        [
            UInt8((value >> 24) & 0xFF),
            UInt8((value >> 16) & 0xFF),
            UInt8((value >> 8) & 0xFF),
            UInt8(value & 0xFF),
        ]
    }

    private func encodeVariableLength(_ value: Int) -> [UInt8] {
        var buffer = value & 0x0FFFFFFF
        var bytes = [UInt8(buffer & 0x7F)]
        buffer >>= 7
        while buffer > 0 {
            bytes.insert(UInt8((buffer & 0x7F) | 0x80), at: 0)
            buffer >>= 7
        }
        return bytes
    }
}
