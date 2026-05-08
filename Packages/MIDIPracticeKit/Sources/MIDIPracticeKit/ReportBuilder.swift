import Foundation

struct ReportBuilder {
    var configuration: MIDIPracticeConfiguration

    func build(
        target: [NoteEvent],
        performance: [NoteEvent],
        alignment: [AlignmentItem],
        warnings: [String],
        estimatedOffsetBeat: Double,
        estimatedTempoScale: Double
    ) -> MIDIPracticeReport {
        let errors = buildErrors(from: alignment, target: target, performance: performance)
        return MIDIPracticeReport(
            targetEvents: target,
            performanceEvents: performance,
            alignment: alignment,
            level1: buildLevel1(targetCount: target.count, alignment: alignment),
            level2: buildLevel2(alignment: alignment),
            level3: .placeholder,
            summaries: buildSummaries(target: target, alignment: alignment),
            errors: errors,
            warnings: warnings,
            estimatedOffsetBeat: estimatedOffsetBeat,
            estimatedTempoScale: estimatedTempoScale
        )
    }

    private func buildLevel1(targetCount: Int, alignment: [AlignmentItem]) -> Level1Score {
        let matched = alignment.filter { $0.kind == .matched }.count
        let missed = alignment.filter { $0.kind == .missed }.count
        let extra = alignment.filter { $0.kind == .extra }.count
        let wrong = alignment.filter { $0.kind == .wrongPitch }.count
        let targetDenominator = max(targetCount, 1)
        let totalDenominator = max(targetCount + extra, 1)

        return Level1Score(
            pitchAccuracy: clamp01(Double(matched) / Double(totalDenominator)),
            completeness: clamp01(Double(matched + wrong) / Double(targetDenominator)),
            matchedCount: matched,
            missedCount: missed,
            extraCount: extra,
            wrongPitchCount: wrong
        )
    }

    private func buildLevel2(alignment: [AlignmentItem]) -> Level2Score {
        let paired = alignment.filter { $0.kind == .matched || $0.kind == .wrongPitch }
        let onsetDeltas = paired.compactMap(\.onsetDelta)
        let durationDeltas = paired.compactMap(\.durationDelta)
        let early = onsetDeltas.filter { $0 < -configuration.onsetToleranceBeat }.count
        let late = onsetDeltas.filter { $0 > configuration.onsetToleranceBeat }.count
        let average = onsetDeltas.isEmpty ? 0 : onsetDeltas.reduce(0, +) / Double(onsetDeltas.count)
        let maxDelta = onsetDeltas.map { abs($0) }.max() ?? 0

        return Level2Score(
            onsetTimingScore: toleranceScore(values: onsetDeltas, tolerance: configuration.onsetToleranceBeat),
            interOnsetScore: interOnsetScore(alignment: paired),
            durationScore: toleranceScore(values: durationDeltas, tolerance: configuration.durationToleranceBeat),
            earlyCount: early,
            lateCount: late,
            averageOnsetDelta: average,
            maxOnsetDelta: maxDelta
        )
    }

    private func toleranceScore(values: [Double], tolerance: Double) -> Double {
        guard !values.isEmpty else { return 0 }
        let normalized = values.map { min(abs($0) / max(tolerance, 0.0001), 2) / 2 }
        return clamp01(1 - normalized.reduce(0, +) / Double(normalized.count))
    }

    private func interOnsetScore(alignment: [AlignmentItem]) -> Double {
        guard alignment.count >= 2 else {
            return alignment.isEmpty ? 0 : 1
        }

        var diffs: [Double] = []
        for index in 1..<alignment.count {
            guard let previous = alignment[index - 1].onsetDelta,
                  let current = alignment[index].onsetDelta else { continue }
            diffs.append(current - previous)
        }
        return toleranceScore(values: diffs, tolerance: configuration.onsetToleranceBeat)
    }

    private func buildSummaries(target: [NoteEvent], alignment: [AlignmentItem]) -> [PracticeSummary] {
        let targetByID = Dictionary(uniqueKeysWithValues: target.map { ($0.id, $0) })
        var groups: [SummaryKey: [AlignmentItem]] = [:]

        for item in alignment {
            let event = item.targetEventID.flatMap { targetByID[$0] }
            let key = SummaryKey(
                measureIndex: event?.annotations?.measureIndex,
                segmentID: event?.annotations?.segmentID
            )
            groups[key, default: []].append(item)
        }

        return groups
            .map { key, items in
                let deltas = items.compactMap(\.onsetDelta)
                return PracticeSummary(
                    measureIndex: key.measureIndex,
                    segmentID: key.segmentID,
                    missedCount: items.filter { $0.kind == .missed }.count,
                    extraCount: items.filter { $0.kind == .extra }.count,
                    wrongPitchCount: items.filter { $0.kind == .wrongPitch }.count,
                    averageOnsetDelta: deltas.isEmpty ? nil : deltas.reduce(0, +) / Double(deltas.count)
                )
            }
            .sorted {
                ($0.measureIndex ?? Int.max, $0.segmentID ?? "") < ($1.measureIndex ?? Int.max, $1.segmentID ?? "")
            }
    }

    private func buildErrors(
        from alignment: [AlignmentItem],
        target: [NoteEvent],
        performance: [NoteEvent]
    ) -> [PracticeErrorItem] {
        let targetByID = Dictionary(uniqueKeysWithValues: target.map { ($0.id, $0) })
        let performanceByID = Dictionary(uniqueKeysWithValues: performance.map { ($0.id, $0) })

        return alignment.compactMap { item in
            switch item.kind {
            case .matched:
                return nil
            case .missed:
                let targetEvent = item.targetEventID.flatMap { targetByID[$0] }
                return PracticeErrorItem(
                    id: "error-\(item.id)",
                    type: .missedNote,
                    severity: .critical,
                    targetEventID: item.targetEventID,
                    performanceEventID: nil,
                    message: "Missed pitch \(targetEvent?.pitch ?? -1)"
                )
            case .extra:
                let performanceEvent = item.performanceEventID.flatMap { performanceByID[$0] }
                return PracticeErrorItem(
                    id: "error-\(item.id)",
                    type: .extraNote,
                    severity: .warning,
                    targetEventID: nil,
                    performanceEventID: item.performanceEventID,
                    message: "Extra pitch \(performanceEvent?.pitch ?? -1)"
                )
            case .wrongPitch:
                let targetEvent = item.targetEventID.flatMap { targetByID[$0] }
                let performanceEvent = item.performanceEventID.flatMap { performanceByID[$0] }
                return PracticeErrorItem(
                    id: "error-\(item.id)",
                    type: .wrongPitch,
                    severity: .critical,
                    targetEventID: item.targetEventID,
                    performanceEventID: item.performanceEventID,
                    message: "Expected pitch \(targetEvent?.pitch ?? -1), got \(performanceEvent?.pitch ?? -1)"
                )
            }
        }
    }

    private func clamp01(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }

    private struct SummaryKey: Hashable {
        var measureIndex: Int?
        var segmentID: String?
    }
}
