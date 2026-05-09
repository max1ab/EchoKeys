import Foundation
import Testing
@testable import MIDINotationConverter

@Suite struct JTFParseAndSerializeTests {

    @Test func parseSimpleMelody() throws {
        let text = """
        1=C 4/4
        | 1 2 3 4 | 5 6 7 [1] ||
        """
        let score = try JTFParser().parse(text)
        #expect(score.key.tonic == .C)
        #expect(score.timeSig == TimeSignature(numerator: 4, denominator: 4))
        #expect(score.voices.count == 1)
        let voice = try #require(score.voices.first)
        #expect(voice.measures.count == 2)
    }

    @Test func parseWithDottedRhythm() throws {
        let text = """
        1=C 4/4
        | 3._ 2_ 2 - | 1 - - - ||
        """
        let score = try JTFParser().parse(text)
        let voice = try #require(score.voices.first)
        let measure = try #require(voice.measures.first)
        #expect(measure.elements.count == 3) // dotted eighth, eighth, sustained half
        guard case .note(let sustained) = measure.elements[2] else {
            Issue.record("Expected sustained note")
            return
        }
        #expect(sustained.duration.beats == 2.0)
    }

    @Test func parseChord() throws {
        let text = """
        1=C 4/4
        | {1 3 5} 2 3 | 4 - - - ||
        """
        let score = try JTFParser().parse(text)
        let voice = try #require(score.voices.first)
        let measure = try #require(voice.measures.first)
        guard case .chord(let atoms) = measure.elements[0] else {
            Issue.record("First element should be chord")
            return
        }
        #expect(atoms.count == 3)
        #expect(atoms[0].pitch == 1)
        #expect(atoms[1].pitch == 3)
        #expect(atoms[2].pitch == 5)
    }

    @Test func rejectChordWithMixedDurationsInOneVoice() throws {
        let text = """
        1=C 4/4
        | { [#4] [7]__ } 1 ||
        """

        do {
            _ = try JTFParser().parse(text)
            Issue.record("Expected mixed-duration chord to fail")
            return
        } catch let error as NotationConversionError {
            #expect(error.localizedDescription.contains("same duration"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func parseAccidentals() throws {
        let text = """
        1=G 4/4
        | 3 #4 5 (b7) | [1] - - - ||
        """
        let score = try JTFParser().parse(text)
        #expect(score.key.tonic == .G)
        let voice = try #require(score.voices.first)
        let measure = try #require(voice.measures.first)
        guard case .note(let atom) = measure.elements[1] else {
            Issue.record("Expected sharp note")
            return
        }
        #expect(atom.accidental == 1)
        #expect(atom.pitch == 4)
    }

    @Test func parseOctaveMarks() throws {
        let text = """
        1=C 4/4
        | (5) 1 [3] | [[1]] - - - ||
        """
        let score = try JTFParser().parse(text)
        let voice = try #require(score.voices.first)
        let measure = try #require(voice.measures.first)
        guard case .note(let low) = measure.elements[0] else {
            Issue.record("Expected low octave note")
            return
        }
        #expect(low.octave == -1)
        #expect(low.pitch == 5)

        guard case .note(let high) = measure.elements[2] else {
            Issue.record("Expected high octave note")
            return
        }
        #expect(high.octave == 1)
        #expect(high.pitch == 3)
    }

    @Test func parseRest() throws {
        let text = """
        1=C 4/4
        | 1 0 3 0 | 0_ 0_ 0_ 0_ ||
        """
        let score = try JTFParser().parse(text)
        let voice = try #require(score.voices.first)
        let measure = try #require(voice.measures.first)
        guard case .rest(let dur) = measure.elements[1] else {
            Issue.record("Expected rest")
            return
        }
        #expect(dur.beats == 1.0)
    }

    @Test func parseDashExtendsPreviousSound() throws {
        let text = """
        1=C 4/4
        | 1 - - - ||
        """
        let score = try JTFParser().parse(text)
        let voice = try #require(score.voices.first)
        let measure = try #require(voice.measures.first)
        #expect(measure.elements.count == 1)
        guard case .note(let atom) = measure.elements[0] else {
            Issue.record("Expected sustained note")
            return
        }
        #expect(atom.pitch == 1)
        #expect(atom.duration.beats == 4.0)
    }

    @Test func parseTieAndSlur() throws {
        let text = """
        1=C 4/4
        | 3 ~ 3 ^ 5 | 1 - - - ||
        """
        let score = try JTFParser().parse(text)
        let voice = try #require(score.voices.first)
        let measure = try #require(voice.measures.first)
        #expect(measure.elements[1] == .tie)
        #expect(measure.elements[3] == .slur)
    }

    @Test func parseTuplet() throws {
        let text = """
        1=C 4/4
        | (3 1_ 2_ 3_) 4 | 1 - - - ||
        """
        let score = try JTFParser().parse(text)
        let voice = try #require(score.voices.first)
        let measure = try #require(voice.measures.first)
        guard case .tuplet(let count, let elements) = measure.elements[0] else {
            Issue.record("Expected tuplet")
            return
        }
        #expect(count == 3)
        #expect(elements.count == 3)
    }

    @Test func parseMultiVoice() throws {
        let text = """
        1=C 4/4
        V:旋律
        | 1 2 3 4 | 5 6 7 [1] ||
        V:伴奏
        | {1 5} {3 5} {2 5} {1 5} | {1 3 5 7} - - - ||
        """
        let score = try JTFParser().parse(text)
        #expect(score.voices.count == 2)
        #expect(score.voices[0].name == "旋律")
        #expect(score.voices[1].name == "伴奏")
        #expect(score.voices[0].measures.count == 2)
        #expect(score.voices[1].measures.count == 2)
    }
}

@Suite struct JTFToMIDIToTests {
    @Test func roundTripSimple() throws {
        let text = """
        1=C 4/4
        | 1 2 3 4 | 5 6 7 [1] ||
        """
        let tempDir = FileManager.default.temporaryDirectory
        let midiURL = tempDir.appendingPathComponent("test_simple.mid")
        let result = try JTFToMIDI().convert(text, to: midiURL)
        #expect(result.trackCount == 1)
        #expect(result.noteEventCount > 0)

        let jtfBack = try MIDIToJTF().convert(midiURL: midiURL)
        #expect(!jtfBack.isEmpty)
    }

