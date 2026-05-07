import Foundation

struct PerformanceOffsetEstimator {
    var configuration: MIDIPracticeConfiguration

    func estimate(target: [NoteEvent], performance: [NoteEvent]) -> Double {
        let target = target.practiceSorted()
        let performance = performance.practiceSorted()
        guard !target.isEmpty, !performance.isEmpty else { return 0 }

        var usedPerformance = Set<String>()
        var deltas: [Double] = []

        for targetEvent in target {
            guard deltas.count < configuration.offsetAnchorCount else { break }
            let candidates = performance
                .filter { $0.pitch == targetEvent.pitch && !usedPerformance.contains($0.id) }
                .sorted {
                    abs(($0.onsetBeat - targetEvent.onsetBeat)) < abs(($1.onsetBeat - targetEvent.onsetBeat))
                }

            guard let best = candidates.first else { continue }
            usedPerformance.insert(best.id)
            deltas.append(best.onsetBeat - targetEvent.onsetBeat)
        }

        if deltas.isEmpty {
            return performance[0].onsetBeat - target[0].onsetBeat
        }

        return median(deltas)
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
