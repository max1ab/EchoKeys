import MIDIInputKit
import PianoPracticeCore
import SwiftUI

struct MIDIInputDebugView: View {
    @ObservedObject var controller: MIDIInputDebugController

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            devicePanel
            recordingPanel
            eventPanel

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("MIDI Input Debug")
                .font(.title2.bold())

            Text(controller.status)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }

    private var devicePanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Device")
                .font(.headline)

            HStack(spacing: 12) {
                Picker("Input", selection: $controller.selectedDeviceID) {
                    if controller.devices.isEmpty {
                        Text("No devices").tag(Optional<MIDIInputDevice.ID>.none)
                    }

                    ForEach(controller.devices) { device in
                        Text(deviceLabel(for: device)).tag(Optional(device.id))
                    }
                }
                .frame(maxWidth: 360)

                Button("Refresh") {
                    controller.refreshDevices()
                }

                Button("Connect") {
                    controller.connectSelectedDevice()
                }
                .disabled(controller.selectedDeviceID == nil)

                Button("Disconnect") {
                    controller.disconnect()
                }
                .disabled(controller.connectedDevice == nil)
            }

            if let connectedDevice = controller.connectedDevice {
                Text("Connected: \(deviceLabel(for: connectedDevice))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }

    private var recordingPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recording")
                .font(.headline)

            HStack(spacing: 12) {
                TextField("Tempo", value: $controller.tempoBPM, format: .number.precision(.fractionLength(0...1)))
                    .frame(width: 96)

                Text("BPM")
                    .foregroundStyle(.secondary)

                Button("Start") {
                    controller.startRecording()
                }
                .disabled(controller.connectedDevice == nil || controller.isRecording)

                Button("Stop") {
                    controller.stopRecording()
                }
                .disabled(!controller.isRecording)

                Button("Export MIDI") {
                    controller.exportLastRecording()
                }
                .disabled(controller.notes.isEmpty || controller.isRecording)
            }

            if let exportedMIDIURL = controller.exportedMIDIURL {
                Text("Exported: \(exportedMIDIURL.path)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }

    private var eventPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Note Events")
                    .font(.headline)

                Spacer()

                Text("\(controller.notes.count)")
                    .foregroundStyle(.secondary)
            }

            Table(controller.notes) {
                TableColumn("ID") { note in
                    Text(note.id)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(1)
                }

                TableColumn("Pitch") { note in
                    Text("\(note.pitch)")
                }

                TableColumn("Onset") { note in
                    Text(formatBeat(note.onsetBeat))
                }

                TableColumn("Duration") { note in
                    Text(formatBeat(note.durationBeat))
                }

                TableColumn("Velocity") { note in
                    Text("\(note.velocity)")
                }

                TableColumn("Channel") { note in
                    Text("\(note.channel)")
                }
            }
            .frame(minHeight: 220)

            if !controller.warnings.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Warnings")
                        .font(.subheadline.bold())

                    ForEach(controller.warnings, id: \.self) { warning in
                        Text(warning)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
            }
        }
    }

    private func deviceLabel(for device: MIDIInputDevice) -> String {
        if let manufacturer = device.manufacturer, !manufacturer.isEmpty {
            return "\(device.name) (\(manufacturer))"
        }

        return device.name
    }

    private func formatBeat(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...3)))
    }
}
