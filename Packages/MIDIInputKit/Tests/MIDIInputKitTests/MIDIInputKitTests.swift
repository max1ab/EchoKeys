import Foundation
import MIDIPracticeKit
import PianoPracticeCore
import Testing
@testable import MIDIInputKit

@Suite struct MIDIInputKitTests {
    @Test func noteOnAndNoteOffGenerateNoteEvent() throws {
        let recording = try buildRecording(messages: [
            noteOn(time: 10.0, pitch: 60, velocity: 82),
            noteOff(time: 10.5, pitch: 60),
        ])

        #expect(recording.notes.count == 1)
        let note = try #require(recording.notes.first)
        #expect(note.id == "test-000000")
        #expect(note.pitch == 60)
        #expect(note.velocity == 82)
        #expect(note.channel == 0)
        #expect(note.trackIndex == 0)
        #expect(note.sourceTick == nil)
        #expect(note.sourceDurationTick == nil)
        #expect(note.onsetBeat == 0)
        #expect(note.durationBeat == 1)
        #expect(recording.warnings.isEmpty)
    }

    @Test func firstNoteOnDefinesZeroBeat() throws {
        let recording = try buildRecording(messages: [
            noteOn(time: 10.0, pitch: 60),
            noteOff(time: 10.5, pitch: 60),
            noteOn(time: 11.0, pitch: 64),
            noteOff(time: 11.5, pitch: 64),
        ])

        #expect(recording.notes.map(\.onsetBeat) == [0, 2])
    }

    @Test func halfSecondAt120BPMIsOneBeat() throws {
        let recording = try buildRecording(messages: [
            noteOn(time: 0.0, pitch: 60),
            noteOff(time: 0.5, pitch: 60),
        ], tempoBPM: 120)

        #expect(recording.notes[0].durationBeat == 1)
    }

    @Test func velocityZeroNoteOnActsAsNoteOff() throws {
        let recording = try buildRecording(messages: [
            noteOn(time: 0.0, pitch: 60, velocity: 90),
            noteOn(time: 0.5, pitch: 60, velocity: 0),
        ])

        #expect(recording.notes.count == 1)
        #expect(recording.notes[0].durationBeat == 1)
    }

    @Test func overlappingSamePitchAndChannelUsesFIFO() throws {
        let recording = try buildRecording(messages: [
            noteOn(time: 0.0, pitch: 60, velocity: 70),
            noteOn(time: 0.25, pitch: 60, velocity: 80),
            noteOff(time: 0.5, pitch: 60),
            noteOff(time: 0.75, pitch: 60),
        ])

        #expect(recording.notes.count == 2)
        #expect(recording.notes[0].velocity == 70)
        #expect(recording.notes[0].onsetBeat == 0)
        #expect(recording.notes[0].durationBeat == 1)
        #expect(recording.notes[1].velocity == 80)
        #expect(recording.notes[1].onsetBeat == 0.5)
        #expect(recording.notes[1].durationBeat == 1)
    }

    @Test func unmatchedNoteOffProducesWarning() throws {
        let recording = try buildRecording(messages: [
            noteOff(time: 0.0, pitch: 60),
        ])

        #expect(recording.notes.isEmpty)
        #expect(recording.warnings.count == 1)
        #expect(recording.warnings[0].contains("unmatched noteOff"))
    }

    @Test func unclosedNoteOnIsDiscardedWithWarning() throws {
        let recording = try buildRecording(messages: [
            noteOn(time: 0.0, pitch: 60),
        ])

        #expect(recording.notes.isEmpty)
        #expect(recording.warnings.count == 1)
        #expect(recording.warnings[0].contains("unclosed note"))
    }

    @Test func exportMIDIDataCreatesParseableSMF() throws {
        let recording = try buildRecording(messages: [
            noteOn(time: 0.0, pitch: 60),
            noteOff(time: 0.5, pitch: 60),
            noteOn(time: 0.5, pitch: 64),
            noteOff(time: 1.0, pitch: 64),
        ])

        let data = try recording.exportMIDIData()
        #expect(String(bytes: data.prefix(4), encoding: .ascii) == "MThd")
        #expect(String(bytes: data.dropFirst(14).prefix(4), encoding: .ascii) == "MTrk")

        let report = try MIDIPracticeKit().score(targetMIDI: data, performanceMIDI: data)
        #expect(report.level1.matchedCount == 2)
        #expect(report.level1.missedCount == 0)
        #expect(report.level1.extraCount == 0)
    }

    @Test func invalidOptionsThrow() throws {
        #expect(throws: MIDIInputError.invalidTempo(0)) {
            _ = try MIDIInputRecordingBuilder(options: MIDIInputRecordingOptions(tempoBPM: 0))
        }
        #expect(throws: MIDIInputError.invalidTicksPerBeat(0)) {
            _ = try MIDIInputRecordingBuilder(options: MIDIInputRecordingOptions(tempoBPM: 120, ticksPerBeat: 0))
        }
    }

    private func buildRecording(
        messages: [MIDIInputNoteMessage],
        tempoBPM: Double = 120
    ) throws -> MIDIInputRecording {
        let builder = try MIDIInputRecordingBuilder(
            options: MIDIInputRecordingOptions(
                tempoBPM: tempoBPM,
                idPrefix: "test"
            )
        )
        messages.forEach(builder.record)
        return builder.finish()
    }

    private func noteOn(
        time: Double,
        channel: UInt8 = 0,
        pitch: UInt8,
        velocity: UInt8 = 80
    ) -> MIDIInputNoteMessage {
        MIDIInputNoteMessage(
            timestampSeconds: time,
            status: 0x90 | channel,
            data1: pitch,
            data2: velocity
        )
    }

    private func noteOff(
        time: Double,
        channel: UInt8 = 0,
        pitch: UInt8
    ) -> MIDIInputNoteMessage {
        MIDIInputNoteMessage(
            timestampSeconds: time,
            status: 0x80 | channel,
            data1: pitch,
            data2: 0
        )
    }
}
