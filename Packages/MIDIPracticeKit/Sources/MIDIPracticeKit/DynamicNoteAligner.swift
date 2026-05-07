import Foundation

struct DynamicNoteAligner {
    var configuration: MIDIPracticeConfiguration

    func align(target: [NoteEvent], performance: [NoteEvent]) -> [AlignmentItem] {
        let target = target.practiceSorted()
        let performance = performance.practiceSorted()
        let rowCount = target.count + 1
        let columnCount = performance.count + 1
        var cost = Array(
            repeating: Array(repeating: Double.infinity, count: columnCount),
            count: rowCount
        )
        var back = Array(
            repeating: Array(repeating: Step.none, count: columnCount),
            count: rowCount
        )
        cost[0][0] = 0

        if !target.isEmpty {
            for i in 1...target.count {
                cost[i][0] = cost[i - 1][0] + configuration.deleteCost
                back[i][0] = .delete
            }
        }
        if !performance.isEmpty {
            for j in 1...performance.count {
                cost[0][j] = cost[0][j - 1] + configuration.insertCost
                back[0][j] = .insert
            }
        }

        if !target.isEmpty, !performance.isEmpty {
            for i in 1...target.count {
                for j in 1...performance.count {
                    let deleteCost = cost[i - 1][j] + configuration.deleteCost
                    if deleteCost < cost[i][j] {
                        cost[i][j] = deleteCost
                        back[i][j] = .delete
                    }

                    let insertCost = cost[i][j - 1] + configuration.insertCost
                    if insertCost < cost[i][j] {
                        cost[i][j] = insertCost
                        back[i][j] = .insert
                    }

                    if let pairCost = pairCost(target[i - 1], performance[j - 1]) {
                        let total = cost[i - 1][j - 1] + pairCost.cost
                        if total < cost[i][j] {
                            cost[i][j] = total
                            back[i][j] = pairCost.kind == .matched ? .match : .wrongPitch
                        }
                    }
                }
            }
        }

        var items: [AlignmentItem] = []
        var i = target.count
        var j = performance.count

        while i > 0 || j > 0 {
            switch back[i][j] {
            case .match, .wrongPitch:
                let kind: AlignmentKind = back[i][j] == .match ? .matched : .wrongPitch
                let targetEvent = target[i - 1]
                let performanceEvent = performance[j - 1]
                items.append(AlignmentItem(
                    id: "alignment-\(items.count)",
                    kind: kind,
                    targetEventID: targetEvent.id,
                    performanceEventID: performanceEvent.id,
                    onsetDelta: performanceEvent.onsetBeat - targetEvent.onsetBeat,
                    durationDelta: performanceEvent.durationBeat - targetEvent.durationBeat
                ))
                i -= 1
                j -= 1
            case .delete:
                items.append(AlignmentItem(
                    id: "alignment-\(items.count)",
                    kind: .missed,
                    targetEventID: target[i - 1].id,
                    performanceEventID: nil,
                    onsetDelta: nil,
                    durationDelta: nil
                ))
                i -= 1
            case .insert:
                items.append(AlignmentItem(
                    id: "alignment-\(items.count)",
                    kind: .extra,
                    targetEventID: nil,
                    performanceEventID: performance[j - 1].id,
                    onsetDelta: nil,
                    durationDelta: nil
                ))
                j -= 1
            case .none:
                if i > 0 {
                    items.append(AlignmentItem(
                        id: "alignment-\(items.count)",
                        kind: .missed,
                        targetEventID: target[i - 1].id,
                        performanceEventID: nil,
                        onsetDelta: nil,
                        durationDelta: nil
                    ))
                    i -= 1
                } else if j > 0 {
                    items.append(AlignmentItem(
                        id: "alignment-\(items.count)",
                        kind: .extra,
                        targetEventID: nil,
                        performanceEventID: performance[j - 1].id,
                        onsetDelta: nil,
                        durationDelta: nil
                    ))
                    j -= 1
                }
            }
        }

        return items.reversed().enumerated().map { index, item in
            var copy = item
            copy.id = "alignment-\(String(format: "%06d", index))"
            return copy
        }
    }

    private func pairCost(_ target: NoteEvent, _ performance: NoteEvent) -> (cost: Double, kind: AlignmentKind)? {
        let onsetDelta = abs(performance.onsetBeat - target.onsetBeat)
        guard onsetDelta <= configuration.maxMatchWindowBeat else { return nil }

        let durationDelta = abs(performance.durationBeat - target.durationBeat)
        let timingCost = min(onsetDelta / max(configuration.onsetToleranceBeat, 0.0001), 4) * 0.25
        let durationCost = min(durationDelta / max(configuration.durationToleranceBeat, 0.0001), 4) * 0.1

        if target.pitch == performance.pitch {
            return (timingCost + durationCost, .matched)
        }

        return (configuration.wrongPitchCost + timingCost + durationCost + configuration.pitchMismatchPenalty, .wrongPitch)
    }

    private enum Step: Equatable {
        case none
        case match
        case wrongPitch
        case insert
        case delete
    }
}
