import PianoPracticeCore

struct PerformanceTimingEstimator {
    var configuration: MIDIPracticeConfiguration

    func estimate(target: [NoteEvent], performance: [NoteEvent]) -> PerformanceTimingEstimate {
        let target = target.practiceSorted()
        let performance = performance.practiceSorted()
        guard !target.isEmpty, !performance.isEmpty else {
            return PerformanceTimingEstimate(offsetBeat: 0, tempoScale: 1)
        }

        var usedPerformance = Set<String>()
        var anchors: [(target: NoteEvent, performance: NoteEvent)] = []

        for targetEvent in target {
            let candidates = performance
                .filter { $0.pitch == targetEvent.pitch && !usedPerformance.contains($0.id) }
                .sorted {
                    abs(($0.onsetBeat - targetEvent.onsetBeat)) < abs(($1.onsetBeat - targetEvent.onsetBeat))
                }

            guard let best = candidates.first else { continue }
            usedPerformance.insert(best.id)
            anchors.append((targetEvent, best))
        }

        guard !anchors.isEmpty else {
            return PerformanceTimingEstimate(
                offsetBeat: performance[0].onsetBeat - target[0].onsetBeat,
                tempoScale: 1
            )
        }

        let tempoScale = estimateTempoScale(from: anchors)
        let offsetAnchors = Array(anchors.prefix(configuration.offsetAnchorCount))
        let offsets = offsetAnchors.map { anchor in
            anchor.performance.onsetBeat - anchor.target.onsetBeat * tempoScale
        }

        return PerformanceTimingEstimate(
            offsetBeat: median(offsets),
            tempoScale: tempoScale
        )
    }

    private func estimateTempoScale(from anchors: [(target: NoteEvent, performance: NoteEvent)]) -> Double {
        guard anchors.count >= 2 else { return 1 }

        var ratios: [Double] = []
        for index in 1..<anchors.count {
            let targetIOI = anchors[index].target.onsetBeat - anchors[index - 1].target.onsetBeat
            let performanceIOI = anchors[index].performance.onsetBeat - anchors[index - 1].performance.onsetBeat
            guard targetIOI > 0, performanceIOI > 0 else { continue }

            let ratio = performanceIOI / targetIOI
            guard ratio >= configuration.minTempoScale,
                  ratio <= configuration.maxTempoScale else { continue }
            ratios.append(ratio)
        }

        guard ratios.count >= 3 else { return 1 }
        return median(ratios)
    }

    private func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }
        return sorted[middle]
    }
}

struct PerformanceTimingEstimate {
    var offsetBeat: Double
    var tempoScale: Double
}
