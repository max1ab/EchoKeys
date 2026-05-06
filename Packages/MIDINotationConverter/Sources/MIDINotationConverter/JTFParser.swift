import Foundation

struct JTFParser {
    func parse(_ text: String, options: JTFConvertOptions = .default) throws -> Score {
        let lineTokens = try JTFTokenizer().tokenize(text)
        return try buildScore(from: lineTokens, options: options)
    }

    // MARK: - Score building

    private func buildScore(from lineTokens: [[JTFPlainToken]], options: JTFConvertOptions) throws -> Score {
        var key = options.defaultKey
        var timeSig = options.defaultTimeSig
        var tempo = options.defaultTempo
        var startLine = 0

        // Try to parse header from first line
        if let firstLine = lineTokens.first,
           case let .headerLine(headerText) = firstLine.first {
            let header = try parseHeader(headerText)
            key = header.key
            timeSig = header.timeSig
            tempo = header.tempo ?? tempo
            startLine = 1
        }

        // Build voices
        var voices: [Voice] = []
        var currentVoice: (name: String?, measures: [Measure]) = (nil, [])
        var currentMeasures: [Measure] = []

        for lineIdx in startLine..<lineTokens.count {
            let tokens = lineTokens[lineIdx]

            // Check for voice declaration
            if case let .voiceDecl(name) = tokens.first {
                if !currentMeasures.isEmpty {
                    currentVoice.measures = currentMeasures
                    currentMeasures = []
                }
                if currentVoice.measures.isEmpty && voices.isEmpty {
                    // first voice with no measures yet, just set name
                    currentVoice.name = name.isEmpty ? nil : name
                } else {
                    // save previous voice, start new one
                    if !currentVoice.measures.isEmpty || voices.contains(where: { $0.name == currentVoice.name && $0.measures.isEmpty }) == false {
                        // only save if it has content
                    }
                    if !voicelessMeasures(currentVoice) {
                        voices.append(Voice(name: currentVoice.name, measures: currentVoice.measures))
                    }
                    currentVoice = (name.isEmpty ? nil : name, [])
                }
                continue
            }

            // Chord line - skip for now
            if case .chordLine = tokens.first {
                continue
            }

            // Parse all measures on this line.
            let measures = try parseMeasures(from: tokens)
            currentMeasures.append(contentsOf: measures)
        }

        if !currentMeasures.isEmpty {
            currentVoice.measures = currentMeasures
        }
        voices.append(Voice(name: currentVoice.name, measures: currentVoice.measures))

        if voices.isEmpty {
            throw NotationConversionError.missingMeasureData
        }

        return Score(
            key: key,
            timeSig: timeSig,
            tempo: tempo,
            voices: voices
        )
    }

    private func voicelessMeasures(_ voice: (name: String?, measures: [Measure])) -> Bool {
        voice.name == nil && voice.measures.isEmpty
    }

    // MARK: - Header parsing

    private struct HeaderInfo {
        let key: KeySignature
        let timeSig: TimeSignature
        let tempo: Int?
    }

    private func parseHeader(_ text: String) throws -> HeaderInfo {
        let parts = text.split(separator: " ")
        guard parts.count >= 2 else {
            throw NotationConversionError.parseFailed("Header must contain key and time signature")
        }

        let key = try parseKeySignature(String(parts[0]))
        let timeSig = try parseTimeSignature(String(parts[1]))
        var tempo: Int?
        if parts.count >= 3, let t = Int(parts[2]) {
            tempo = t
        }

        return HeaderInfo(key: key, timeSig: timeSig, tempo: tempo)
    }

    func parseKeySignature(_ text: String) throws -> KeySignature {
        guard text.hasPrefix("1="), text.count >= 3 else {
            throw NotationConversionError.parseFailed("Invalid key signature: \(text)")
        }
        let nameStr = String(text.dropFirst(2))
        guard let name = noteName(from: nameStr) else {
            throw NotationConversionError.parseFailed("Unknown note name: \(nameStr)")
        }
        return KeySignature(tonic: name)
    }

    func parseTimeSignature(_ text: String) throws -> TimeSignature {
        let parts = text.split(separator: "/")
        guard parts.count == 2,
              let num = Int(parts[0]),
              let den = Int(parts[1]) else {
            throw NotationConversionError.parseFailed("Invalid time signature: \(text)")
        }
        return TimeSignature(numerator: num, denominator: den)
    }

    // MARK: - Measure parsing

    private func parseMeasures(from tokens: [JTFPlainToken]) throws -> [Measure] {
        var measures: [Measure] = []
        var currentTokens: [JTFPlainToken] = []

        for token in tokens {
            currentTokens.append(token)

            if case .barMarker = token, currentTokens.count > 1 {
                measures.append(try parseMeasure(from: currentTokens))
                currentTokens = []
            }
        }

        if !currentTokens.isEmpty {
            measures.append(try parseMeasure(from: currentTokens))
        }

        return measures
    }

