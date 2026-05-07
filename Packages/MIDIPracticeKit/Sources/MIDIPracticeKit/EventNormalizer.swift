import Foundation

enum EventNormalizer {
    static func normalizeTargetDuplicates(
        _ events: [NoteEvent],
        epsilon: Double
    ) -> [NoteEvent] {
        let sorted = events.practiceSorted()
        var result: [NoteEvent] = []

        for event in sorted {
            if let lastIndex = result.indices.last,
               result[lastIndex].pitch == event.pitch,
               abs(result[lastIndex].onsetBeat - event.onsetBeat) <= epsilon {
                result[lastIndex] = merge(result[lastIndex], with: event)
            } else {
                result.append(event)
            }
        }

        return result
    }

    private static func merge(_ first: NoteEvent, with second: NoteEvent) -> NoteEvent {
        var merged = first
        merged.durationBeat = max(first.durationBeat, second.durationBeat)
        merged.velocity = max(first.velocity, second.velocity)
        let firstAnnotation = first.annotations ?? TargetAnnotation(sources: [
            EventSource(
                trackIndex: first.trackIndex,
                channel: first.channel,
                sourceTick: first.sourceTick,
                sourceDurationTick: first.sourceDurationTick
            )
        ])
        let secondAnnotation = second.annotations ?? TargetAnnotation(sources: [
            EventSource(
                trackIndex: second.trackIndex,
                channel: second.channel,
                sourceTick: second.sourceTick,
                sourceDurationTick: second.sourceDurationTick
            )
        ])
        merged.annotations = firstAnnotation.merged(with: secondAnnotation)
        return merged
    }
}
