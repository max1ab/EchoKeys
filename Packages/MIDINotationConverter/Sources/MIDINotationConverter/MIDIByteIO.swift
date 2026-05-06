import Foundation

// MARK: - Binary structures

struct MIDITempoEvent {
    var tick: Int
    var microsecondsPerQuarter: Int
}

struct MIDIKeySigEvent {
    var tick: Int
    var sharpsFlats: Int8
    var minor: Bool
}

struct MIDITimeSigEvent {
    var tick: Int
    var numerator: Int
    var denominator: Int
}

struct MIDINoteEvent {
    var tick: Int
    var duration: Int
    var channel: Int
    var note: Int
    var velocity: Int
}

struct MIDITrackData {
    var notes: [MIDINoteEvent]
    var tempos: [MIDITempoEvent]
    var keySigs: [MIDIKeySigEvent]
    var timeSigs: [MIDITimeSigEvent]
}

// MARK: - MIDI constants

private let defaultTempo: Int = 500_000
let ticksPerQuarterDefault: Int = 480

// MARK: - Byte reader

struct MIDIByteReader {
    private let data: Data
    var offset: Int = 0

    init(data: Data) {
        self.data = data
    }

    var isAtEnd: Bool { offset >= data.count }

    mutating func readByte() throws -> UInt8 {
        guard offset < data.count else {
            throw NotationConversionError.invalidMIDIFile("Unexpected end of file")
        }
        let b = data[offset]
        offset += 1
        return b
    }

    mutating func readASCII(count: Int) throws -> String {
        guard offset + count <= data.count else {
            throw NotationConversionError.invalidMIDIFile("Unexpected end of file")
        }
        let bytes = data[offset..<(offset + count)]
        offset += count
        guard let str = String(bytes: bytes, encoding: .ascii) else {
            throw NotationConversionError.invalidMIDIFile("Invalid ASCII")
        }
        return str
    }

    mutating func readUInt16() throws -> Int {
        Int(try readByte()) << 8 | Int(try readByte())
    }

    mutating func readUInt24() throws -> Int {
        Int(try readByte()) << 16 | Int(try readByte()) << 8 | Int(try readByte())
    }

    mutating func readUInt32() throws -> Int {
        Int(try readByte()) << 24 | Int(try readByte()) << 16 | Int(try readByte()) << 8 | Int(try readByte())
    }

    mutating func readVarLen() throws -> Int {
        var value = 0
        for _ in 0..<4 {
            let b = try readByte()
            value = (value << 7) | Int(b & 0x7F)
            if b & 0x80 == 0 { return value }
        }
        throw NotationConversionError.invalidMIDIFile("Invalid variable-length quantity")
    }

    mutating func skip(_ n: Int) throws {
        guard offset + n <= data.count else {
            throw NotationConversionError.invalidMIDIFile("Unexpected end of file")
        }
        offset += n
    }
}

// MARK: - Byte writer

final class MIDIByteWriter {
    private var bytes: [UInt8] = []

    func writeByte(_ b: UInt8) { bytes.append(b) }
    func writeASCII(_ s: String) { bytes.append(contentsOf: s.utf8) }

    func writeUInt16(_ v: Int) {
        bytes.append(UInt8((v >> 8) & 0xFF))
        bytes.append(UInt8(v & 0xFF))
    }

    func writeUInt32(_ v: Int) {
        bytes.append(UInt8((v >> 24) & 0xFF))
        bytes.append(UInt8((v >> 16) & 0xFF))
        bytes.append(UInt8((v >> 8) & 0xFF))
        bytes.append(UInt8(v & 0xFF))
    }

    func writeVarLen(_ v: Int) {
        var value = v
        var buffer: [UInt8] = [UInt8(value & 0x7F)]
        value >>= 7
        while value > 0 {
            buffer.append(UInt8((value & 0x7F) | 0x80))
            value >>= 7
        }
        bytes.append(contentsOf: buffer.reversed())
    }

    func data() -> Data { Data(bytes) }
}

// MARK: - MIDI file parser

