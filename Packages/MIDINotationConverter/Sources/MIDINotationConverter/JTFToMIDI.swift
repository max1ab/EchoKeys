import Foundation

public struct JTFToMIDI {
    public init() {}

    public func convert(
        _ text: String,
        to outputURL: URL,
        options: JTFConvertOptions = .default
    ) throws -> MIDIEncodeResult {
        let score = try JTFParser().parse(text, options: options)
        let data = try buildMIDIFile(from: score, ticksPerQuarter: options.ticksPerQuarter)
        return try write(data, to: outputURL, score: score, options: options)
    }

    // MARK: - Build MIDI file

    private func buildMIDIFile(from score: Score, ticksPerQuarter: Int) throws -> Data {
        let writer = MIDIByteWriter()

        // Header
        writer.writeASCII("MThd")
        writer.writeUInt32(6)
        writer.writeUInt16(score.voices.count > 1 ? 1 : 0)
        writer.writeUInt16(score.voices.count)
        writer.writeUInt16(ticksPerQuarter)

        let tempoMicros = 60_000_000 / score.tempo

        for voice in score.voices {
            let trackData = buildTrack(
                voice: voice,
                key: score.key,
                ticksPerQuarter: ticksPerQuarter,
                tempoMicros: tempoMicros,
                timeSig: score.timeSig
            )
            writer.writeASCII("MTrk")
            let trackBytes = trackData
            writer.writeUInt32(trackBytes.count)
            for b in trackBytes { writer.writeByte(b) }
        }

        return writer.data()
    }

    private func buildTrack(
        voice: Voice,
        key: KeySignature,
        ticksPerQuarter: Int,
        tempoMicros: Int,
        timeSig: TimeSignature
    ) -> [UInt8] {
        var events: [(tick: Int, bytes: [UInt8])] = []

        // Tempo meta
        events.append((0, midiTempoMeta(microseconds: tempoMicros)))
        // Time sig meta
        events.append((0, midiTimeSigMeta(numerator: timeSig.numerator, denominator: timeSig.denominator)))
        // Key sig meta
        events.append((0, midiKeySigMeta(key: key)))

        var currentTick = 0
        let ticksPerBeat = ticksPerQuarter
        var noteEventCount = 0

        for measure in voice.measures {
            for element in measure.elements {
                switch element {
                case .note(let atom):
                    let durTicks = Int(atom.duration.beats * Float64(ticksPerBeat))
                    let midiNote = atomToMIDI(atom, key: key)
                    events.append((currentTick, midiNoteOn(note: midiNote, velocity: 80)))
                    events.append((currentTick + durTicks, midiNoteOff(note: midiNote)))
                    currentTick += durTicks
                    noteEventCount += 1

                case .chord(let atoms):
                    let durations = Set(atoms.map { Int($0.duration.beats * Float64(ticksPerBeat)) })
                    let durTicks = durations.first ?? ticksPerBeat
                    var midiNotes: [Int] = []
                    for atom in atoms {
                        let n = atomToMIDI(atom, key: key)
                        midiNotes.append(n)
                        events.append((currentTick, midiNoteOn(note: n, velocity: 80)))
                        noteEventCount += 1
                    }
                    for n in midiNotes {
                        events.append((currentTick + durTicks, midiNoteOff(note: n)))
                    }
                    currentTick += durTicks

                case .rest(let dur):
                    currentTick += Int(dur.beats * Float64(ticksPerBeat))

                case .tuplet(let count, let elements):
                    let tupletTicks = ticksPerBeat
                    let subTicks = tupletTicks / count
                    for el in elements {
                        if case .note(let atom) = el {
                            let midiNote = atomToMIDI(atom, key: key)
                            events.append((currentTick, midiNoteOn(note: midiNote, velocity: 80)))
                            events.append((currentTick + subTicks, midiNoteOff(note: midiNote)))
                            noteEventCount += 1
                        }
                        currentTick += subTicks
                    }

                case .tie, .slur:
                    break
                }
            }
        }

        // End of track meta
        let maxTick = events.map(\.tick).max() ?? 0
        events.append((maxTick, [0xFF, 0x2F, 0x00]))

        // Sort by tick, write as delta-time encoded MIDI
        events.sort { $0.tick < $1.tick }

        var bytes: [UInt8] = []
        var prevTick = 0
        for (tick, data) in events {
            let delta = tick - prevTick
            bytes.append(contentsOf: encodeVarLen(delta))
            bytes.append(contentsOf: data)
            prevTick = tick
        }

        // Store note count via a side variable
        _ = noteEventCount
        return bytes
    }

