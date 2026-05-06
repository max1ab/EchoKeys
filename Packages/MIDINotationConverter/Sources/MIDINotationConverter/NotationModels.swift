import Foundation

// MARK: - Score (internal, all conversions flow through this)

struct Score {
    var key: KeySignature
    var timeSig: TimeSignature
    var tempo: Int
    var voices: [Voice]

    init(
        key: KeySignature = .C,
        timeSig: TimeSignature = .fourFour,
        tempo: Int = 120,
        voices: [Voice]
    ) {
        self.key = key
        self.timeSig = timeSig
        self.tempo = tempo
        self.voices = voices
    }
}

struct Voice {
    var name: String?
    var measures: [Measure]

    init(name: String? = nil, measures: [Measure]) {
        self.name = name
        self.measures = measures
    }
}

struct Measure {
    var elements: [Element]
    var barPrefix: BarMarker?
    var barSuffix: BarMarker?
}

// MARK: - Elements

enum Element: Equatable {
    case note(NoteAtom)
    case chord([NoteAtom])
    case rest(Duration)
    case tuplet(count: Int, elements: [Element])
    case tie
    case slur
}

// MARK: - Note atom

struct NoteAtom: Equatable {
    var octave: Int
    var pitch: Int
    var accidental: Int
    var duration: Duration
}

// MARK: - Duration

struct Duration: Hashable {
    var beats: Float64
}

extension Duration {
    static let quarter = Duration(beats: 1)
    static let half = Duration(beats: 2)
    static let whole = Duration(beats: 4)
    static let eighth = Duration(beats: 0.5)
    static let sixteenth = Duration(beats: 0.25)

    static func dotted(_ base: Duration) -> Duration {
        Duration(beats: base.beats * 1.5)
    }
}

// MARK: - Bar markers

enum BarMarker: Equatable {
    case bar
    case doubleBar
    case repeatStart
    case repeatEnd
}

// MARK: - Key → semitone mapping

let majorScaleSemitones: [Int] = [0, 2, 4, 5, 7, 9, 11]

func tonicMIDI(for key: KeySignature) -> Int {
    60 + key.tonic.semitoneFromC
}

func semitoneForDegree(_ degree: Int, in key: KeySignature) -> Int {
    guard (1...7).contains(degree) else { return 0 }
    return majorScaleSemitones[degree - 1]
}

func degreeAndAccidental(for semitone: Int, in key: KeySignature) -> (degree: Int, accidental: Int) {
    let tonic = key.tonic.semitoneFromC
    let normalized = ((semitone - tonic) % 12 + 12) % 12

    var bestDegree = 1
    var bestDiff = Int.max
    for i in 0..<7 {
        let expected = majorScaleSemitones[i]
        let diff = normalized - expected
        if abs(diff) < abs(bestDiff) || (abs(diff) == abs(bestDiff) && diff > bestDiff) {
            bestDiff = diff
            bestDegree = i + 1
        }
    }

    if abs(bestDiff) <= 6 {
        return (bestDegree, bestDiff)
    } else {
        let wrapped = bestDiff > 0 ? bestDiff - 12 : bestDiff + 12
        return (bestDegree, wrapped)
    }
}
