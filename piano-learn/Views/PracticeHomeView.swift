import SwiftUI

struct PracticeHomeView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Practice")
                    .font(.largeTitle.bold())

                Text("Connect a MIDI keyboard, listen, play back, and review your score.")
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .top, spacing: 16) {
                practiceArea(title: "Device", value: "No keyboard connected")
                practiceArea(title: "Session", value: "No practice session started")
                practiceArea(title: "Score", value: "No score yet")
            }

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func practiceArea(title: String, value: String) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Text(value)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        } label: {
            Text(title)
                .font(.headline)
        }
    }
}
