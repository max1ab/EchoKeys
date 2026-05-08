import Foundation

public struct MIDIPracticeKit: Sendable {
    public init() {}

    public func score(
        targetEvents: [NoteEvent],
        performanceEvents: [NoteEvent],
        annotations: [String: TargetAnnotation]? = nil,
        configuration: MIDIPracticeConfiguration = .default
    ) throws -> MIDIPracticeReport {
        guard !targetEvents.isEmpty else {
            throw MIDIPracticeError.emptyInput("targetEvents is empty")
        }

        let annotatedTargets = applyAnnotations(annotations, to: targetEvents)
        let normalizedTargets = EventNormalizer.normalizeTargetDuplicates(
            annotatedTargets,
            epsilon: configuration.duplicateEpsilonBeat
        )
        let sortedTargets = normalizedTargets.practiceSorted()
        let sortedPerformance = performanceEvents.practiceSorted()
        let alignment = DynamicNoteAligner(configuration: configuration)
            .align(target: sortedTargets, performance: sortedPerformance)
        return ReportBuilder(configuration: configuration).build(
            target: sortedTargets,
            performance: sortedPerformance,
            alignment: alignment,
            warnings: [],
            estimatedOffsetBeat: 0,
            estimatedTempoScale: 1
        )
    }

    public func score(
        targetMIDI: Data,
        performanceMIDI: Data,
        targetJTF: String? = nil,
        configuration: MIDIPracticeConfiguration = .default
    ) throws -> MIDIPracticeReport {
        let targetConversion = try MIDIEventConverter(prefix: "target").convert(targetMIDI)
        let performanceConversion = try MIDIEventConverter(prefix: "performance").convert(performanceMIDI)

        var warnings = targetConversion.warnings + performanceConversion.warnings
        var targetEvents = EventNormalizer.normalizeTargetDuplicates(
            targetConversion.events,
            epsilon: configuration.duplicateEpsilonBeat
        )

        if let targetJTF {
            let result = JTFAnnotationExtractor().extract(from: targetJTF)
            warnings.append(contentsOf: result.warnings)
            targetEvents = JTFAnnotationApplier().apply(
                result.annotations,
                to: targetEvents,
                warnings: &warnings
            )
        }

        let timing = PerformanceTimingEstimator(configuration: configuration)
            .estimate(target: targetEvents, performance: performanceConversion.events)
        let adjustedPerformance = performanceConversion.events.map { event in
            var copy = event
            copy.onsetBeat = (copy.onsetBeat - timing.offsetBeat) / timing.tempoScale
            copy.durationBeat /= timing.tempoScale
            return copy
        }

        let alignment = DynamicNoteAligner(configuration: configuration)
            .align(target: targetEvents.practiceSorted(), performance: adjustedPerformance.practiceSorted())

        return ReportBuilder(configuration: configuration).build(
            target: targetEvents.practiceSorted(),
            performance: adjustedPerformance.practiceSorted(),
            alignment: alignment,
            warnings: warnings,
            estimatedOffsetBeat: timing.offsetBeat,
            estimatedTempoScale: timing.tempoScale
        )
    }

    private func applyAnnotations(
        _ annotations: [String: TargetAnnotation]?,
        to events: [NoteEvent]
    ) -> [NoteEvent] {
        guard let annotations else { return events }
        return events.map { event in
            var copy = event
            if let annotation = annotations[event.id] {
                copy.annotations = annotation
            }
            return copy
        }
    }
}

extension Array where Element == NoteEvent {
    func practiceSorted() -> [NoteEvent] {
        sorted {
            if $0.onsetBeat != $1.onsetBeat { return $0.onsetBeat < $1.onsetBeat }
            if $0.pitch != $1.pitch { return $0.pitch < $1.pitch }
            if $0.trackIndex != $1.trackIndex { return $0.trackIndex < $1.trackIndex }
            if $0.channel != $1.channel { return $0.channel < $1.channel }
            return $0.id < $1.id
        }
    }
}
