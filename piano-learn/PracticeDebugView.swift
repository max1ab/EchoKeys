import MIDIInputKit
import MIDIPracticeKit
import SwiftUI

struct PracticeDebugView: View {
    @ObservedObject var controller: PracticeDebugController

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            editor
            deviceControls
            practiceControls
            resultPanel

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Practice Debug")
                .font(.title2.bold())

            Text(controller.status)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Target JTF")
                    .font(.headline)

                Spacer()

                Button("Load Example") {
                    controller.loadExample()
                }

                Button("Prepare Target") {
                    controller.prepareTarget()
                }
            }

            TextEditor(text: $controller.jtfText)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 130)
                .scrollContentBackground(.hidden)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(nsColor: .separatorColor))
                )
        }
    }

    private var deviceControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Input Device")
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
        }
    }

    private var practiceControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Practice")
                .font(.headline)

            HStack(spacing: 12) {
                TextField("Tempo", value: $controller.tempoBPM, format: .number.precision(.fractionLength(0...1)))
                    .frame(width: 96)

                Text("BPM")
                    .foregroundStyle(.secondary)

                Button("Start Recording") {
                    controller.startRecording()
                }
                .disabled(controller.connectedDevice == nil || controller.isRecording)

                Button("Stop and Score") {
                    controller.stopAndScore()
                }
                .disabled(!controller.isRecording)

                Button("Simulate Perfect") {
                    controller.simulatePerfectPerformance()
                }
            }

            if let targetMIDIURL = controller.targetMIDIURL {
                Text("Target MIDI: \(targetMIDIURL.path)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            if let performanceMIDIURL = controller.performanceMIDIURL {
                Text("Performance MIDI: \(performanceMIDIURL.path)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }

    private var resultPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Score")
                .font(.headline)

            if let report = controller.report {
                LazyVGrid(
                    columns: [
                        GridItem(.fixed(170), alignment: .leading),
                        GridItem(.fixed(170), alignment: .leading),
                        GridItem(.fixed(170), alignment: .leading)
                    ],
                    alignment: .leading,
                    spacing: 12
                ) {
                    scoreMetric("Pitch", report.level1.pitchAccuracy)
                    scoreMetric("Completeness", report.level1.completeness)
                    scoreMetric("Timing", report.level2.onsetTimingScore)
                    scoreMetric("Duration", report.level2.durationScore)
                    countMetric("Matched", report.level1.matchedCount)
                    countMetric("Missed", report.level1.missedCount)
                    countMetric("Extra", report.level1.extraCount)
                    countMetric("Wrong Pitch", report.level1.wrongPitchCount)
                    countMetric("Errors", report.errors.count)
                }

                if !report.errors.isEmpty {
                    Table(report.errors) {
                        TableColumn("Type") { item in
                            Text(item.type.rawValue)
                        }

                        TableColumn("Severity") { item in
                            Text(item.severity.rawValue)
                        }

                        TableColumn("Message") { item in
                            Text(item.message)
                                .lineLimit(2)
                        }
                    }
                    .frame(minHeight: 140)
                }

                if !report.warnings.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Warnings")
                            .font(.subheadline.bold())

                        ForEach(report.warnings, id: \.self) { warning in
                            Text(warning)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                }
            } else {
                Text("No score yet.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func scoreMetric(_ title: String, _ value: Double) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value.formatted(.number.precision(.fractionLength(0...3))))
                .font(.title3.monospacedDigit())
        }
    }

    private func countMetric(_ title: String, _ value: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(value)")
                .font(.title3.monospacedDigit())
        }
    }

    private func deviceLabel(for device: MIDIInputDevice) -> String {
        if let manufacturer = device.manufacturer, !manufacturer.isEmpty {
            return "\(device.name) (\(manufacturer))"
        }

        return device.name
    }
}
