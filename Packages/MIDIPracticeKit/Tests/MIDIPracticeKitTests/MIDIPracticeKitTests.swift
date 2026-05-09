import XCTest
@testable import MIDIPracticeKit

final class MIDIPracticeKitTests: XCTestCase {
    func testPerfectEventPerformanceScoresFullCredit() throws {
        let kit = MIDIPracticeKit()
        let target = [
            event("t0", 60, 0),
            event("t1", 64, 1),
            event("t2", 67, 2),
        ]
        let performance = [
            event("p0", 60, 0),
            event("p1", 64, 1),
            event("p2", 67, 2),
        ]

        let report = try kit.score(targetEvents: target, performanceEvents: performance)

        XCTAssertEqual(report.level1.matchedCount, 3)
        XCTAssertEqual(report.level1.missedCount, 0)
        XCTAssertEqual(report.level1.extraCount, 0)
        XCTAssertEqual(report.level1.wrongPitchCount, 0)
        XCTAssertEqual(report.level1.pitchAccuracy, 1)
        XCTAssertEqual(report.level2.onsetTimingScore, 1)
    }

    func testWrongPitchNearTargetIsSubstitutionNotMissedPlusExtra() throws {
        let kit = MIDIPracticeKit()
        let report = try kit.score(
            targetEvents: [event("t0", 60, 0)],
            performanceEvents: [event("p0", 61, 0.02)]
        )

        XCTAssertEqual(report.level1.wrongPitchCount, 1)
        XCTAssertEqual(report.level1.missedCount, 0)
        XCTAssertEqual(report.level1.extraCount, 0)
        XCTAssertEqual(report.level1.completeness, 0)
        XCTAssertEqual(report.errors.map(\.type), [.wrongPitch])
    }

    func testMissedAndExtraNotesAreReported() throws {
        let kit = MIDIPracticeKit()
        let report = try kit.score(
            targetEvents: [event("t0", 60, 0), event("t1", 64, 1)],
            performanceEvents: [event("p0", 60, 0), event("p1", 67, 3)]
        )

        XCTAssertEqual(report.level1.matchedCount, 1)
        XCTAssertEqual(report.level1.missedCount, 1)
        XCTAssertEqual(report.level1.extraCount, 1)
        XCTAssertEqual(report.errors.map(\.type).sorted { $0.rawValue < $1.rawValue }, [.extraNote, .missedNote])
    }

    func testTargetDuplicateSamePitchSameOnsetIsMerged() throws {
        let kit = MIDIPracticeKit()
        let target = [
            event("t0", 60, 0, track: 0),
            event("t1", 60, 0, track: 1),
        ]

        let report = try kit.score(
            targetEvents: target,
            performanceEvents: [event("p0", 60, 0)]
        )

        XCTAssertEqual(report.targetEvents.count, 1)
        XCTAssertEqual(report.level1.matchedCount, 1)
        XCTAssertEqual(report.level1.missedCount, 0)
        XCTAssertEqual(report.targetEvents[0].annotations?.sources.count, 2)
    }

    func testMIDIWrapperEstimatesStartOffset() throws {
        let kit = MIDIPracticeKit()
        let target = TestMIDIFile(ticksPerQuarter: 480, notes: [
            TestNote(pitch: 60, start: 0, duration: 480),
            TestNote(pitch: 64, start: 480, duration: 480),
            TestNote(pitch: 67, start: 960, duration: 480),
        ]).data()
        let performance = TestMIDIFile(ticksPerQuarter: 480, notes: [
            TestNote(pitch: 60, start: 240, duration: 480),
            TestNote(pitch: 64, start: 720, duration: 480),
            TestNote(pitch: 67, start: 1200, duration: 480),
        ]).data()

        let report = try kit.score(targetMIDI: target, performanceMIDI: performance)

        XCTAssertEqual(report.estimatedOffsetBeat, 0.5, accuracy: 0.0001)
        XCTAssertEqual(report.level1.matchedCount, 3)
        XCTAssertEqual(report.level2.onsetTimingScore, 1)
    }

    func testMIDIParserTreatsVelocityZeroAsNoteOffAndRunningStatus() throws {
        let kit = MIDIPracticeKit()
        let midi = TestMIDIFile(
            ticksPerQuarter: 480,
            rawTrackBytes: [
                0x00, 0x90, 60, 80,
                0x83, 0x60, 60, 0,
                0x00, 0xFF, 0x2F, 0x00,
            ]
        ).data()

        let report = try kit.score(targetMIDI: midi, performanceMIDI: midi)

        XCTAssertEqual(report.targetEvents.count, 1)
        XCTAssertEqual(report.targetEvents[0].durationBeat, 1, accuracy: 0.0001)
        XCTAssertEqual(report.level1.matchedCount, 1)
    }

    func testDifferentPPQConvertsToSameBeatCoordinates() throws {
        let kit = MIDIPracticeKit()
        let target = TestMIDIFile(ticksPerQuarter: 480, notes: [
            TestNote(pitch: 60, start: 480, duration: 480),
        ]).data()
        let performance = TestMIDIFile(ticksPerQuarter: 960, notes: [
            TestNote(pitch: 60, start: 960, duration: 960),
        ]).data()

        let report = try kit.score(targetMIDI: target, performanceMIDI: performance)

        XCTAssertEqual(report.targetEvents[0].onsetBeat, 1, accuracy: 0.0001)
        XCTAssertEqual(report.performanceEvents[0].onsetBeat, 1, accuracy: 0.0001)
        XCTAssertEqual(report.level1.matchedCount, 1)
    }

