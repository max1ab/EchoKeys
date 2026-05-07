import Foundation

struct MIDIEventConverter {
    var prefix: String

    func convert(_ data: Data) throws -> MIDIEventConversion {
        let parsed = try MIDIFileParser().parse(data)
        var warnings: [String] = []
        var events: [NoteEvent] = []

        for track in parsed.tracks {
            let paired = pairNotes(in: track.events, trackIndex: track.index, warnings: &warnings)
            for note in paired {
                let id = "\(prefix)-\(String(format: "%06d", events.count))"
                events.append(NoteEvent(
                    id: id,
                    pitch: note.pitch,
                    onsetBeat: Double(note.startTick) / Double(parsed.ticksPerQuarter),
                    durationBeat: Double(note.durationTick) / Double(parsed.ticksPerQuarter),
                    velocity: note.velocity,
                    trackIndex: note.trackIndex,
                    channel: note.channel,
                    sourceTick: note.startTick,
                    sourceDurationTick: note.durationTick,
                    annotations: TargetAnnotation(sources: [
                        EventSource(
                            trackIndex: note.trackIndex,
                            channel: note.channel,
                            sourceTick: note.startTick,
                            sourceDurationTick: note.durationTick
                        )
                    ])
                ))
            }
        }

        return MIDIEventConversion(events: events.practiceSorted(), warnings: warnings)
    }

    private func pairNotes(
        in rawEvents: [RawMIDINoteMessage],
        trackIndex: Int,
        warnings: inout [String]
    ) -> [PairedMIDINote] {
        struct PendingKey: Hashable {
            var channel: Int
            var pitch: Int
        }

        var pending: [PendingKey: [(tick: Int, velocity: Int)]] = [:]
        var paired: [PairedMIDINote] = []

        for event in rawEvents.sorted(by: { $0.tick < $1.tick }) {
            let key = PendingKey(channel: event.channel, pitch: event.pitch)
            if event.isOn {
                pending[key, default: []].append((event.tick, event.velocity))
            } else {
                guard var queue = pending[key], !queue.isEmpty else {
                    warnings.append("Ignoring unmatched noteOff track=\(trackIndex) channel=\(event.channel) pitch=\(event.pitch) tick=\(event.tick)")
                    continue
                }
                let start = queue.removeFirst()
                pending[key] = queue.isEmpty ? nil : queue
                let duration = event.tick - start.tick
                guard duration > 0 else {
                    warnings.append("Ignoring non-positive note duration track=\(trackIndex) channel=\(event.channel) pitch=\(event.pitch) tick=\(event.tick)")
                    continue
                }
                paired.append(PairedMIDINote(
                    trackIndex: trackIndex,
                    channel: event.channel,
                    pitch: event.pitch,
                    startTick: start.tick,
                    durationTick: duration,
                    velocity: start.velocity
                ))
            }
        }

        for (key, queue) in pending where !queue.isEmpty {
            warnings.append("Discarded \(queue.count) unclosed note(s) track=\(trackIndex) channel=\(key.channel) pitch=\(key.pitch)")
        }

        return paired.sorted {
            if $0.startTick != $1.startTick { return $0.startTick < $1.startTick }
            return $0.pitch < $1.pitch
        }
    }
}

struct MIDIEventConversion: Equatable {
    var events: [NoteEvent]
    var warnings: [String]
}

private struct PairedMIDINote {
    var trackIndex: Int
    var channel: Int
    var pitch: Int
    var startTick: Int
    var durationTick: Int
    var velocity: Int
}

private struct MIDIFile {
    var ticksPerQuarter: Int
    var tracks: [MIDITrack]
}

private struct MIDITrack {
    var index: Int
    var events: [RawMIDINoteMessage]
}

private struct RawMIDINoteMessage {
    var tick: Int
    var channel: Int
    var pitch: Int
    var velocity: Int
    var isOn: Bool
}