    private func parseMeasure(from tokens: [JTFPlainToken]) throws -> Measure {
        var elements: [Element] = []
        var barPrefix: BarMarker?
        var barSuffix: BarMarker?

        // Extract bar prefix from first token
        let startIdx: Int
        if case let .barMarker(marker) = tokens.first {
            barPrefix = marker
            startIdx = 1
        } else {
            startIdx = 0
        }

        // Extract bar suffix from last token
        let endIdx: Int
        if tokens.count > startIdx, case let .barMarker(marker) = tokens.last {
            barSuffix = marker
            endIdx = tokens.count - 1
        } else {
            endIdx = tokens.count
        }

        // Parse elements between prefix and suffix
        var idx = startIdx
        while idx < endIdx {
            if case .extend = tokens[idx] {
                extendLastElement(in: &elements)
                idx += 1
                continue
            }
            let (element, nextIdx) = try parseElement(from: tokens, at: idx)
            elements.append(element)
            idx = nextIdx
        }

        return Measure(elements: elements, barPrefix: barPrefix, barSuffix: barSuffix)
    }

    private func extendLastElement(in elements: inout [Element]) {
        for index in elements.indices.reversed() {
            switch elements[index] {
            case .note(var atom):
                atom.duration.beats += Duration.quarter.beats
                elements[index] = .note(atom)
                return
            case .chord(var atoms):
                for atomIndex in atoms.indices {
                    atoms[atomIndex].duration.beats += Duration.quarter.beats
                }
                elements[index] = .chord(atoms)
                return
            case .rest(var duration):
                duration.beats += Duration.quarter.beats
                elements[index] = .rest(duration)
                return
            case .tuplet, .tie, .slur:
                continue
            }
        }

        elements.append(.rest(.quarter))
    }

    private func parseElement(from tokens: [JTFPlainToken], at idx: Int) throws -> (Element, Int) {
        guard idx < tokens.count else {
            throw NotationConversionError.parseFailed("Unexpected end of tokens")
        }

        switch tokens[idx] {
        case .extend:
            return (.rest(.quarter), idx + 1)

        case .tie:
            return (.tie, idx + 1)

        case .slur:
            return (.slur, idx + 1)

        case .chordOpen:
            var noteTokens: [NoteToken] = []
            var i = idx + 1
            while i < tokens.count {
                if case .chordClose = tokens[i] {
                    break
                }
                if case let .note(noteTok) = tokens[i] {
                    noteTokens.append(noteTok)
                }
                i += 1
            }
            guard i < tokens.count, case .chordClose = tokens[i] else {
                throw NotationConversionError.parseFailed("Unclosed chord")
            }
            let atoms = noteTokens.map(makeNoteAtom)
            let durations = Set(atoms.map(\.duration))
            guard durations.count == 1 else {
                throw NotationConversionError.parseFailed("All notes in a chord must have the same duration")
            }
            return (.chord(atoms), i + 1)

        case .tupletOpen(let count):
            var innerElements: [Element] = []
            var i = idx + 1
            while i < tokens.count {
                if case .tupletClose = tokens[i] {
                    break
                }
                let (el, next) = try parseElement(from: tokens, at: i)
                innerElements.append(el)
                i = next
            }
            guard i < tokens.count, case .tupletClose = tokens[i] else {
                throw NotationConversionError.parseFailed("Unclosed tuplet")
            }
            return (.tuplet(count: count, elements: innerElements), i + 1)

        case .note(let noteTok):
            if noteTok.pitch == 0 {
                return (.rest(tokenDuration(noteTok)), idx + 1)
            }
            return (.note(makeNoteAtom(noteTok)), idx + 1)

        default:
            throw NotationConversionError.parseFailed("Unexpected token in measure")
        }
    }

    // MARK: - Duration

    private func tokenDuration(_ tok: NoteToken) -> Duration {
        var beats: Float64 = 1
        for _ in 0..<tok.underscoreCount {
            beats /= 2
        }
        if tok.dot {
            beats *= 1.5
        }
        return Duration(beats: beats)
    }

    private func makeNoteAtom(_ tok: NoteToken) -> NoteAtom {
        NoteAtom(
            octave: tok.octaveUp - tok.octaveDown,
            pitch: tok.pitch,
            accidental: tok.accidental,
            duration: tokenDuration(tok)
        )
    }

    // MARK: - Note name parsing

    private func noteName(from string: String) -> NoteName? {
        switch string.uppercased() {
        case "C": .C
        case "D": .D
        case "E": .E
        case "F": .F
        case "G": .G
        case "A": .A
        case "B": .B
        case "C#", "C♯": .Csharp
        case "D#", "D♯": .Dsharp
        case "F#", "F♯": .Fsharp
        case "G#", "G♯": .Gsharp
        case "A#", "A♯": .Asharp
        case "DB", "D♭": .Dflat
        case "EB", "E♭": .Eflat
        case "CB", "C♭": .Cflat
        case "GB", "G♭": .Gflat
        case "AB", "A♭": .Aflat
        case "BB", "B♭": .Bflat
        default: nil
        }
    }

    // MARK: - Helpers

    private func tokensToString(_ tokens: [JTFPlainToken]) -> String {
        tokens.map { tok in
            switch tok {
            case .barMarker(let m):
                switch m {
                case .bar: "|"
                case .doubleBar: "||"
                case .repeatStart: "|:"
                case .repeatEnd: ":|"
                }
            case .chordOpen: "{"
            case .chordClose: "}"
            case .tupletOpen(let c): "(\(c)"
            case .tupletClose: ")"
            case .extend: "-"
            case .tie: "~"
            case .slur: "^"
            case .note(let n):
                "\(n.pitch)"
            case .headerLine(let h): h
            case .voiceDecl(let n): "V:\(n)"
            case .chordLine(let s): "Ch:\(s.joined(separator: " "))"
            }
        }.joined(separator: " ")
    }
}