struct MIDIFileParser {
    func parse(_ data: Data) throws -> (division: Int, tracks: [MIDITrackData]) {
        var reader = MIDIByteReader(data: data)

        guard try reader.readASCII(count: 4) == "MThd" else {
            throw NotationConversionError.invalidMIDIFile("Missing MThd header")
        }
        let headerLen = try reader.readUInt32()
        guard headerLen >= 6 else {
            throw NotationConversionError.invalidMIDIFile("MThd too short")
        }
        _ = try reader.readUInt16() // format
        let trackCount = try reader.readUInt16()
        let division = try reader.readUInt16()

        guard division & 0x8000 == 0 else {
            throw NotationConversionError.invalidMIDIFile("SMPTE time division not supported")
        }

        if headerLen > 6 { try reader.skip(headerLen - 6) }

        var tracks: [MIDITrackData] = []
        for _ in 0..<trackCount {
            guard try reader.readASCII(count: 4) == "MTrk" else {
                throw NotationConversionError.invalidMIDIFile("Missing MTrk")
            }
            let trackLen = try reader.readUInt32()
            let trackEnd = reader.offset + trackLen
            var trackData = MIDITrackData(notes: [], tempos: [], keySigs: [], timeSigs: [])

            var runningStatus: UInt8?
            var absoluteTick = 0

            while reader.offset < trackEnd {
                absoluteTick += try reader.readVarLen()

                var status = try reader.readByte()
                if status < 0x80 {
                    guard let prev = runningStatus else {
                        throw NotationConversionError.invalidMIDIFile("Running status without status")
                    }
                    reader.offset -= 1
                    status = prev
                } else if status < 0xF0 {
                    runningStatus = status
                } else {
                    runningStatus = nil
                }

                switch status & 0xF0 {
                case 0x80: // Note Off
                    let note = Int(try reader.readByte())
                    _ = try reader.readByte() // velocity
                    trackData.notes.append(MIDINoteEvent(
                        tick: absoluteTick, duration: 0, channel: Int(status & 0x0F),
                        note: note, velocity: 0
                    ))

                case 0x90: // Note On
                    let note = Int(try reader.readByte())
                    let velocity = Int(try reader.readByte())
                    trackData.notes.append(MIDINoteEvent(
                        tick: absoluteTick, duration: 0, channel: Int(status & 0x0F),
                        note: note, velocity: velocity
                    ))

                case 0xA0, 0xE0:
                    try reader.skip(2)

                case 0xB0, 0xC0, 0xD0:
                    try reader.skip(1 + (status & 0xF0 == 0xC0 || status & 0xF0 == 0xD0 ? 0 : 1))

                case 0xF0:
                    if status == 0xFF {
                        let metaType = try reader.readByte()
                        let len = try reader.readVarLen()
                        switch metaType {
                        case 0x51 where len == 3:
                            trackData.tempos.append(MIDITempoEvent(
                                tick: absoluteTick,
                                microsecondsPerQuarter: try reader.readUInt24()
                            ))
                        case 0x58 where len >= 4:
                            trackData.timeSigs.append(MIDITimeSigEvent(
                                tick: absoluteTick,
                                numerator: Int(try reader.readByte()),
                                denominator: Int(try reader.readByte())
                            ))
                            try reader.skip(len - 2)
                        case 0x59 where len >= 2:
                            trackData.keySigs.append(MIDIKeySigEvent(
                                tick: absoluteTick,
                                sharpsFlats: Int8(bitPattern: try reader.readByte()),
                                minor: try reader.readByte() != 0
                            ))
                            try reader.skip(len - 2)
                        default:
                            try reader.skip(len)
                        }
                    } else {
                        let len = try reader.readVarLen()
                        try reader.skip(len)
                    }

                default:
                    throw NotationConversionError.invalidMIDIFile(
                        "Unknown status 0x\(String(status, radix: 16))"
                    )
                }
            }

            if reader.offset != trackEnd {
                reader.offset = trackEnd
            }
            tracks.append(trackData)
        }

        return (division, tracks)
    }
}

// MARK: - MIDI tempo → tick conversion

func tickDuration(
    _ ticks: Int,
    ticksPerQuarter: Int,
    tempos: [MIDITempoEvent]
) -> TimeInterval {
    guard ticks > 0, ticksPerQuarter > 0 else { return 0 }

    var sorted = tempos.sorted { $0.tick < $1.tick }
    if sorted.isEmpty || sorted[0].tick != 0 {
        sorted.insert(MIDITempoEvent(tick: 0, microsecondsPerQuarter: defaultTempo), at: 0)
    }

    var seconds: Float64 = 0
    var prevTick = 0
    for tempo in sorted where tempo.tick < ticks {
        let deltaTicks = Float64(tempo.tick - prevTick)
        seconds += deltaTicks / Float64(ticksPerQuarter) * Float64(defaultTempo) / 1_000_000
        prevTick = tempo.tick
    }

    let lastTempo = sorted.last(where: { $0.tick <= prevTick })?.microsecondsPerQuarter ?? defaultTempo
    seconds += Float64(ticks - prevTick) / Float64(ticksPerQuarter) * Float64(lastTempo) / 1_000_000

    return TimeInterval(seconds)
}
