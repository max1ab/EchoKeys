import AVFoundation
import Foundation

public struct MIDIFileRenderer: MIDIFileRendering {
    public init() {}

    public func renderMIDIFile(
        at midiURL: URL,
        to outputURL: URL,
        options: MIDIRenderOptions = .default
    ) throws -> MIDIAudioRenderResult {
        let renderFormat = AVAudioFormat(
            standardFormatWithSampleRate: options.sampleRate,
            channels: AVAudioChannelCount(options.channelCount)
        )

        guard let renderFormat else {
            throw MIDIConversionError.renderFailed("Unable to create render format.")
        }

        let synth = try SystemMIDISynth(
            offlineFormat: renderFormat,
            maximumFrameCount: AVAudioFrameCount(options.maximumFrameCount)
        )

        let sequencer = AVAudioSequencer(audioEngine: synth.engine)
        let baseDuration = try MIDISequenceLoader.loadSequence(
            into: sequencer,
            from: midiURL,
            destinationAudioUnit: synth.instrument
        )

        do {
            try synth.start()

            if baseDuration <= 0.0001 {
                let result = try OfflineAudioWriter.write(
                    engine: synth.engine,
                    to: outputURL,
                    duration: options.tailDuration,
                    options: options
                )
                synth.stop()
                return result
            }

            sequencer.prepareToPlay()
            try sequencer.start()
            let result = try OfflineAudioWriter.write(
                engine: synth.engine,
                to: outputURL,
                duration: baseDuration + options.tailDuration,
                options: options
            )
            sequencer.stop()
            synth.stop()
            return result
        } catch let error as MIDIConversionError {
            sequencer.stop()
            synth.stop()
            throw error
        } catch {
            sequencer.stop()
            synth.stop()
            throw MIDIConversionError.renderFailed(error.localizedDescription)
        }
    }
}
