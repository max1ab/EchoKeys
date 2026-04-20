import AVFoundation
import Foundation

public final class MIDIFilePlayer: MIDIFilePlaying {
    public private(set) var state: MIDIPlaybackState = .idle

    private let options: MIDIPlaybackOptions
    private var synth: SystemMIDISynth?
    private var sequencer: AVAudioSequencer?
    private var loadedURL: URL?

    public init(options: MIDIPlaybackOptions = .default) {
        self.options = options
    }

    public func load(midiURL: URL) throws {
        stop()

        let synth = try SystemMIDISynth(outputVolume: options.outputVolume)
        let sequencer = AVAudioSequencer(audioEngine: synth.engine)
        _ = try MIDISequenceLoader.loadSequence(
            into: sequencer,
            from: midiURL,
            destinationAudioUnit: synth.instrument
        )

        self.synth = synth
        self.sequencer = sequencer
        loadedURL = midiURL
        state = .loaded
    }

    public func play() throws {
        guard let synth, let sequencer else {
            throw MIDIConversionError.notLoaded
        }

        do {
            try synth.start()
            sequencer.prepareToPlay()
            try sequencer.start()
            state = .playing
        } catch let error as MIDIConversionError {
            throw error
        } catch {
            throw MIDIConversionError.playbackFailed(error.localizedDescription)
        }
    }

    public func pause() {
        guard let sequencer else {
            return
        }

        sequencer.stop()
        if loadedURL != nil {
            state = .paused
        }
    }

    public func stop() {
        sequencer?.stop()
        sequencer?.currentPositionInSeconds = 0
        synth?.stop()

        if loadedURL != nil {
            state = .stopped
        } else {
            state = .idle
        }
    }

    deinit {
        stop()
    }
}
