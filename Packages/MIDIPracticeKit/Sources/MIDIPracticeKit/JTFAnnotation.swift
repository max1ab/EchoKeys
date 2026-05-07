import Foundation

struct JTFAnnotationExtractor {
    func extract(from text: String) -> JTFAnnotationExtraction {
        var annotations: [JTFPositionalAnnotation] = []
        var warnings: [String] = []
        var currentVoice: String?
        var currentMeasure = -1

        let lines = text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("//") }

        for line in lines {
            if line.hasPrefix("1=") || line.hasPrefix("Ch:") {
                continue
            }
            if line.hasPrefix("V:") {
                currentVoice = String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                currentMeasure = -1
                continue
            }

            let tokens = line.split(separator: " ").map(String.init)
            var inChord = false
            var chordAdded = false
            for rawToken in tokens {
                let token = rawToken.trimmingCharacters(in: .whitespaces)
                if token.isEmpty { continue }
                if token.contains("|") {
                    currentMeasure += token.filter { $0 == "|" }.count
                    continue
                }
                if token == "-" || token == "~" || token == "^" {
                    continue
                }

                if token.hasPrefix("{") {
                    inChord = true
                    chordAdded = false
                }

                let cleaned = token
                    .replacingOccurrences(of: "{", with: "")
                    .replacingOccurrences(of: "}", with: "")
                if cleaned.contains(where: { ("1"..."7").contains(String($0)) }) || cleaned.contains("0") {
                    if !cleaned.contains("0"), (!inChord || !chordAdded) {
                        annotations.append(JTFPositionalAnnotation(
                            voiceID: currentVoice,
                            hand: hand(from: currentVoice),
                            measureIndex: max(currentMeasure, 0),
                            segmentID: nil
                        ))
                        chordAdded = true
                    }
                }

                if token.hasSuffix("}") {
                    inChord = false
                    chordAdded = false
                }
            }
        }

        if annotations.isEmpty {
            warnings.append("No JTF annotations were extracted.")
        }
        return JTFAnnotationExtraction(annotations: annotations, warnings: warnings)
    }

    private func hand(from voiceID: String?) -> Hand? {
        guard let voiceID = voiceID?.lowercased() else { return nil }
        if voiceID.contains("right") || voiceID.contains("右") {
            return .right
        }
        if voiceID.contains("left") || voiceID.contains("左") {
            return .left
        }
        return nil
    }
}

struct JTFAnnotationApplier {
    func apply(
        _ annotations: [JTFPositionalAnnotation],
        to events: [NoteEvent],
        warnings: inout [String]
    ) -> [NoteEvent] {
        guard !annotations.isEmpty else { return events }
        if annotations.count != events.count {
            warnings.append("JTF annotation count \(annotations.count) does not match target event count \(events.count); applying best-effort positional annotations.")
        }

        return events.practiceSorted().enumerated().map { index, event in
            guard index < annotations.count else { return event }
            let item = annotations[index]
            var copy = event
            let source = EventSource(
                trackIndex: event.trackIndex,
                channel: event.channel,
                sourceTick: event.sourceTick,
                sourceDurationTick: event.sourceDurationTick,
                voiceID: item.voiceID,
                hand: item.hand
            )
            let annotation = TargetAnnotation(
                voiceID: item.voiceID,
                hand: item.hand,
                measureIndex: item.measureIndex,
                segmentID: item.segmentID,
                sources: [source]
            )
            copy.annotations = annotation.merged(with: event.annotations)
            return copy
        }
    }
}

struct JTFAnnotationExtraction {
    var annotations: [JTFPositionalAnnotation]
    var warnings: [String]
}

struct JTFPositionalAnnotation {
    var voiceID: String?
    var hand: Hand?
    var measureIndex: Int?
    var segmentID: String?
}
