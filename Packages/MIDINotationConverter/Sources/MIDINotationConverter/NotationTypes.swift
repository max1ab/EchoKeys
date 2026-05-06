import Foundation

// MARK: - Key & Time Signature

public struct KeySignature: Sendable, Equatable, CustomStringConvertible {
    public var description: String { "1=\(tonic)" }

    public let tonic: NoteName

    public init(tonic: NoteName) {
        self.tonic = tonic
    }

    public static let C = KeySignature(tonic: .C)
}

public enum NoteName: Sendable, Equatable, CustomStringConvertible {
    case C, D, E, F, G, A, B
    case Csharp, Dsharp, Fsharp, Gsharp, Asharp
    case Cflat, Dflat, Eflat, Gflat, Aflat, Bflat

    public var description: String {
        switch self {
        case .C: "C"
        case .D: "D"
        case .E: "E"
        case .F: "F"
        case .G: "G"
        case .A: "A"
        case .B: "B"
        case .Cflat: "Cb"
        case .Csharp: "C#"
        case .Dsharp: "D#"
        case .Fsharp: "F#"
        case .Gsharp: "G#"
        case .Asharp: "A#"
        case .Dflat: "Db"
        case .Eflat: "Eb"
        case .Gflat: "Gb"
        case .Aflat: "Ab"
        case .Bflat: "Bb"
        }
    }

    var semitoneFromC: Int {
        switch self {
        case .C: 0; case .Csharp, .Dflat: 1; case .D: 2
        case .Cflat: 11
        case .Dsharp, .Eflat: 3; case .E: 4; case .F: 5
        case .Fsharp, .Gflat: 6; case .G: 7
        case .Gsharp, .Aflat: 8; case .A: 9
        case .Asharp, .Bflat: 10; case .B: 11
        }
    }
}

public struct TimeSignature: Sendable, Equatable, CustomStringConvertible {
    public var description: String { "\(numerator)/\(denominator)" }

    public let numerator: Int
    public let denominator: Int

    public init(numerator: Int, denominator: Int) {
        self.numerator = numerator
        self.denominator = denominator
    }

    public static let fourFour = TimeSignature(numerator: 4, denominator: 4)
}

// MARK: - Options

public struct JTFConvertOptions: Sendable, Equatable {
    public var defaultKey: KeySignature
    public var defaultTimeSig: TimeSignature
    public var defaultTempo: Int
    public var ticksPerQuarter: Int

    public init(
        defaultKey: KeySignature = .C,
        defaultTimeSig: TimeSignature = .fourFour,
        defaultTempo: Int = 120,
        ticksPerQuarter: Int = 480
    ) {
        self.defaultKey = defaultKey
        self.defaultTimeSig = defaultTimeSig
        self.defaultTempo = defaultTempo
        self.ticksPerQuarter = ticksPerQuarter
    }

    public static let `default` = JTFConvertOptions()
}

public struct MIDIDecodeOptions: Sendable, Equatable {
    public var defaultKey: KeySignature
    public var ticksPerQuarterThreshold: Int

    public init(
        defaultKey: KeySignature = .C,
        ticksPerQuarterThreshold: Int = 960
    ) {
        self.defaultKey = defaultKey
        self.ticksPerQuarterThreshold = ticksPerQuarterThreshold
    }

    public static let `default` = MIDIDecodeOptions()
}

// MARK: - Result

public struct MIDIEncodeResult: Sendable, Equatable {
    public let outputURL: URL
    public let trackCount: Int
    public let noteEventCount: Int
    public let duration: TimeInterval

    public init(
        outputURL: URL,
        trackCount: Int,
        noteEventCount: Int,
        duration: TimeInterval
    ) {
        self.outputURL = outputURL
        self.trackCount = trackCount
        self.noteEventCount = noteEventCount
        self.duration = duration
    }
}

// MARK: - Errors

public enum NotationConversionError: LocalizedError, Equatable {
    case parseFailed(String)
    case invalidMIDIFile(String)
    case unsupportedFeature(String)
    case fileWriteFailed(String)
    case missingMeasureData
    case emptyInput

    public var errorDescription: String? {
        switch self {
        case let .parseFailed(reason):
            "Parse failed: \(reason)"
        case let .invalidMIDIFile(reason):
            "Invalid MIDI file: \(reason)"
        case let .unsupportedFeature(reason):
            "Unsupported: \(reason)"
        case let .fileWriteFailed(reason):
            "Failed to write file: \(reason)"
        case .missingMeasureData:
            "Missing measure data."
        case .emptyInput:
            "Input is empty."
        }
    }
}
