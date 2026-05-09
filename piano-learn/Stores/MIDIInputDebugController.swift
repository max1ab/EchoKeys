import Combine
import Foundation
import MIDIInputKit
import PianoPracticeCore

@MainActor
final class MIDIInputDebugController: ObservableObject {
    @Published private(set) var devices: [MIDIInputDevice] = []
    @Published var selectedDeviceID: MIDIInputDevice.ID?
    @Published var tempoBPM = 120.0
    @Published private(set) var connectedDevice: MIDIInputDevice?
    @Published private(set) var isRecording = false
    @Published private(set) var notes: [NoteEvent] = []
    @Published private(set) var warnings: [String] = []
    @Published private(set) var status = "Ready"
    @Published private(set) var exportedMIDIURL: URL?

    private let recorder: MIDIInputRecorder?
    private var lastRecording: MIDIInputRecording?

    init() {
        do {
            recorder = try MIDIInputRecorder()
            status = "MIDI recorder ready"
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
            return
        }

        selectedDeviceID = devices.first?.id
        status = devices.isEmpty ? "No MIDI input devices found" : "Found \(devices.count) MIDI input device(s)"
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

    func startRecording() {
        guard let recorder else {
            status = "MIDI recorder unavailable"
            return
        }

        do {
            notes = []
            warnings = []
            exportedMIDIURL = nil
            lastRecording = nil
            let options = MIDIInputRecordingOptions(tempoBPM: tempoBPM, idPrefix: "debug-input")
            try recorder.startRecording(options: options)
            isRecording = true
            status = "Recording. Play notes on the connected MIDI device."
        } catch {
            status = error.localizedDescription
        }
    }

    func stopRecording() {
        guard let recorder else {
            isRecording = false
            status = "MIDI recorder unavailable"
            return
        }

        do {
            let recording = try recorder.stopRecording()
            lastRecording = recording
            notes = recording.notes
            warnings = recording.warnings
            isRecording = false
            status = "Recorded \(recording.notes.count) note event(s)"
        } catch {
            status = error.localizedDescription
        }
    }

    func exportLastRecording() {
        guard let lastRecording else {
            status = "Record something before exporting MIDI"
            return
        }

        do {
            let data = try lastRecording.exportMIDIData()
            let url = FileManager.default.temporaryDirectory
                .appending(path: "MIDIInputDebug-\(Int(Date().timeIntervalSince1970)).mid")
            try data.write(to: url)
            exportedMIDIURL = url
            status = "Exported MIDI: \(url.lastPathComponent)"
        } catch {
            status = error.localizedDescription
        }
    }
}
