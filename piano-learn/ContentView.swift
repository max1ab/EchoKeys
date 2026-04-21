//
//  ContentView.swift
//  piano-learn
//
//  Created by r00t on 2026/4/12.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var controller = MIDIDemoController()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("MIDIAudioConverter Demo")
                .font(.title2.bold())

            Text("Playback: \(String(describing: controller.playbackState))")
                .font(.headline)

            Text(controller.status)
                .font(.body)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
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
        .frame(minWidth: 720, minHeight: 280)
    }
}

#Preview {
    ContentView()
}
