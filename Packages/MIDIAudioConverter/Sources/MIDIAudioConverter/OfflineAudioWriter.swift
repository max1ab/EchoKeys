import AVFoundation
import Foundation

enum OfflineAudioWriter {
    static func write(
        engine: AVAudioEngine,
        to outputURL: URL,
        duration: TimeInterval,
        options: MIDIRenderOptions
    ) throws -> MIDIAudioRenderResult {
        try MIDISequenceLoader.validateOutputURL(outputURL)

        let directoryURL = outputURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true,
            attributes: nil
        )
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        let renderFormat = engine.manualRenderingFormat
        let frameCapacity = engine.manualRenderingMaximumFrameCount
        guard let buffer = AVAudioPCMBuffer(pcmFormat: renderFormat, frameCapacity: frameCapacity) else {
            throw MIDIConversionError.renderFailed("Unable to allocate an offline render buffer.")
        }

        let totalFrameCount = max(
            AVAudioFramePosition(ceil(max(duration, 0.01) * options.sampleRate)),
            1
        )

        let audioFile: AVAudioFile
        do {
            audioFile = try AVAudioFile(forWriting: outputURL, settings: renderFormat.settings)
        } catch {
            throw MIDIConversionError.fileWriteFailed(error.localizedDescription)
        }

        while engine.manualRenderingSampleTime < totalFrameCount {
            let framesRemaining = totalFrameCount - engine.manualRenderingSampleTime
            let framesToRender = AVAudioFrameCount(
                min(Int64(frameCapacity), Int64(framesRemaining))
            )

            let status = try engine.renderOffline(framesToRender, to: buffer)
            switch status {
            case .success:
                if buffer.frameLength > 0 {
                    try audioFile.write(from: buffer)
                }
            case .insufficientDataFromInputNode, .cannotDoInCurrentContext:
                continue
            case .error:
                throw MIDIConversionError.renderFailed("Offline renderer returned an error status.")
            @unknown default:
                throw MIDIConversionError.renderFailed("Offline renderer returned an unknown status.")
            }
        }

        let fileSize: UInt64
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: outputURL.path)
            fileSize = attributes[.size] as? UInt64 ?? 0
        } catch {
            fileSize = 0
        }

        return MIDIAudioRenderResult(
            outputURL: outputURL,
            duration: Double(totalFrameCount) / options.sampleRate,
            sampleRate: options.sampleRate,
            frameCount: Int64(totalFrameCount),
            fileSize: fileSize
        )
    }
}