    func testMIDIWrapperEstimatesTempoScale() throws {
        let kit = MIDIPracticeKit()
        let target = TestMIDIFile(ticksPerQuarter: 480, notes: [
            TestNote(pitch: 60, start: 0, duration: 480),
            TestNote(pitch: 62, start: 480, duration: 480),
            TestNote(pitch: 64, start: 960, duration: 480),
            TestNote(pitch: 65, start: 1440, duration: 480),
        ]).data()
        let performance = TestMIDIFile(ticksPerQuarter: 480, notes: [
            TestNote(pitch: 60, start: 0, duration: 432),
            TestNote(pitch: 62, start: 432, duration: 432),
            TestNote(pitch: 64, start: 864, duration: 432),
            TestNote(pitch: 65, start: 1296, duration: 432),
        ]).data()

        let report = try kit.score(targetMIDI: target, performanceMIDI: performance)

        XCTAssertEqual(report.estimatedTempoScale, 0.9, accuracy: 0.0001)
        XCTAssertEqual(report.level1.matchedCount, 4)
        XCTAssertEqual(report.level2.onsetTimingScore, 1, accuracy: 0.0001)
        XCTAssertEqual(report.level2.durationScore, 1, accuracy: 0.0001)
    }

    func testUnclosedMIDINoteProducesWarningAndDoesNotCrash() throws {
        let kit = MIDIPracticeKit()
        let good = TestMIDIFile(ticksPerQuarter: 480, notes: [
            TestNote(pitch: 60, start: 0, duration: 480),
        ]).data()
        let unclosed = TestMIDIFile(
            ticksPerQuarter: 480,
            rawTrackBytes: [
                0x00, 0x90, 60, 80,
                0x00, 0xFF, 0x2F, 0x00,
            ]
        ).data()

        let report = try kit.score(targetMIDI: good, performanceMIDI: unclosed)

        XCTAssertTrue(report.warnings.contains { $0.contains("unclosed") })
        XCTAssertEqual(report.level1.missedCount, 1)
    }

    func testSMPTETimeDivisionThrows() {
        var bytes: [UInt8] = []
        bytes.append(contentsOf: Array("MThd".utf8))
        bytes.append(contentsOf: be32(6))
        bytes.append(contentsOf: be16(0))
        bytes.append(contentsOf: be16(1))
        bytes.append(contentsOf: be16(0xE250))

        XCTAssertThrowsError(try MIDIPracticeKit().score(
            targetMIDI: Data(bytes),
            performanceMIDI: Data(bytes)
        ))
    }

    func testJTFAnnotationFailureIsWarningOnly() throws {
        let kit = MIDIPracticeKit()
        let midi = TestMIDIFile(ticksPerQuarter: 480, notes: [
            TestNote(pitch: 60, start: 0, duration: 480),
            TestNote(pitch: 64, start: 480, duration: 480),
        ]).data()

        let report = try kit.score(
            targetMIDI: midi,
            performanceMIDI: midi,
            targetJTF: """
            1=C 4/4 120
            V:Right
            | 1 ||
            """
        )

        XCTAssertEqual(report.level1.matchedCount, 2)
        XCTAssertTrue(report.warnings.contains { $0.contains("does not match") })
        XCTAssertEqual(report.targetEvents[0].annotations?.hand, .right)
    }

    private func event(
        _ id: String,
        _ pitch: Int,
        _ onset: Double,
        duration: Double = 1,
        track: Int = 0
    ) -> NoteEvent {
        NoteEvent(
            id: id,
            pitch: pitch,
            onsetBeat: onset,
            durationBeat: duration,
            velocity: 80,
            trackIndex: track,
            channel: 0
        )
    }
}

private struct TestNote {
    var pitch: UInt8
    var start: Int
    var duration: Int
    var velocity: UInt8 = 80
}

private struct TestMIDIFile {
    var ticksPerQuarter: Int
    var notes: [TestNote] = []
    var rawTrackBytes: [UInt8]?

    func data() -> Data {
        let trackBytes = rawTrackBytes ?? buildTrack()
        var bytes: [UInt8] = []
        bytes.append(contentsOf: Array("MThd".utf8))
        bytes.append(contentsOf: be32(6))
        bytes.append(contentsOf: be16(0))
        bytes.append(contentsOf: be16(1))
        bytes.append(contentsOf: be16(ticksPerQuarter))
        bytes.append(contentsOf: Array("MTrk".utf8))
        bytes.append(contentsOf: be32(trackBytes.count))
        bytes.append(contentsOf: trackBytes)
        return Data(bytes)
    }

    private func buildTrack() -> [UInt8] {
        struct Message {
            var tick: Int
            var bytes: [UInt8]
            var order: Int
        }

        var messages: [Message] = []
        for (index, note) in notes.enumerated() {
            messages.append(Message(tick: note.start, bytes: [0x90, note.pitch, note.velocity], order: index * 2))
            messages.append(Message(tick: note.start + note.duration, bytes: [0x80, note.pitch, 0], order: index * 2 + 1))
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
