import Foundation
import PianoPracticeCore

public typealias NoteEvent = PianoPracticeCore.NoteEvent
public typealias TargetAnnotation = PianoPracticeCore.TargetAnnotation
public typealias Hand = PianoPracticeCore.Hand
public typealias EventSource = PianoPracticeCore.EventSource

public struct MIDIPracticeConfiguration: Codable, Sendable, Equatable {
    public var onsetToleranceBeat: Double
    public var durationToleranceBeat: Double
    public var maxMatchWindowBeat: Double
    public var insertCost: Double
    public var deleteCost: Double
    public var wrongPitchCost: Double
    public var pitchMismatchPenalty: Double
    public var chordSyncToleranceBeat: Double
    public var duplicateEpsilonBeat: Double
    public var offsetAnchorCount: Int
    public var minTempoScale: Double
    public var maxTempoScale: Double

    public init(
        onsetToleranceBeat: Double = 0.125,
        durationToleranceBeat: Double = 0.25,
        maxMatchWindowBeat: Double = 1.0,
        insertCost: Double = 1.0,
        deleteCost: Double = 1.0,
        wrongPitchCost: Double = 0.8,
        pitchMismatchPenalty: Double = 0.2,
        chordSyncToleranceBeat: Double = 0.05,
        duplicateEpsilonBeat: Double = 0.0001,
        offsetAnchorCount: Int = 3,
        minTempoScale: Double = 0.75,
        maxTempoScale: Double = 1.35
    ) {
        self.onsetToleranceBeat = onsetToleranceBeat
        self.durationToleranceBeat = durationToleranceBeat
        self.maxMatchWindowBeat = maxMatchWindowBeat
        self.insertCost = insertCost
        self.deleteCost = deleteCost
        self.wrongPitchCost = wrongPitchCost
        self.pitchMismatchPenalty = pitchMismatchPenalty
        self.chordSyncToleranceBeat = chordSyncToleranceBeat
        self.duplicateEpsilonBeat = duplicateEpsilonBeat
        self.offsetAnchorCount = offsetAnchorCount
        self.minTempoScale = minTempoScale
        self.maxTempoScale = maxTempoScale
    }

    public static let `default` = MIDIPracticeConfiguration()
}

public enum MIDIPracticeError: LocalizedError, Equatable {
    case invalidMIDIFile(String)
    case unsupportedMIDI(String)
    case emptyInput(String)

    public var errorDescription: String? {
        switch self {
        case let .invalidMIDIFile(reason):
            "Invalid MIDI file: \(reason)"
        case let .unsupportedMIDI(reason):
            "Unsupported MIDI: \(reason)"
        case let .emptyInput(reason):
            "Empty input: \(reason)"
        }
    }
}

public struct MIDIPracticeReport: Codable, Sendable, Equatable {
    public var targetEvents: [NoteEvent]
    public var performanceEvents: [NoteEvent]
    public var alignment: [AlignmentItem]
    public var level1: Level1Score
    public var level2: Level2Score
    public var level3: Level3Score
    public var summaries: [PracticeSummary]
    public var errors: [PracticeErrorItem]
    public var warnings: [String]
    public var estimatedOffsetBeat: Double
    public var estimatedTempoScale: Double
}

public struct AlignmentItem: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    public var kind: AlignmentKind
    public var targetEventID: String?
    public var performanceEventID: String?
    public var onsetDelta: Double?
    public var durationDelta: Double?
}

public enum AlignmentKind: String, Codable, Sendable, Equatable {
    case matched
    case missed
    case extra
    case wrongPitch
}

public struct Level1Score: Codable, Sendable, Equatable {
    public var pitchAccuracy: Double
    public var completeness: Double
    public var matchedCount: Int
    public var missedCount: Int
    public var extraCount: Int
    public var wrongPitchCount: Int
}

public struct Level2Score: Codable, Sendable, Equatable {
    public var onsetTimingScore: Double
    public var interOnsetScore: Double
    public var durationScore: Double
    public var earlyCount: Int
    public var lateCount: Int
    public var averageOnsetDelta: Double
    public var maxOnsetDelta: Double
}

public struct Level3Score: Codable, Sendable, Equatable {
    public var isPlaceholder: Bool
    public var message: String

    public static let placeholder = Level3Score(
        isPlaceholder: true,
        message: "Expressive scoring is not implemented in this version."
    )
}

public struct PracticeSummary: Codable, Sendable, Equatable {
    public var measureIndex: Int?
    public var segmentID: String?
    public var missedCount: Int
    public var extraCount: Int
    public var wrongPitchCount: Int
    public var averageOnsetDelta: Double?
}

public struct PracticeErrorItem: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    public var type: PracticeErrorType
    public var severity: PracticeErrorSeverity
    public var targetEventID: String?
    public var performanceEventID: String?
    public var message: String
}

public enum PracticeErrorType: String, Codable, Sendable, Equatable {
    case missedNote
    case extraNote
    case wrongPitch
}

public enum PracticeErrorSeverity: String, Codable, Sendable, Equatable {
    case info
    case warning
    case critical
}
