//
//  ContentView.swift
//  piano-learn
//
//  Created by r00t on 2026/4/12.
//

import SwiftUI
import UniformTypeIdentifiers

private enum DevSection: String, CaseIterable, Identifiable {
    case home
    case midiInput
    case practice
    case converterDemo

    var id: Self { self }

    var title: String {
        switch self {
        case .home:
            "Home"
        case .midiInput:
            "MIDI Input"
        case .practice:
            "Practice"
        case .converterDemo:
            "MIDI / JTF Demo"
        }
    }

    var systemImage: String {
        switch self {
        case .home:
            "house"
        case .midiInput:
            "pianokeys"
        case .practice:
            "metronome"
        case .converterDemo:
            "music.note.list"
        }
    }
}

struct ContentView: View {
    @SceneStorage("selectedDevSection") private var selectedSectionRawValue = DevSection.home.rawValue
    @StateObject private var midiInputDebugController = MIDIInputDebugController()
    @StateObject private var practiceDebugController = PracticeDebugController()

    private var selectedSection: Binding<DevSection> {
        Binding {
            DevSection(rawValue: selectedSectionRawValue) ?? .home
        } set: { newValue in
            selectedSectionRawValue = newValue.rawValue
        }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: selectedSection) {
                ForEach(DevSection.allCases) { section in
                    Label(section.title, systemImage: section.systemImage)
                        .tag(section)
                }
            }
            .navigationTitle("Piano Learn")
            .listStyle(.sidebar)
        } detail: {
            switch selectedSection.wrappedValue {
            case .home:
                HomeView()
            case .midiInput:
                MIDIInputDebugView(controller: midiInputDebugController)
            case .practice:
                PracticeDebugView(controller: practiceDebugController)
            case .converterDemo:
                ConverterDemoView()
            }
        }
        .frame(minWidth: 900, minHeight: 600)
    }
}

private struct HomeView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Piano Learn")
                .font(.largeTitle.bold())

            Text("Select a test page from the sidebar.")
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct ConverterDemoView: View {
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

#Preview {
    ContentView()
}
