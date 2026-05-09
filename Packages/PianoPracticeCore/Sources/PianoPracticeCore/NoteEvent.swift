import Foundation

public struct NoteEvent: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    public var pitch: Int
    public var onsetBeat: Double
    public var durationBeat: Double
    public var velocity: Int
    public var trackIndex: Int
    public var channel: Int
    public var sourceTick: Int?
    public var sourceDurationTick: Int?
    public var annotations: TargetAnnotation?

    public init(
        id: String,
        pitch: Int,
        onsetBeat: Double,
        durationBeat: Double,
        velocity: Int,
        trackIndex: Int = 0,
        channel: Int = 0,
        sourceTick: Int? = nil,
        sourceDurationTick: Int? = nil,
        annotations: TargetAnnotation? = nil
    ) {
        self.id = id
        self.pitch = pitch
        self.onsetBeat = onsetBeat
        self.durationBeat = durationBeat
        self.velocity = velocity
        self.trackIndex = trackIndex
        self.channel = channel
        self.sourceTick = sourceTick
        self.sourceDurationTick = sourceDurationTick
        self.annotations = annotations
    }
}

public struct TargetAnnotation: Codable, Sendable, Equatable {
    public var voiceID: String?
    public var hand: Hand?
    public var measureIndex: Int?
    public var segmentID: String?
    public var sources: [EventSource]

    public init(
        voiceID: String? = nil,
        hand: Hand? = nil,
        measureIndex: Int? = nil,
        segmentID: String? = nil,
        sources: [EventSource] = []
    ) {
        self.voiceID = voiceID
        self.hand = hand
        self.measureIndex = measureIndex
        self.segmentID = segmentID
        self.sources = sources
    }

    public func merged(with other: TargetAnnotation?) -> TargetAnnotation {
        guard let other else { return self }
        return TargetAnnotation(
            voiceID: voiceID ?? other.voiceID,
            hand: hand ?? other.hand,
            measureIndex: measureIndex ?? other.measureIndex,
            segmentID: segmentID ?? other.segmentID,
            sources: sources + other.sources
        )
    }
}

public enum Hand: String, Codable, Sendable, Equatable {
    case left
    case right
}

public struct EventSource: Codable, Sendable, Equatable {
    public var trackIndex: Int
    public var channel: Int
    public var sourceTick: Int?
    public var sourceDurationTick: Int?
    public var voiceID: String?
    public var hand: Hand?

    public init(
        trackIndex: Int,
        channel: Int,
        sourceTick: Int? = nil,
        sourceDurationTick: Int? = nil,
        voiceID: String? = nil,
        hand: Hand? = nil
    ) {
        self.trackIndex = trackIndex
        self.channel = channel
        self.sourceTick = sourceTick
        self.sourceDurationTick = sourceDurationTick
        self.voiceID = voiceID
        self.hand = hand
    }
}
