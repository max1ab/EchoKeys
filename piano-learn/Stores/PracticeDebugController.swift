import Combine
import Foundation
import MIDIInputKit
import MIDINotationConverter
import MIDIPracticeKit

@MainActor
final class PracticeDebugController: ObservableObject {
    static let defaultJTF = """
    1=C 4/4 120
    | 1 2 3 4 | 5 - 5 - ||
    """

    @Published var jtfText = PracticeDebugController.defaultJTF
    @Published var tempoBPM = 120.0
    @Published private(set) var devices: [MIDIInputDevice] = []
    @Published var selectedDeviceID: MIDIInputDevice.ID?
    @Published private(set) var connectedDevice: MIDIInputDevice?
    @Published private(set) var isRecording = false
    @Published private(set) var status = "Ready"
    @Published private(set) var recording: MIDIInputRecording?
    @Published private(set) var report: MIDIPracticeReport?
    @Published private(set) var targetMIDIURL: URL?
    @Published private(set) var performanceMIDIURL: URL?

    private let recorder: MIDIInputRecorder?
    private var targetMIDIData: Data?

    init() {
        do {
            recorder = try MIDIInputRecorder()
            refreshDevices()
        } catch {
            recorder = nil
            status = "MIDI recorder unavailable: \(error.localizedDescription)"
        }
    }

    var selectedDevice: MIDIInputDevice? {
        guard let selectedDeviceID else { return nil }
        return devices.first { $0.id == selectedDeviceID }
    }

    func loadExample() {
        jtfText = Self.defaultJTF
        status = "Loaded example phrase"
    }

    func refreshDevices() {
        guard let recorder else {
            devices = []
            selectedDeviceID = nil
            status = "MIDI recorder unavailable"
            return
        }

        devices = recorder.availableDevices()
        if let selectedDeviceID, devices.contains(where: { $0.id == selectedDeviceID }) {
            status = "Found \(devices.count) MIDI input device(s)"
        } else {
            selectedDeviceID = devices.first?.id
            status = devices.isEmpty ? "No MIDI input devices found" : "Found \(devices.count) MIDI input device(s)"
        }
    }

    func connectSelectedDevice() {
        guard let recorder else {
            status = "MIDI recorder unavailable"
            return
        }

        guard let device = selectedDevice else {
            status = "Select a MIDI input device first"
            return
        }

        do {
            try recorder.connect(to: device)
            connectedDevice = device
            status = "Connected: \(device.name)"
        } catch {
            status = error.localizedDescription
        }
    }

    func disconnect() {
        guard let recorder else {
            connectedDevice = nil
            isRecording = false
            status = "MIDI recorder unavailable"
            return
        }

        if isRecording {
            _ = try? recorder.stopRecording()
            isRecording = false
        }

        recorder.disconnect()
        connectedDevice = nil
        status = "Disconnected"
    }

    func prepareTarget() {
        do {
            targetMIDIData = try makeTargetMIDIData()
            report = nil
            recording = nil
            performanceMIDIURL = nil
            status = "Target phrase ready"
        } catch {
            status = error.localizedDescription
        }
    }

    func startRecording() {
        guard let recorder else {
            status = "MIDI recorder unavailable"
            return
        }

        do {
            if targetMIDIData == nil {
                targetMIDIData = try makeTargetMIDIData()
            }

            report = nil
            recording = nil
            performanceMIDIURL = nil
            try recorder.startRecording(options: MIDIInputRecordingOptions(tempoBPM: tempoBPM, idPrefix: "practice"))
            isRecording = true
            status = "Recording performance"
        } catch {
            status = error.localizedDescription
        }
    }

    func stopAndScore() {
        guard let recorder else {
            isRecording = false
            status = "MIDI recorder unavailable"
            return
        }

        do {
            let recording = try recorder.stopRecording()
            isRecording = false
            self.recording = recording
            try score(recording: recording)
        } catch {
            status = error.localizedDescription
        }
    }

    func simulatePerfectPerformance() {
        do {
            let targetMIDIData = try makeTargetMIDIData()
            self.targetMIDIData = targetMIDIData
            let report = try MIDIPracticeKit().score(
                targetMIDI: targetMIDIData,
                performanceMIDI: targetMIDIData,
                targetJTF: jtfText
            )
            self.report = report
            recording = nil
            performanceMIDIURL = targetMIDIURL
            status = "Simulated perfect performance"
        } catch {
            status = error.localizedDescription
        }
    }

    private func score(recording: MIDIInputRecording) throws {
        let targetMIDIData = try targetMIDIData ?? makeTargetMIDIData()
        self.targetMIDIData = targetMIDIData

        let performanceMIDIData = try recording.exportMIDIData()
        let performanceURL = FileManager.default.temporaryDirectory
            .appending(path: "PracticePerformance-\(Int(Date().timeIntervalSince1970)).mid")
        try performanceMIDIData.write(to: performanceURL)
        performanceMIDIURL = performanceURL

        report = try MIDIPracticeKit().score(
            targetMIDI: targetMIDIData,
            performanceMIDI: performanceMIDIData,
            targetJTF: jtfText
        )
        status = "Scored \(recording.notes.count) recorded note(s)"
    }

    private func makeTargetMIDIData() throws -> Data {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "PracticeTarget-\(Int(Date().timeIntervalSince1970)).mid")
        let result = try JTFToMIDI().convert(jtfText, to: url)
        targetMIDIURL = result.outputURL
        return try Data(contentsOf: result.outputURL)
    }
}
