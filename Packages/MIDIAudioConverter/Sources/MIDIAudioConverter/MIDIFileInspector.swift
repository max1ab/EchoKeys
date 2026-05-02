import Foundation

public struct MIDIFileInspector: MIDIFileInspecting {
    public init() {}

    public func inspectMIDIFile(at midiURL: URL) throws -> MIDIFileInfo {
        try MIDISequenceLoader.validateInputURL(midiURL)

        let data: Data
        do {
            data = try Data(contentsOf: midiURL)
        } catch {
            throw MIDIConversionError.invalidMIDIFile(error.localizedDescription)
        }

        return try StandardMIDIFileInspector(data: data).inspect()
    }
}

private struct StandardMIDIFileInspector {
    let data: Data

    func inspect() throws -> MIDIFileInfo {
        var reader = ByteReader(data: data)
        guard try reader.readASCII(count: 4) == "MThd" else {
            throw MIDIConversionError.invalidMIDIFile("Missing MThd header.")
        }

        let headerLength = try reader.readUInt32()
        guard headerLength >= 6 else {
            throw MIDIConversionError.invalidMIDIFile("Invalid MThd length.")
        }

        _ = try reader.readUInt16()
        let trackCount = Int(try reader.readUInt16())
        let division = try reader.readUInt16()
        guard division & 0x8000 == 0 else {
            throw MIDIConversionError.invalidMIDIFile("SMPTE time division is not supported by the inspector yet.")
        }

        if headerLength > 6 {
            try reader.skip(Int(headerLength - 6))
        }

        let ticksPerQuarter = Double(division)
        var tempoEvents: [(tick: Int, microsecondsPerQuarter: Int)] = [(0, 500_000)]
        var noteEventCount = 0
        var tempoEventCount = 0
        var sustainPedalEventCount = 0
        var maxTick = 0

        for _ in 0..<trackCount {
            guard try reader.readASCII(count: 4) == "MTrk" else {
                throw MIDIConversionError.invalidMIDIFile("Missing MTrk chunk.")
            }

            let trackLength = Int(try reader.readUInt32())
            let trackEnd = reader.offset + trackLength
            guard trackEnd <= data.count else {
                throw MIDIConversionError.invalidMIDIFile("Track length exceeds file size.")
            }

            var absoluteTick = 0
            var runningStatus: UInt8?

            while reader.offset < trackEnd {
                absoluteTick += try reader.readVariableLengthQuantity(limit: trackEnd)
                maxTick = max(maxTick, absoluteTick)

                var status = try reader.readByte(limit: trackEnd)
                if status < 0x80 {
                    guard let previousStatus = runningStatus else {
                        throw MIDIConversionError.invalidMIDIFile("Running status used before any MIDI status byte.")
                    }
                    reader.offset -= 1
                    status = previousStatus
                } else if status < 0xF0 {
                    runningStatus = status
                }

                switch status {
                case 0x80...0x8F:
                    try reader.skip(2, limit: trackEnd)
                case 0x90...0x9F:
                    _ = try reader.readByte(limit: trackEnd)
                    let velocity = try reader.readByte(limit: trackEnd)
                    if velocity > 0 {
                        noteEventCount += 1
                    }
                case 0xA0...0xAF, 0xB0...0xBF, 0xE0...0xEF:
                    let data1 = try reader.readByte(limit: trackEnd)
                    _ = try reader.readByte(limit: trackEnd)
                    if status & 0xF0 == 0xB0, data1 == 64 {
                        sustainPedalEventCount += 1
                    }
                case 0xC0...0xDF:
                    try reader.skip(1, limit: trackEnd)
                case 0xFF:
                    runningStatus = nil
                    let metaType = try reader.readByte(limit: trackEnd)
                    let length = try reader.readVariableLengthQuantity(limit: trackEnd)
                    if metaType == 0x51, length == 3 {
                        let value = try reader.readUInt24(limit: trackEnd)
                        tempoEventCount += 1
                        tempoEvents.append((absoluteTick, value))
                    } else {
                        try reader.skip(length, limit: trackEnd)
                    }
                case 0xF0, 0xF7:
                    runningStatus = nil
                    let length = try reader.readVariableLengthQuantity(limit: trackEnd)
                    try reader.skip(length, limit: trackEnd)
                default:
                    throw MIDIConversionError.invalidMIDIFile("Unsupported MIDI event status 0x\(String(status, radix: 16)).")
                }
            }

            if reader.offset != trackEnd {
                reader.offset = trackEnd
            }
        }

        return MIDIFileInfo(
            duration: duration(maxTick: maxTick, ticksPerQuarter: ticksPerQuarter, tempoEvents: tempoEvents),
            trackCount: trackCount,
            noteEventCount: noteEventCount,
            tempoEventCount: tempoEventCount,
            sustainPedalEventCount: sustainPedalEventCount
        )
    }

