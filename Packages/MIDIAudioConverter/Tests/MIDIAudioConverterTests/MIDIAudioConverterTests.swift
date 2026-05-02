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
    func inspectorReportsShortMIDIStats() throws {
        let tempDirectory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        let midiURL = tempDirectory.appending(path: "sample.mid")
        try MIDIByteFixtures.shortPianoMIDI().write(to: midiURL)

        let inspector = MIDIFileInspector()
        let info = try inspector.inspectMIDIFile(at: midiURL)

        #expect(info.trackCount == 1)
        #expect(info.noteEventCount == 2)
        #expect(info.tempoEventCount == 1)
        #expect(info.sustainPedalEventCount == 2)
        #expect(info.duration > 0.9)
        #expect(info.duration < 1.1)
    }

    @Test
    func inspectorHandlesEmptyAndMultiTrackMIDI() throws {
        let tempDirectory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        let emptyURL = tempDirectory.appending(path: "empty.mid")
        let multiURL = tempDirectory.appending(path: "multi.mid")
        try MIDIByteFixtures.emptyMIDI().write(to: emptyURL)
        try MIDIByteFixtures.multiTrackMIDI().write(to: multiURL)

        let inspector = MIDIFileInspector()
        let emptyInfo = try inspector.inspectMIDIFile(at: emptyURL)
        let multiInfo = try inspector.inspectMIDIFile(at: multiURL)

        #expect(emptyInfo.trackCount == 1)
        #expect(emptyInfo.noteEventCount == 0)
        #expect(emptyInfo.duration == 0)
        #expect(multiInfo.trackCount == 3)
        #expect(multiInfo.noteEventCount == 2)
        #expect(multiInfo.tempoEventCount == 1)
        #expect(multiInfo.duration > 0.4)
        #expect(multiInfo.duration < 0.6)
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
