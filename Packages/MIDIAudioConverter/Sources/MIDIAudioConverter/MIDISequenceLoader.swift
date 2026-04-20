import AVFoundation
import Foundation

enum MIDISequenceLoader {
    static func validateInputURL(_ midiURL: URL) throws {
        guard midiURL.isFileURL else {
            throw MIDIConversionError.inputMustBeLocalFile
        }

        let ext = midiURL.pathExtension.lowercased()
        guard ext == "mid" || ext == "midi" else {
            throw MIDIConversionError.unsupportedInputType(ext)
        }

        guard FileManager.default.fileExists(atPath: midiURL.path) else {
            throw MIDIConversionError.fileNotFound(midiURL)
        }
    }

    static func validateOutputURL(_ outputURL: URL) throws {
        guard outputURL.isFileURL else {
            throw MIDIConversionError.outputMustBeLocalFile
        }

        let ext = outputURL.pathExtension.lowercased()
        guard ext == "wav" else {
            throw MIDIConversionError.unsupportedOutputType(ext)
        }
    }

    static func loadSequence(
        into sequencer: AVAudioSequencer,
        from midiURL: URL,
        destinationAudioUnit: AVAudioUnit
    ) throws -> TimeInterval {
        try validateInputURL(midiURL)

        do {
            try sequencer.load(from: midiURL, options: [])
        } catch {
            throw MIDIConversionError.invalidMIDIFile(error.localizedDescription)
        }

        for track in sequencer.tracks {
            track.destinationAudioUnit = destinationAudioUnit
        }

        return sequencer.tracks
            .map(\.lengthInSeconds)
            .max() ?? 0
    }
}
