import Foundation

struct JTFSerializer {
    func serialize(_ score: Score) throws -> String {
        var lines: [String] = []

        // Header
        var header = "1=\(score.key.tonic) \(score.timeSig)"
        if score.tempo != 120 {
            header += " \(score.tempo)"
        }
        lines.append(header)

        // Voices
        for voice in score.voices {
            if let name = voice.name {
                lines.append("V:\(name)")
            }

            var currentLine = ""
            for measure in voice.measures {
                let measureStr = serializeMeasure(measure)
                if currentLine.isEmpty {
                    currentLine = measureStr
                } else if currentLine.count + measureStr.count > 80 {
                    lines.append(currentLine)
                    currentLine = measureStr
                } else {
                    currentLine += " " + measureStr
                }

                // Check if we should split at bar end
                if let suffix = measure.barSuffix, suffix == .doubleBar {
                    lines.append(currentLine)
                    currentLine = ""
                }
            }

            if !currentLine.isEmpty {
                lines.append(currentLine)
            }
        }

        return lines.joined(separator: "\n")
    }

    private func serializeMeasure(_ measure: Measure) -> String {
        var parts: [String] = []

        // Bar prefix
        if let prefix = measure.barPrefix {
            parts.append(barMarkerString(prefix))
        }

        // Elements
        for element in measure.elements {
            switch element {
            case .note(let atom):
                parts.append(contentsOf: serializeNote(atom))
            case .chord(let atoms):
                parts.append(contentsOf: serializeChord(atoms))
            case .rest(let dur):
                parts.append(contentsOf: serializeRestElement(dur))
            case .tuplet(let count, let elements):
                let inner = elements.map(serializeElement).joined(separator: " ")
                parts.append("(\(count) \(inner) )")
            case .tie:
                parts.append("~")
            case .slur:
                parts.append("^")
            }
        }

        // Bar suffix
        if let suffix = measure.barSuffix {
            parts.append(barMarkerString(suffix))
        } else {
            parts.append("|")
        }

        return parts.joined(separator: " ")
    }

    private func serializeElement(_ element: Element) -> String {
        switch element {
        case .note(let atom): return serializeNote(atom).joined(separator: " ")
        case .chord(let atoms): return serializeChord(atoms).joined(separator: " ")
        case .rest(let dur): return serializeRestElement(dur).joined(separator: " ")
        case .tie: return "~"
        case .slur: return "^"
        case .tuplet(let count, let elements):
            let inner = elements.map(serializeElement).joined(separator: " ")
            return "(\(count) \(inner) )"
        }
    }

    private func serializeNote(_ atom: NoteAtom) -> [String] {
        var base = atom
        base.duration = baseDuration(for: atom.duration)
        return [serializeNoteAtom(base)] + sustainMarkers(for: atom.duration)
    }

    private func serializeChord(_ atoms: [NoteAtom]) -> [String] {
        let baseAtoms = atoms.map { atom in
            var base = atom
            base.duration = baseDuration(for: atom.duration)
            return base
        }
        let duration = atoms.first?.duration ?? .quarter
        return ["{ " + baseAtoms.map(serializeNoteAtom).joined(separator: " ") + " }"]
            + sustainMarkers(for: duration)
    }

    private func serializeRestElement(_ duration: Duration) -> [String] {
        let count = wholeBeatCount(duration)
        if count > 1 {
            return Array(repeating: serializeRest(.quarter), count: count)
        }
        return [serializeRest(duration)]
    }

    private func serializeNoteAtom(_ atom: NoteAtom) -> String {
        var result = ""

        // Octave down prefix
        for _ in 0..<max(0, -atom.octave) {
            result += "("
        }
        // Octave up prefix
        for _ in 0..<max(0, atom.octave) {
            result += "["
        }

        // Accidental
        if atom.accidental > 0 {
            result += "#"
        } else if atom.accidental < 0 {
            result += "b"
        }

        // Pitch
        result += String(atom.pitch)

        // Octave suffix
        for _ in 0..<max(0, atom.octave) {
            result += "]"
        }
        for _ in 0..<max(0, -atom.octave) {
            result += ")"
        }

        // Duration
        if durationHasDot(atom.duration) {
            result += "."
        }
        for _ in 0..<durationUnderscoreCount(atom.duration) {
            result += "_"
        }

        return result
    }

    private func serializeRest(_ dur: Duration) -> String {
        var result = "0"
        if durationHasDot(dur) {
            result += "."
        }
        for _ in 0..<durationUnderscoreCount(dur) {
            result += "_"
        }
        return result
    }

    private func baseDuration(for duration: Duration) -> Duration {
        wholeBeatCount(duration) > 1 ? .quarter : duration
    }

    private func sustainMarkers(for duration: Duration) -> [String] {
        let count = wholeBeatCount(duration)
        guard count > 1 else { return [] }
        return Array(repeating: "-", count: count - 1)
    }

    private func wholeBeatCount(_ duration: Duration) -> Int {
        let rounded = duration.beats.rounded()
        guard abs(duration.beats - rounded) < 0.0001 else { return 0 }
        return max(0, Int(rounded))
    }

    private func barMarkerString(_ marker: BarMarker) -> String {
        switch marker {
        case .bar: "|"
        case .doubleBar: "||"
        case .repeatStart: "|:"
        case .repeatEnd: ":|"
        }
    }

    // MARK: - Duration decomposition

    /// Given a beat duration, figure out if it has a dot
    private func durationHasDot(_ dur: Duration) -> Bool {
        dur.beats.truncatingRemainder(dividingBy: 1) != 0
            && dur.beats * 2 == round(dur.beats * 2)
            && dur.beats != floor(dur.beats)
            && dur.beats * 10 == round(dur.beats * 10)
    }

    /// Count of underscore marks for the beat fraction
    private func durationUnderscoreCount(_ dur: Duration) -> Int {
        let base = durationHasDot(dur) ? dur.beats / 1.5 : dur.beats
        if base >= 1 { return 0 }
        var count = 0
        var v = base
        while v < 0.99 {
            v *= 2
            count += 1
        }
        return count
    }
}
