import Foundation

public struct MIDIToJTF {
    public init() {}

    public func convert(midiURL: URL, options: MIDIDecodeOptions = .default) throws -> String {
        guard midiURL.isFileURL else {
            throw NotationConversionError.invalidMIDIFile("Must be a local file URL")
        }

        let data: Data
        do {
            data = try Data(contentsOf: midiURL)
        } catch {
            throw NotationConversionError.invalidMIDIFile(error.localizedDescription)
        }

        let (division, tracks) = try MIDIFileParser().parse(data)
        let score = try buildScore(tracks: tracks, division: division, options: options)
        return try JTFSerializer().serialize(score)
    }

    // MARK: - Build Score

    private func buildScore(
        tracks: [MIDITrackData],
        division: Int,
        options: MIDIDecodeOptions
    ) throws -> Score {
        // Merge all tempo/key/time events
        var allTempos: [MIDITempoEvent] = [MIDITempoEvent(tick: 0, microsecondsPerQuarter: defaultTempoUS)]
        var allKeySigs: [MIDIKeySigEvent] = []
        var allTimeSigs: [MIDITimeSigEvent] = []

        for track in tracks {
            allTempos.append(contentsOf: track.tempos)
            allKeySigs.append(contentsOf: track.keySigs)
            allTimeSigs.append(contentsOf: track.timeSigs)
        }

        // Determine key
        let key: KeySignature
        if let firstKey = allKeySigs.first {
            key = keyFromSharpsFlats(Int(firstKey.sharpsFlats), minor: firstKey.minor)
        } else {
            key = inferKey(from: tracks.flatMap(\.notes))
                ?? options.defaultKey
        }

        // Determine time signature
        let timeSig: TimeSignature
        if let firstTS = allTimeSigs.first {
            timeSig = TimeSignature(numerator: firstTS.numerator, denominator: 1 << firstTS.denominator)
        } else {
            timeSig = .fourFour
        }

        // Tempo
        let tempo = allTempos.first.map { Int(60_000_000.0 / Float64($0.microsecondsPerQuarter)) } ?? 120

        // Build voices from tracks that have notes
        var voices: [Voice] = []
        for (idx, track) in tracks.enumerated() {
            let notes = matchNotePairs(in: track.notes, fallbackTicks: division)
            guard !notes.isEmpty else { continue }

            let measures = buildMeasures(
                from: notes,
                ticksPerQuarter: division,
                timeSig: timeSig,
                key: key
            )
            let name = tracks.count > 1 ? "Track\(idx + 1)" : nil
            voices.append(Voice(name: name, measures: measures))
        }

        guard !voices.isEmpty else {
            throw NotationConversionError.invalidMIDIFile("No notes found")
        }

        return Score(key: key, timeSig: timeSig, tempo: tempo, voices: voices)
    }

    // MARK: - Note pairing

    private func matchNotePairs(in events: [MIDINoteEvent], fallbackTicks: Int) -> [MIDINoteEvent] {
        var paired: [MIDINoteEvent] = []
        var pending: [Int: (tick: Int, channel: Int, velocity: Int)] = [:] // keyed by note

        for event in events.sorted(by: { $0.tick < $1.tick }) {
            let key = event.note * 16 + event.channel
            if event.velocity > 0 {
                pending[key] = (event.tick, event.channel, event.velocity)
            } else {
                if let start = pending.removeValue(forKey: key) {
                    paired.append(MIDINoteEvent(
                        tick: start.tick,
                        duration: event.tick - start.tick,
                        channel: event.channel,
                        note: event.note,
                        velocity: start.velocity
                    ))
                }
            }
        }

        // Close unpaired notes at end
        for (key, start) in pending {
            paired.append(MIDINoteEvent(
                tick: start.tick,
                duration: (paired.map(\.tick).max() ?? 0) - start.tick + fallbackTicks,
                channel: start.channel,
                note: key / 16,
                velocity: start.velocity
            ))
        }

        return paired.sorted { $0.tick < $1.tick || ($0.tick == $1.tick && $0.note < $1.note) }
    }

    // MARK: - Build measures

