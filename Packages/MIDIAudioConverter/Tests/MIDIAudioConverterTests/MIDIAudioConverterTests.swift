import AVFoundation
import Foundation
import Testing
@testable import MIDIAudioConverter

struct MIDIAudioConverterTests {
    @Test
    func playerLoadsAndTransitionsState() throws {
        let tempDirectory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        let midiURL = tempDirectory.appending(path: "sample.mid")
        try MIDIByteFixtures.shortPianoMIDI().write(to: midiURL)

        let player = MIDIFilePlayer()
        #expect(player.state == .idle)

        try player.load(midiURL: midiURL)
        #expect(player.state == .loaded)

        try player.play()
        #expect(player.state == .playing)

        player.pause()
        #expect(player.state == .paused)

        player.stop()
        #expect(player.state == .stopped)
    }

    @Test
    func invalidInputsFailPredictably() throws {
        let tempDirectory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        let textURL = tempDirectory.appending(path: "bad.txt")
        try Data("not midi".utf8).write(to: textURL)

        let player = MIDIFilePlayer()
        #expect(throws: MIDIConversionError.unsupportedInputType("txt")) {
            try player.load(midiURL: textURL)
        }

        let missingURL = tempDirectory.appending(path: "missing.mid")
        #expect(throws: MIDIConversionError.fileNotFound(missingURL)) {
            try player.load(midiURL: missingURL)
        }
    }

    @Test
    func rendererCreatesWaveFile() throws {
        let tempDirectory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        let midiURL = tempDirectory.appending(path: "sample.mid")
        let wavURL = tempDirectory.appending(path: "sample.wav")
        try MIDIByteFixtures.shortPianoMIDI().write(to: midiURL)

        let renderer = MIDIFileRenderer()
        let result = try renderer.renderMIDIFile(at: midiURL, to: wavURL, options: .default)

        #expect(FileManager.default.fileExists(atPath: wavURL.path))
        #expect(result.fileSize > 0)
        #expect(result.duration > 0.5)

        let file = try AVAudioFile(forReading: wavURL)
        let actualDuration = Double(file.length) / file.processingFormat.sampleRate
        #expect(abs(actualDuration - result.duration) < 0.1)
    }

    @Test
    func rendererHandlesEmptyAndMultiTrackMIDI() throws {
        let tempDirectory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        let emptyURL = tempDirectory.appending(path: "empty.mid")
        let emptyWAV = tempDirectory.appending(path: "empty.wav")
        let multiURL = tempDirectory.appending(path: "multi.mid")
        let multiWAV = tempDirectory.appending(path: "multi.wav")

        try MIDIByteFixtures.emptyMIDI().write(to: emptyURL)
        try MIDIByteFixtures.multiTrackMIDI().write(to: multiURL)

        let renderer = MIDIFileRenderer()
        let emptyResult = try renderer.renderMIDIFile(at: emptyURL, to: emptyWAV, options: .default)
        let multiResult = try renderer.renderMIDIFile(at: multiURL, to: multiWAV, options: .default)

        #expect(emptyResult.fileSize > 0)
        #expect(multiResult.fileSize > 0)
        #expect(multiResult.duration > 0.5)
    }
}
