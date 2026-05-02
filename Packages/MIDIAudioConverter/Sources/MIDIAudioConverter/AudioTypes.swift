import Foundation

public struct MIDIPlaybackOptions: Sendable, Equatable {
    public var outputVolume: Float

    public init(outputVolume: Float = 1.0) {
        self.outputVolume = outputVolume
    }

    public static let `default` = MIDIPlaybackOptions()
}

public struct MIDIRenderOptions: Sendable, Equatable {
    public var sampleRate: Double
    public var channelCount: UInt32
    public var maximumFrameCount: UInt32
    public var tailDuration: TimeInterval

    public init(
        sampleRate: Double = 44_100,
        channelCount: UInt32 = 2,
        maximumFrameCount: UInt32 = 4_096,
        tailDuration: TimeInterval = 0.1
    ) {
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.maximumFrameCount = maximumFrameCount
        self.tailDuration = tailDuration
    }

    public static let `default` = MIDIRenderOptions()
}

public enum MIDIPlaybackState: Sendable, Equatable {
    case idle
    case loaded
    case playing
    case paused
    case stopped
}

public struct MIDIAudioRenderResult: Sendable, Equatable {
    public let outputURL: URL
    public let duration: TimeInterval
    public let sampleRate: Double
    public let frameCount: Int64
    public let fileSize: UInt64

    public init(
        outputURL: URL,
        duration: TimeInterval,
        sampleRate: Double,
        frameCount: Int64,
        fileSize: UInt64
    ) {
        self.outputURL = outputURL
        self.duration = duration
        self.sampleRate = sampleRate
        self.frameCount = frameCount
        self.fileSize = fileSize
    }
}

public struct MIDIFileInfo: Sendable, Equatable {
    public let duration: TimeInterval
    public let trackCount: Int
    public let noteEventCount: Int
    public let tempoEventCount: Int
    public let sustainPedalEventCount: Int

    public init(
        duration: TimeInterval,
        trackCount: Int,
        noteEventCount: Int,
        tempoEventCount: Int,
        sustainPedalEventCount: Int
    ) {
        self.duration = duration
        self.trackCount = trackCount
        self.noteEventCount = noteEventCount
        self.tempoEventCount = tempoEventCount
        self.sustainPedalEventCount = sustainPedalEventCount
    }
}

public enum MIDIConversionError: LocalizedError, Equatable {
    case inputMustBeLocalFile
    case outputMustBeLocalFile
    case unsupportedInputType(String)
    case unsupportedOutputType(String)
    case fileNotFound(URL)
    case invalidMIDIFile(String)
    case notLoaded
    case playbackFailed(String)
    case renderFailed(String)
    case audioEngineFailed(String)
    case fileWriteFailed(String)

    public var errorDescription: String? {
        switch self {
        case .inputMustBeLocalFile:
            return "Input must be a local file URL."
        case .outputMustBeLocalFile:
            return "Output must be a local file URL."
        case let .unsupportedInputType(ext):
            return "Unsupported input type: \(ext). Only .mid and .midi are supported."
        case let .unsupportedOutputType(ext):
            return "Unsupported output type: \(ext). Only .wav is supported."
        case let .fileNotFound(url):
            return "File not found: \(url.path)."
        case let .invalidMIDIFile(reason):
            return "Invalid MIDI file: \(reason)"
        case .notLoaded:
            return "No MIDI file is loaded."
        case let .playbackFailed(reason):
            return "Playback failed: \(reason)"
        case let .renderFailed(reason):
            return "Render failed: \(reason)"
        case let .audioEngineFailed(reason):
            return "Audio engine failed: \(reason)"
        case let .fileWriteFailed(reason):
            return "Failed to write output file: \(reason)"
        }
    }
}