    @Test func roundTripDotted() throws {
        let text = """
        1=C 4/4
        | 3._ 2_ 2 - | 1 - - - ||
        """
        let tempDir = FileManager.default.temporaryDirectory
        let midiURL = tempDir.appendingPathComponent("test_dotted.mid")
        _ = try JTFToMIDI().convert(text, to: midiURL)
        let jtfBack = try MIDIToJTF().convert(midiURL: midiURL)
        #expect(jtfBack.contains("3"))
    }

    @Test func roundTripChord() throws {
        let text = """
        1=C 4/4
        | {1 3 5} 2 3 | 4 - - - ||
        """
        let tempDir = FileManager.default.temporaryDirectory
        let midiURL = tempDir.appendingPathComponent("test_chord.mid")
        let result = try JTFToMIDI().convert(text, to: midiURL)
        #expect(result.trackCount == 1)

        let jtfBack = try MIDIToJTF().convert(midiURL: midiURL)
        #expect(jtfBack.contains("{"))
    }

    @Test func roundTripAccidentals() throws {
        let text = """
        1=G 4/4
        | 3 #4 5 (b7) | [1] - - - ||
        """
        let tempDir = FileManager.default.temporaryDirectory
        let midiURL = tempDir.appendingPathComponent("test_acc.mid")
        _ = try JTFToMIDI().convert(text, to: midiURL)
        let jtfBack = try MIDIToJTF().convert(midiURL: midiURL)
        #expect(jtfBack.contains("#") || jtfBack.contains("b"))
    }

    @Test func parseWithoutHeaderDefaults() throws {
        let text = "| 1 2 3 4 |"
        let score = try JTFParser().parse(text)
        #expect(score.key.tonic == .C)
        #expect(score.tempo == 120)
    }

    @Test func plainCEncodesAsMiddleC() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let midiURL = tempDir.appendingPathComponent("test_middle_c.mid")
        _ = try JTFToMIDI().convert("1=C 4/4\n| 1 ||", to: midiURL)

        let data = try Data(contentsOf: midiURL)
        let (_, tracks) = try MIDIFileParser().parse(data)
        let noteOn = try #require(tracks.flatMap(\.notes).first { $0.velocity > 0 })
        #expect(noteOn.note == 60)
    }

    @Test func dashSustainEncodesSingleLongNote() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let midiURL = tempDir.appendingPathComponent("test_sustain.mid")
        _ = try JTFToMIDI().convert("1=C 4/4\n| 1 - - - ||", to: midiURL)

        let data = try Data(contentsOf: midiURL)
        let (division, tracks) = try MIDIFileParser().parse(data)
        let noteEvents = tracks.flatMap(\.notes)
        #expect(noteEvents.filter { $0.velocity > 0 }.count == 1)
        let noteOff = try #require(noteEvents.first { $0.velocity == 0 && $0.note == 60 })
        #expect(noteOff.tick == division * 4)
    }

    @Test func midiDecodeSplitsSameOnsetDifferentDurationsIntoVoices() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let midiURL = tempDir.appendingPathComponent("test_split_voices.mid")
        try makeMIDIFile(
            division: 480,
            notes: [
                (note: 60, startTick: 0, duration: 480),
                (note: 67, startTick: 0, duration: 120),
            ]
        ).write(to: midiURL)

        let jtf = try MIDIToJTF().convert(midiURL: midiURL)
        #expect(jtf.contains("V:Track1-Voice1"))
        #expect(jtf.contains("V:Track1-Voice2"))
        #expect(!jtf.contains("{ 1 5_ }"))
        _ = try JTFParser().parse(jtf)
    }

    @Test func midiDecodeUsesFileDivisionForDurations() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let midiURL = tempDir.appendingPathComponent("test_960_tpq.mid")
        try makeSingleNoteMIDI(division: 960, startTick: 0, duration: 960).write(to: midiURL)

        let jtf = try MIDIToJTF().convert(midiURL: midiURL)
        #expect(jtf.contains("| 1 ||"))
        #expect(!jtf.contains("| 1 - ||"))
    }

    @Test func midiDecodeInsertsRestsForGaps() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let midiURL = tempDir.appendingPathComponent("test_gap.mid")
        try makeSingleNoteMIDI(division: 480, startTick: 960, duration: 480).write(to: midiURL)

        let jtf = try MIDIToJTF().convert(midiURL: midiURL)
        #expect(jtf.contains("| 0 0 1 ||"))
    }
}

