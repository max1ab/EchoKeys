import Foundation

enum MIDIByteFixtures {
    static func emptyMIDI() -> Data {
        midiFile(format: 0, division: 480, tracks: [
            trackChunk([
                0x00, 0xFF, 0x2F, 0x00,
            ]),
        ])
    }

    static func shortPianoMIDI() -> Data {
        midiFile(format: 0, division: 480, tracks: [
            trackChunk([
                0x00, 0xFF, 0x51, 0x03, 0x07, 0xA1, 0x20,
                0x00, 0xC0, 0x00,
                0x00, 0x90, 0x3C, 0x64,
                0x81, 0x70, 0xB0, 0x40, 0x7F,
                0x81, 0x70, 0x80, 0x3C, 0x00,
                0x00, 0x90, 0x40, 0x64,
                0x81, 0x70, 0xB0, 0x40, 0x00,
                0x81, 0x70, 0x80, 0x40, 0x00,
                0x00, 0xFF, 0x2F, 0x00,
            ]),
        ])
    }

    static func multiTrackMIDI() -> Data {
        midiFile(format: 1, division: 480, tracks: [
            trackChunk([
                0x00, 0xFF, 0x51, 0x03, 0x07, 0xA1, 0x20,
                0x00, 0xFF, 0x2F, 0x00,
            ]),
            trackChunk([
                0x00, 0xC0, 0x00,
                0x00, 0x90, 0x3C, 0x64,
                0x83, 0x60, 0x80, 0x3C, 0x00,
                0x00, 0xFF, 0x2F, 0x00,
            ]),
            trackChunk([
                0x00, 0xC1, 0x00,
                0x00, 0x91, 0x43, 0x50,
                0x83, 0x60, 0x81, 0x43, 0x00,
                0x00, 0xFF, 0x2F, 0x00,
            ]),
        ])
    }

    private static func midiFile(format: UInt16, division: UInt16, tracks: [[UInt8]]) -> Data {
        var bytes: [UInt8] = [
            0x4D, 0x54, 0x68, 0x64,
            0x00, 0x00, 0x00, 0x06,
            UInt8((format >> 8) & 0xFF), UInt8(format & 0xFF),
            UInt8((UInt16(tracks.count) >> 8) & 0xFF), UInt8(UInt16(tracks.count) & 0xFF),
            UInt8((division >> 8) & 0xFF), UInt8(division & 0xFF),
        ]
        for track in tracks {
            bytes.append(contentsOf: track)
        }
        return Data(bytes)
    }

    private static func trackChunk(_ events: [UInt8]) -> [UInt8] {
        let length = UInt32(events.count)
        return [
            0x4D, 0x54, 0x72, 0x6B,
            UInt8((length >> 24) & 0xFF),
            UInt8((length >> 16) & 0xFF),
            UInt8((length >> 8) & 0xFF),
            UInt8(length & 0xFF),
        ] + events
    }
}