    // MARK: - MIDI note conversion

    private func atomToMIDI(_ atom: NoteAtom, key: KeySignature) -> Int {
        let tonic = tonicMIDI(for: key)
        let scaleOffset = semitoneForDegree(atom.pitch, in: key)
        return tonic + scaleOffset + atom.accidental + atom.octave * 12
    }

    // MARK: - MIDI event builders

    private func midiNoteOn(note: Int, velocity: Int) -> [UInt8] {
        [0x90, UInt8(note.clamped(to: 0...127)), UInt8(velocity.clamped(to: 0...127))]
    }

    private func midiNoteOff(note: Int) -> [UInt8] {
        [0x80, UInt8(note.clamped(to: 0...127)), 0x00]
    }

    private func midiTempoMeta(microseconds: Int) -> [UInt8] {
        [0xFF, 0x51, 0x03,
         UInt8((microseconds >> 16) & 0xFF),
         UInt8((microseconds >> 8) & 0xFF),
         UInt8(microseconds & 0xFF)]
    }

    private func midiTimeSigMeta(numerator: Int, denominator: Int) -> [UInt8] {
        let denomP2 = Int(log2(Float64(denominator)))
        return [0xFF, 0x58, 0x04,
                UInt8(numerator), UInt8(denomP2), 0x18, 0x08]
    }

    private func midiKeySigMeta(key: KeySignature) -> [UInt8] {
        let sf = sharpsFlats(for: key.tonic)
        return [0xFF, 0x59, 0x02, UInt8(bitPattern: Int8(sf)), 0x00]
    }

    private func sharpsFlats(for name: NoteName) -> Int {
        switch name {
        case .Cflat: -7
        case .Gflat: -6
        case .Dflat: -5
        case .Aflat: -4
        case .Eflat: -3
        case .Bflat: -2
        case .F: -1
        case .C: 0
        case .G: 1
        case .D: 2
        case .A: 3
        case .E: 4
        case .B: 5
        case .Fsharp: 6
        case .Csharp: 7
        default: 0
        }
    }

    private func encodeVarLen(_ value: Int) -> [UInt8] {
        var v = value
        var buf: [UInt8] = [UInt8(v & 0x7F)]
        v >>= 7
        while v > 0 {
            buf.append(UInt8((v & 0x7F) | 0x80))
            v >>= 7
        }
        return buf.reversed()
    }

    // MARK: - Write

    private func write(
        _ data: Data,
        to outputURL: URL,
        score: Score,
        options: JTFConvertOptions
    ) throws -> MIDIEncodeResult {
        do {
            let dir = outputURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try data.write(to: outputURL)
        } catch {
            throw NotationConversionError.fileWriteFailed(error.localizedDescription)
        }

        let noteCount = score.voices.flatMap { voice in
            voice.measures.flatMap { measure in
                measure.elements.compactMap { el in
                    if case .note = el { return true }
                    if case .chord = el { return true }
                    return false
                }
            }
        }.count

        let totalBeats = score.voices.first?.measures.flatMap(\.elements).reduce(Float64(0)) { sum, el in
            if case .note(let a) = el { return sum + a.duration.beats }
            if case .chord(let a) = el, let d = a.first?.duration.beats { return sum + d }
            if case .rest(let d) = el { return sum + d.beats }
            return sum
        } ?? 0

        let duration = totalBeats * 60.0 / Float64(score.tempo)

        return MIDIEncodeResult(
            outputURL: outputURL,
            trackCount: score.voices.count,
            noteEventCount: noteCount,
            duration: duration
        )
    }
}

private extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
