import Combine
import Foundation
import MIDIAudioConverter
import MIDINotationConverter

@MainActor
final class MIDIDemoController: ObservableObject {
    static let builtInJTFExample = """
    1=C 4/4 120
    | 1 2 3 4 | 5 - 5 - |
    | 6_ 7_ [1] 7 | 6 5 3 1 ||
    """

    @Published private(set) var status = "Ready"
    @Published private(set) var playbackState: MIDIPlaybackState = .idle
    @Published private(set) var midiURL: URL?
    @Published private(set) var wavURL: URL?
    @Published var jtfText = MIDIDemoController.builtInJTFExample

    private let player = MIDIFilePlayer()
    private let renderer = MIDIFileRenderer()
    private let jtfToMIDI = JTFToMIDI()
    private let midiToJTF = MIDIToJTF()

    func selectMIDIFile(_ url: URL) {
        player.stop()
        midiURL = url
        wavURL = nil
        playbackState = .loaded
        status = "Selected MIDI: \(url.lastPathComponent)"
    }

    func selectImportFailure(_ error: Error) {
        status = "Import failed: \(error.localizedDescription)"
    }

    func loadBuiltInJTFExample() {
        jtfText = Self.builtInJTFExample
        status = "Loaded built-in JTF example"
    }

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
            try withSecurityScopedAccess(to: midiURL) {
                try player.load(midiURL: midiURL)
                try player.play()
            }
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
            try FileManager.default.createDirectory(
                at: tempDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
            let baseName = midiURL.deletingPathExtension().lastPathComponent
            let outputURL = tempDirectory.appending(path: "\(baseName).wav")
            let result = try withSecurityScopedAccess(to: midiURL) {
                try renderer.renderMIDIFile(at: midiURL, to: outputURL, options: .default)
            }
            wavURL = result.outputURL
            status = "Rendered WAV: \(outputURL.lastPathComponent) (\(String(format: "%.2f", result.duration))s)"
        } catch {
            status = error.localizedDescription
        }
    }

    func convertJTFToMIDI(playAfterConversion: Bool = false) {
        do {
            let outputURL = try makeTemporaryOutputURL(baseName: "jtf-converted", extension: "mid")
            let result = try jtfToMIDI.convert(jtfText, to: outputURL)
            player.stop()
            midiURL = result.outputURL
            wavURL = nil
            playbackState = .loaded

            if playAfterConversion {
                try player.load(midiURL: result.outputURL)
                try player.play()
                playbackState = player.state
                status = "Converted and playing MIDI: \(result.outputURL.lastPathComponent)"
            } else {
                status = "Converted JTF to MIDI: \(result.outputURL.lastPathComponent)"
            }
        } catch {
            status = error.localizedDescription
        }
    }

    func convertSelectedMIDIToJTF() {
        do {
            try prepareDemoMIDIIfNeeded()
            guard let midiURL else { return }
            let text = try withSecurityScopedAccess(to: midiURL) {
                try midiToJTF.convert(midiURL: midiURL)
            }
            jtfText = text
            status = "Converted MIDI to JTF: \(midiURL.lastPathComponent)"
        } catch {
            status = error.localizedDescription
        }
    }

    private func makeTemporaryOutputURL(baseName: String, extension pathExtension: String) throws -> URL {
        let tempDirectory = FileManager.default.temporaryDirectory.appending(path: "MIDIAudioConverterDemo", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        let timestamp = Int(Date().timeIntervalSince1970)
        return tempDirectory.appending(path: "\(baseName)-\(timestamp).\(pathExtension)")
    }

    private func withSecurityScopedAccess<T>(to url: URL, operation: () throws -> T) throws -> T {
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try operation()
    }
}