    private func buildMeasures(
        from notes: [MIDINoteEvent],
        ticksPerQuarter: Int,
        timeSig: TimeSignature,
        key: KeySignature
    ) -> [Measure] {
        guard !notes.isEmpty else { return [] }

        let ticksPerBeat = ticksPerQuarter
        let ticksPerMeasure = ticksPerBeat * timeSig.numerator * 4 / timeSig.denominator
        _ = Float64(timeSig.numerator) * 4.0 / Float64(timeSig.denominator)

        // Group notes by onset tick for chord detection
        var measureMap: [Int: [(Float64, MIDINoteEvent)]] = [:] // measureIndex → (beatInMeasure, note)

        let sorted = notes.sorted { $0.tick < $1.tick }
        for note in sorted {
            let measureIdx = note.tick / ticksPerMeasure
            let beatInMeasure = Float64(note.tick % ticksPerMeasure) / Float64(ticksPerBeat)
            measureMap[measureIdx, default: []].append((beatInMeasure, note))
        }

        var measures: [Measure] = []
        let maxMeasure = measureMap.keys.max() ?? 0

        for m in 0...maxMeasure {
            let events = (measureMap[m] ?? []).sorted {
                $0.0 < $1.0 || ($0.0 == $1.0 && $0.1.note < $1.1.note)
            }
            var elements: [Element] = []
            var idx = 0
            var currentBeat = Float64(0)

            while idx < events.count {
                let (beat, note) = events[idx]

                if beat > currentBeat {
                    elements.append(.rest(quantizeDuration(beat - currentBeat)))
                    currentBeat = beat
                }

                // Check for chord: same onset tick
                var chordNotes = [note]
                var j = idx + 1
                while j < events.count, events[j].0 == beat {
                    chordNotes.append(events[j].1)
                    j += 1
                }

                if chordNotes.count > 1 {
                    let atoms = chordNotes.map {
                        midiNoteToAtom($0, key: key, ticksPerQuarter: ticksPerQuarter)
                    }
                    elements.append(.chord(atoms))
                    let chordBeats = chordNotes
                        .map { Float64($0.duration) / Float64(ticksPerQuarter) }
                        .max() ?? 0
                    currentBeat = max(currentBeat, beat + chordBeats)
                } else {
                    let atom = midiNoteToAtom(note, key: key, ticksPerQuarter: ticksPerQuarter)
                    elements.append(.note(atom))
                    currentBeat = max(currentBeat, beat + Float64(note.duration) / Float64(ticksPerQuarter))
                }
                idx = j
            }

            measures.append(Measure(
                elements: elements,
                barPrefix: m == 0 ? .bar : nil,
                barSuffix: m == maxMeasure ? .doubleBar : .bar
            ))
        }

        return measures
    }

    private func midiNoteToAtom(
        _ event: MIDINoteEvent,
        key: KeySignature,
        ticksPerQuarter: Int
    ) -> NoteAtom {
        let octave = event.note / 12 - 1 // MIDI 60 = C4 → 60/12 - 1 = 4
        let semitoneInOctave = event.note % 12
        let (degree, accidental) = degreeAndAccidental(for: semitoneInOctave, in: key)
        let beats = Float64(event.duration) / Float64(ticksPerQuarter)
        return NoteAtom(
            octave: octave - 4,
            pitch: degree,
            accidental: accidental,
            duration: quantizeDuration(beats)
        )
    }

    private func quantizeDuration(_ beats: Float64) -> Duration {
        let candidates: [Float64] = [
            0.25, 0.375, 0.5, 0.75, 1.0, 1.5, 2.0, 3.0, 4.0, 6.0, 8.0
        ]
        let closest = candidates.min(by: { abs($0 - beats) < abs($1 - beats) }) ?? 1.0
        return Duration(beats: closest)
    }

    // MARK: - Key inference

    private let defaultTempoUS = 500_000

    private func keyFromSharpsFlats(_ sf: Int, minor: Bool) -> KeySignature {
        let table: [Int: NoteName] = [
            -7: .Cflat, -6: .Gflat, -5: .Dflat, -4: .Aflat, -3: .Eflat, -2: .Bflat, -1: .F,
            0: .C,
            1: .G, 2: .D, 3: .A, 4: .E, 5: .B, 6: .Fsharp, 7: .Csharp,
        ]
        if let name = table[sf] {
            return KeySignature(tonic: minor ? relativeMinor(name) : name)
        }
        return .C
    }

    private func relativeMinor(_ major: NoteName) -> NoteName {
        let semitones = major.semitoneFromC
        let minorSemitone = (semitones - 3 + 12) % 12
        for name in noteNameList where name.semitoneFromC == minorSemitone {
            return name
        }
        return .A
    }

    private let noteNameList: [NoteName] = [.C, .Csharp, .D, .Dsharp, .E, .F, .Fsharp, .G, .Gsharp, .A, .Asharp, .B]

    private func inferKey(from notes: [MIDINoteEvent]) -> KeySignature? {
        let countMap = Dictionary(grouping: notes) { $0.note % 12 }.mapValues(\.count)
        guard countMap.count >= 6 else { return nil }

        // Krumhansl-Schmuckler correlation table for major keys
        let majorProfile: [Int: Float64] = [
            0: 6.35, 1: 2.23, 2: 3.48, 3: 2.33, 4: 4.38, 5: 4.09, 6: 2.52, 7: 5.19,
            8: 2.39, 9: 3.66, 10: 2.29, 11: 2.88
        ]

        let candidates: [NoteName] = [.C, .G, .D, .A, .E, .B, .Fsharp, .F, .Bflat, .Eflat, .Aflat, .Dflat]
        var bestKey = NoteName.C
        var bestScore = -Float64.infinity

        for name in candidates {
            var score: Float64 = 0
            for (pitchClass, count) in countMap {
                let idx = (pitchClass - name.semitoneFromC + 12) % 12
                let weight = majorProfile[idx] ?? 0
                score += weight * Float64(count)
            }
            if score > bestScore {
                bestScore = score
                bestKey = name
            }
        }

        return KeySignature(tonic: bestKey)
    }
}
