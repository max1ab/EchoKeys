import Foundation
import Testing
@testable import PianoPracticeCore

@Suite struct PianoPracticeCoreTests {
    @Test func noteEventInitializesFields() {
        let annotation = TargetAnnotation(
            voiceID: "right",
            hand: .right,
            measureIndex: 2,
            segmentID: "intro",
            sources: [
                EventSource(
                    trackIndex: 1,
                    channel: 3,
                    sourceTick: 480,
                    sourceDurationTick: 240,
                    voiceID: "right",
                    hand: .right
                ),
            ]
        )

        let event = NoteEvent(
            id: "note-1",
            pitch: 60,
            onsetBeat: 1.5,
            durationBeat: 0.5,
            velocity: 88,
            trackIndex: 1,
            channel: 3,
            sourceTick: 480,
            sourceDurationTick: 240,
            annotations: annotation
        )

        #expect(event.id == "note-1")
        #expect(event.pitch == 60)
        #expect(event.onsetBeat == 1.5)
        #expect(event.durationBeat == 0.5)
        #expect(event.velocity == 88)
        #expect(event.trackIndex == 1)
        #expect(event.channel == 3)
        #expect(event.sourceTick == 480)
        #expect(event.sourceDurationTick == 240)
        #expect(event.annotations == annotation)
    }

    @Test func noteEventCodableRoundTrip() throws {
        let event = NoteEvent(
            id: "note-1",
            pitch: 64,
            onsetBeat: 2,
            durationBeat: 1,
            velocity: 72,
            annotations: TargetAnnotation(
                voiceID: "left",
                hand: .left,
                measureIndex: 4,
                segmentID: "phrase-a",
                sources: [EventSource(trackIndex: 0, channel: 0)]
            )
        )

        let data = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(NoteEvent.self, from: data)

        #expect(decoded == event)
    }

    @Test func targetAnnotationMergePreservesExistingValuesAndAppendsSources() {
        let first = TargetAnnotation(
            voiceID: "right",
            hand: .right,
            measureIndex: 1,
            segmentID: nil,
            sources: [EventSource(trackIndex: 0, channel: 0)]
        )
        let second = TargetAnnotation(
            voiceID: "fallback",
            hand: .left,
            measureIndex: 2,
            segmentID: "segment",
            sources: [EventSource(trackIndex: 1, channel: 1)]
        )

        let merged = first.merged(with: second)

        #expect(merged.voiceID == "right")
        #expect(merged.hand == .right)
        #expect(merged.measureIndex == 1)
        #expect(merged.segmentID == "segment")
        #expect(merged.sources.count == 2)
        #expect(merged.sources[0].trackIndex == 0)
        #expect(merged.sources[1].trackIndex == 1)
    }
}