@Suite struct SerializeTests {

    @Test func serializeSimpleMelody() throws {
        let score = Score(
            key: .C,
            timeSig: .fourFour,
            tempo: 120,
            voices: [
                Voice(name: nil, measures: [
                    Measure(elements: [
                        .note(NoteAtom(octave: 0, pitch: 1, accidental: 0, duration: .quarter)),
                        .note(NoteAtom(octave: 0, pitch: 2, accidental: 0, duration: .quarter)),
                        .note(NoteAtom(octave: 0, pitch: 3, accidental: 0, duration: .quarter)),
                        .note(NoteAtom(octave: 0, pitch: 4, accidental: 0, duration: .quarter)),
                    ], barPrefix: .bar, barSuffix: .doubleBar),
                ]),
            ]
        )
        let text = try JTFSerializer().serialize(score)
        #expect(text.contains("1=C 4/4"))
        #expect(text.contains("| 1 2 3 4 ||"))
    }
}

@Suite struct KeyInferenceTests {

    @Test func inferCMajor() throws {
        let parser = JTFParser()
        let key = try parser.parseKeySignature("1=C")
        #expect(key.tonic == .C)
    }

    @Test func inferGFlatMajor() throws {
        let parser = JTFParser()
        let key = try parser.parseKeySignature("1=Gb")
        #expect(key.tonic == .Gflat)
    }

    @Test func parseTimeSig() throws {
        let parser = JTFParser()
        let ts = try parser.parseTimeSignature("6/8")
        #expect(ts.numerator == 6)
        #expect(ts.denominator == 8)
    }
}

private func makeSingleNoteMIDI(division: Int, startTick: Int, duration: Int) -> Data {
    makeMIDIFile(division: division, notes: [(note: 60, startTick: startTick, duration: duration)])
}

private func makeMIDIFile(division: Int, notes: [(note: Int, startTick: Int, duration: Int)]) -> Data {
    var events: [(tick: Int, bytes: [UInt8])] = []
    for note in notes {
        events.append((note.startTick, [0x90, UInt8(note.note), 80]))
        events.append((note.startTick + note.duration, [0x80, UInt8(note.note), 0]))
    }
    events.sort {
        $0.tick < $1.tick || ($0.tick == $1.tick && $0.bytes[0] == 0x80 && $1.bytes[0] != 0x80)
    }

    var track: [UInt8] = []
    var previousTick = 0
    for event in events {
        track.append(contentsOf: encodeVarLen(event.tick - previousTick))
        track.append(contentsOf: event.bytes)
        previousTick = event.tick
    }
    track.append(contentsOf: [0x00, 0xFF, 0x2F, 0x00])

    var bytes: [UInt8] = []
    bytes.append(contentsOf: "MThd".utf8)
    bytes.append(contentsOf: uint32Bytes(6))
    bytes.append(contentsOf: uint16Bytes(0))
    bytes.append(contentsOf: uint16Bytes(1))
    bytes.append(contentsOf: uint16Bytes(division))
    bytes.append(contentsOf: "MTrk".utf8)
    bytes.append(contentsOf: uint32Bytes(track.count))
    bytes.append(contentsOf: track)
    return Data(bytes)
}

private func encodeVarLen(_ value: Int) -> [UInt8] {
    var v = value
    var buffer: [UInt8] = [UInt8(v & 0x7F)]
    v >>= 7
    while v > 0 {
        buffer.append(UInt8((v & 0x7F) | 0x80))
        v >>= 7
    }
    return buffer.reversed()
}

private func uint16Bytes(_ value: Int) -> [UInt8] {
    [
        UInt8((value >> 8) & 0xFF),
        UInt8(value & 0xFF),
    ]
}

private func uint32Bytes(_ value: Int) -> [UInt8] {
    [
        UInt8((value >> 24) & 0xFF),
        UInt8((value >> 16) & 0xFF),
        UInt8((value >> 8) & 0xFF),
        UInt8(value & 0xFF),
    ]
}
