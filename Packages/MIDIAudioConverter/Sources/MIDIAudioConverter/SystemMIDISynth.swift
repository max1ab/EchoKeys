import AVFoundation
import AudioToolbox
import Foundation

final class SystemMIDISynth {
    let engine: AVAudioEngine
    let instrument: AVAudioUnitMIDIInstrument

    init(
        outputVolume: Float = 1.0,
        offlineFormat: AVAudioFormat? = nil,
        maximumFrameCount: AVAudioFrameCount = 4_096
    ) throws {
        engine = AVAudioEngine()

        let description = AudioComponentDescription(
            componentType: kAudioUnitType_MusicDevice,
            componentSubType: kAudioUnitSubType_DLSSynth,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )

        instrument = AVAudioUnitMIDIInstrument(audioComponentDescription: description)
        engine.attach(instrument)
        engine.connect(instrument, to: engine.mainMixerNode, format: nil)
        engine.mainMixerNode.outputVolume = outputVolume

        if let offlineFormat {
            try engine.enableManualRenderingMode(
                .offline,
                format: offlineFormat,
                maximumFrameCount: maximumFrameCount
            )
        }

        applyDefaultPiano()
        engine.prepare()
    }

    func start() throws {
        do {
            if engine.isRunning == false {
                try engine.start()
            }
        } catch {
            throw MIDIConversionError.audioEngineFailed(error.localizedDescription)
        }
    }

    func stop() {
        engine.stop()
    }

    private func applyDefaultPiano() {
        for channel: UInt8 in 0..<16 {
            instrument.sendProgramChange(0, onChannel: channel)
        }
    }
}