private struct MIDIFileParser {
    func parse(_ data: Data) throws -> MIDIFile {
        var reader = MIDIByteReader(data: data)
        guard try reader.readASCII(count: 4) == "MThd" else {
            throw MIDIPracticeError.invalidMIDIFile("Missing MThd header")
        }

        let headerLength = try reader.readUInt32()
        guard headerLength >= 6 else {
            throw MIDIPracticeError.invalidMIDIFile("MThd is too short")
        }

        _ = try reader.readUInt16()
        let trackCount = try reader.readUInt16()
        let division = try reader.readUInt16()
        guard division & 0x8000 == 0 else {
            throw MIDIPracticeError.unsupportedMIDI("SMPTE time division is not supported")
        }
        if headerLength > 6 {
            try reader.skip(headerLength - 6)
        }

        var tracks: [MIDITrack] = []
        for trackIndex in 0..<trackCount {
            guard try reader.readASCII(count: 4) == "MTrk" else {
                throw MIDIPracticeError.invalidMIDIFile("Missing MTrk header")
            }
            let trackLength = try reader.readUInt32()
            let trackEnd = reader.offset + trackLength
            var events: [RawMIDINoteMessage] = []
            var absoluteTick = 0
            var runningStatus: UInt8?

            while reader.offset < trackEnd {
                absoluteTick += try reader.readVarLen()
                var status = try reader.readByte()

                if status < 0x80 {
                    guard let previous = runningStatus else {
                        throw MIDIPracticeError.invalidMIDIFile("Running status without previous status")
                    }
                    reader.offset -= 1
                    status = previous
                } else if status < 0xF0 {
                    runningStatus = status
                } else {
                    runningStatus = nil
                }

                switch status & 0xF0 {
                case 0x80:
                    let pitch = Int(try reader.readByte())
                    _ = try reader.readByte()
                    events.append(RawMIDINoteMessage(
                        tick: absoluteTick,
                        channel: Int(status & 0x0F),
                        pitch: pitch,
                        velocity: 0,
                        isOn: false
                    ))
                case 0x90:
                    let pitch = Int(try reader.readByte())
                    let velocity = Int(try reader.readByte())
                    events.append(RawMIDINoteMessage(
                        tick: absoluteTick,
                        channel: Int(status & 0x0F),
                        pitch: pitch,
                        velocity: velocity,
                        isOn: velocity > 0
                    ))
                case 0xA0, 0xB0, 0xE0:
                    try reader.skip(2)
                case 0xC0, 0xD0:
                    try reader.skip(1)
                case 0xF0:
                    try skipSystemEvent(status: status, reader: &reader)
                default:
                    throw MIDIPracticeError.invalidMIDIFile("Unknown MIDI status 0x\(String(status, radix: 16))")
                }
            }

            reader.offset = trackEnd
            tracks.append(MIDITrack(index: trackIndex, events: events))
        }

        return MIDIFile(ticksPerQuarter: division, tracks: tracks)
    }

    private func skipSystemEvent(status: UInt8, reader: inout MIDIByteReader) throws {
        if status == 0xFF {
            _ = try reader.readByte()
            let length = try reader.readVarLen()
            try reader.skip(length)
        } else if status == 0xF0 || status == 0xF7 {
            let length = try reader.readVarLen()
            try reader.skip(length)
        } else {
            throw MIDIPracticeError.invalidMIDIFile("Unsupported system status 0x\(String(status, radix: 16))")
        }
    }
}

private struct MIDIByteReader {
    private let data: Data
    var offset: Int = 0

    init(data: Data) {
        self.data = data
    }

    mutating func readByte() throws -> UInt8 {
        guard offset < data.count else {
            throw MIDIPracticeError.invalidMIDIFile("Unexpected end of file")
        }
        let byte = data[offset]
        offset += 1
        return byte
    }

    mutating func readASCII(count: Int) throws -> String {
        guard offset + count <= data.count else {
            throw MIDIPracticeError.invalidMIDIFile("Unexpected end of file")
        }
        let bytes = data[offset..<(offset + count)]
        offset += count
        guard let string = String(bytes: bytes, encoding: .ascii) else {
            throw MIDIPracticeError.invalidMIDIFile("Invalid ASCII")
        }
        return string
    }

    mutating func readUInt16() throws -> Int {
        Int(try readByte()) << 8 | Int(try readByte())
    }

    mutating func readUInt32() throws -> Int {
        Int(try readByte()) << 24 | Int(try readByte()) << 16 | Int(try readByte()) << 8 | Int(try readByte())
    }

    mutating func readVarLen() throws -> Int {
        var value = 0
        for _ in 0..<4 {
            let byte = try readByte()
            value = (value << 7) | Int(byte & 0x7F)
            if byte & 0x80 == 0 {
                return value
            }
        }
        throw MIDIPracticeError.invalidMIDIFile("Invalid variable-length quantity")
    }

    mutating func skip(_ count: Int) throws {
        guard count >= 0, offset + count <= data.count else {
            throw MIDIPracticeError.invalidMIDIFile("Unexpected end of file")
        }
        offset += count
    }
}
