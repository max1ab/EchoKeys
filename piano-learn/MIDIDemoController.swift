import Combine
import Foundation
import MIDIAudioConverter

@MainActor
final class MIDIDemoController: ObservableObject {
    @Published private(set) var status = "Ready"
    @Published private(set) var playbackState: MIDIPlaybackState = .idle
    @Published private(set) var midiURL: URL?
    @Published private(set) var wavURL: URL?

    private let player = MIDIFilePlayer()
    private let renderer = MIDIFileRenderer()

    func prepareDemoMIDIIfNeeded() throws {
        if let midiURL, FileManager.default.fileExists(atPath: midiURL.path) {
            return
        }

        let tempDirectory = FileManager.default.temporaryDirectory.appending(path: "MIDIAudioConverterDemo", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )

        let demoURL = tempDirectory.appending(path: "demo.mid")
        try DemoMIDIFile.makeShortPianoMIDI().write(to: demoURL)
        midiURL = demoURL
        playbackState = .loaded
        status = "Prepared demo MIDI: \(demoURL.lastPathComponent)"
    }

    func playDemo() {
        do {
            try prepareDemoMIDIIfNeeded()
            guard let midiURL else { return }
            try player.load(midiURL: midiURL)
            try player.play()
            playbackState = player.state
            status = "Playing \(midiURL.lastPathComponent)"
        } catch {
            status = error.localizedDescription
        }
    }

    func pause() {
        player.pause()
        playbackState = player.state
        status = "Paused"
    }

    func stop() {
        player.stop()
        playbackState = player.state
        status = "Stopped"
    }

    func renderDemoWAV() {
        do {
            try prepareDemoMIDIIfNeeded()
            guard let midiURL else { return }
            let tempDirectory = FileManager.default.temporaryDirectory.appending(path: "MIDIAudioConverterDemo", directoryHint: .isDirectory)
            let outputURL = tempDirectory.appending(path: "demo.wav")
            let result = try renderer.renderMIDIFile(at: midiURL, to: outputURL, options: .default)
            wavURL = result.outputURL
            status = "Rendered WAV: \(outputURL.lastPathComponent) (\(String(format: "%.2f", result.duration))s)"
        } catch {
            status = error.localizedDescription
        }
    }
}
