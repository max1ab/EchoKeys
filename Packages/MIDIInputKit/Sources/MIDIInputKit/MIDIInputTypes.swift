import Foundation
import PianoPracticeCore

public struct MIDIInputDevice: Sendable, Equatable, Identifiable {
    public var id: Int32
    public var name: String
    public var manufacturer: String?

    public init(id: Int32, name: String, manufacturer: String? = nil) {
        self.id = id
        self.name = name
        self.manufacturer = manufacturer
    }
}

public struct MIDIInputRecordingOptions: Sendable, Equatable {
    public var tempoBPM: Double
    public var ticksPerBeat: Int
    public var idPrefix: String

    public init(
        tempoBPM: Double,
        ticksPerBeat: Int = 480,
        idPrefix: String = "input"
    ) {
        self.tempoBPM = tempoBPM
        self.ticksPerBeat = ticksPerBeat
        self.idPrefix = idPrefix
    }
}

public struct MIDIInputRecording: Sendable, Equatable {
    public var options: MIDIInputRecordingOptions
    public var notes: [NoteEvent]
    public var warnings: [String]

    public var tempoBPM: Double { options.tempoBPM }
    public var ticksPerBeat: Int { options.ticksPerBeat }

    public init(
        options: MIDIInputRecordingOptions,
        notes: [NoteEvent],
        warnings: [String] = []
    ) {
        self.options = options
        self.notes = notes
        self.warnings = warnings
    }

    public func exportMIDIData() throws -> Data {
        try MIDIRecordingExporter().export(recording: self)
    }
}

public enum MIDIInputError: LocalizedError, Equatable {
    case invalidTempo(Double)
    case invalidTicksPerBeat(Int)
    case noDeviceConnected
    case deviceNotFound(Int32)
    case notRecording
    case coreMIDIStatus(operation: String, status: Int32)

    public var errorDescription: String? {
        switch self {
        case let .invalidTempo(value):
            "Invalid tempo BPM: \(value)"
        case let .invalidTicksPerBeat(value):
            "Invalid ticks per beat: \(value)"
        case .noDeviceConnected:
            "No MIDI input device is connected."
        case let .deviceNotFound(id):
            "MIDI input device not found: \(id)"
        case .notRecording:
            "MIDI input recorder is not recording."
        case let .coreMIDIStatus(operation, status):
            "CoreMIDI \(operation) failed with status \(status)."
        }
    }
}