    private func duration(
        maxTick: Int,
        ticksPerQuarter: Double,
        tempoEvents: [(tick: Int, microsecondsPerQuarter: Int)]
    ) -> TimeInterval {
        guard maxTick > 0 else {
            return 0
        }

        let sortedTempoEvents = tempoEvents.sorted { lhs, rhs in
            if lhs.tick == rhs.tick {
                return lhs.microsecondsPerQuarter < rhs.microsecondsPerQuarter
            }
            return lhs.tick < rhs.tick
        }

        var seconds = 0.0
        var currentTick = 0
        var currentTempo = 500_000

        for tempoEvent in sortedTempoEvents where tempoEvent.tick <= maxTick {
            if tempoEvent.tick > currentTick {
                seconds += secondsBetweenTicks(
                    from: currentTick,
                    to: tempoEvent.tick,
                    ticksPerQuarter: ticksPerQuarter,
                    microsecondsPerQuarter: currentTempo
                )
                currentTick = tempoEvent.tick
            }
            currentTempo = tempoEvent.microsecondsPerQuarter
        }

        if currentTick < maxTick {
            seconds += secondsBetweenTicks(
                from: currentTick,
                to: maxTick,
                ticksPerQuarter: ticksPerQuarter,
                microsecondsPerQuarter: currentTempo
            )
        }

        return seconds
    }

    private func secondsBetweenTicks(
        from startTick: Int,
        to endTick: Int,
        ticksPerQuarter: Double,
        microsecondsPerQuarter: Int
    ) -> TimeInterval {
        let ticks = Double(endTick - startTick)
        return ticks / ticksPerQuarter * Double(microsecondsPerQuarter) / 1_000_000
    }
}

private struct ByteReader {
    let data: Data
    var offset = 0

    mutating func readASCII(count: Int) throws -> String {
        guard offset + count <= data.count else {
            throw MIDIConversionError.invalidMIDIFile("Unexpected end of file.")
        }

        let bytes = data[offset..<(offset + count)]
        offset += count
        guard let string = String(bytes: bytes, encoding: .ascii) else {
            throw MIDIConversionError.invalidMIDIFile("Invalid ASCII chunk identifier.")
        }
        return string
    }

    mutating func readUInt16() throws -> UInt16 {
        UInt16(try readByte()) << 8 | UInt16(try readByte())
    }

    mutating func readUInt32() throws -> UInt32 {
        UInt32(try readByte()) << 24 |
            UInt32(try readByte()) << 16 |
            UInt32(try readByte()) << 8 |
            UInt32(try readByte())
    }

    mutating func readUInt24(limit: Int) throws -> Int {
        Int(try readByte(limit: limit)) << 16 |
            Int(try readByte(limit: limit)) << 8 |
            Int(try readByte(limit: limit))
    }

    mutating func readByte(limit: Int? = nil) throws -> UInt8 {
        let boundary = limit ?? data.count
        guard offset < boundary, offset < data.count else {
            throw MIDIConversionError.invalidMIDIFile("Unexpected end of MIDI event data.")
        }

        let byte = data[offset]
        offset += 1
        return byte
    }

    mutating func readVariableLengthQuantity(limit: Int) throws -> Int {
        var value = 0

        for _ in 0..<4 {
            let byte = try readByte(limit: limit)
            value = (value << 7) | Int(byte & 0x7F)
            if byte & 0x80 == 0 {
                return value
            }
        }

        throw MIDIConversionError.invalidMIDIFile("Invalid variable-length quantity.")
    }

    mutating func skip(_ count: Int, limit: Int? = nil) throws {
        let boundary = limit ?? data.count
        guard count >= 0, offset + count <= boundary, offset + count <= data.count else {
            throw MIDIConversionError.invalidMIDIFile("Unexpected end of MIDI event data.")
        }
        offset += count
    }
}
