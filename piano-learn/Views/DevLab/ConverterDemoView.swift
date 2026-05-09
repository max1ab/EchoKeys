import SwiftUI
import UniformTypeIdentifiers

struct ConverterDemoView: View {
    @StateObject private var controller = MIDIDemoController()
    @State private var isMIDIImporterPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("MIDI / JTF Converter Demo")
                .font(.title2.bold())

            Text("Playback: \(String(describing: controller.playbackState))")
                .font(.headline)

            Text(controller.status)
                .font(.body)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button("Choose MIDI File") {
                    isMIDIImporterPresented = true
                }

                Button("MIDI to JTF") {
                    controller.convertSelectedMIDIToJTF()
                }

                Button("Play Demo MIDI") {
                    controller.playDemo()
                }

                Button("Pause") {
                    controller.pause()
                }

                Button("Stop") {
                    controller.stop()
                }

                Button("Render WAV") {
                    controller.renderDemoWAV()
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Text("JTF")
                        .font(.headline)

                    Spacer()

                    Button("Load Example") {
                        controller.loadBuiltInJTFExample()
                    }

                    Button("JTF to MIDI") {
                        controller.convertJTFToMIDI()
                    }

                    Button("Play JTF") {
                        controller.convertJTFToMIDI(playAfterConversion: true)
                    }
                }

                TextEditor(text: $controller.jtfText)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 180)
                    .scrollContentBackground(.hidden)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(nsColor: .separatorColor))
                    )
            }

            if let midiURL = controller.midiURL {
                Text("MIDI: \(midiURL.path)")
                    .font(.caption)
                    .textSelection(.enabled)
            }

            if let wavURL = controller.wavURL {
                Text("WAV: \(wavURL.path)")
                    .font(.caption)
                    .textSelection(.enabled)
            }

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .fileImporter(
            isPresented: $isMIDIImporterPresented,
            allowedContentTypes: [.midi],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case let .success(urls):
                guard let url = urls.first else { return }
                controller.selectMIDIFile(url)
            case let .failure(error):
                controller.selectImportFailure(error)
            }
        }
    }
}
