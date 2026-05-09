import Foundation

enum AppRoute: String, CaseIterable, Identifiable {
    case home
    case practiceHome
    case devMIDIInput
    case devPractice
    case devConverter

    var id: Self { self }

    static let productRoutes: [AppRoute] = [.home, .practiceHome]
    static let devRoutes: [AppRoute] = [.devMIDIInput, .devPractice, .devConverter]

    var title: String {
        switch self {
        case .home:
            "Home"
        case .practiceHome:
            "Practice"
        case .devMIDIInput:
            "MIDI Input"
        case .devPractice:
            "Practice Debug"
        case .devConverter:
            "MIDI / JTF Demo"
        }
    }

    var systemImage: String {
        switch self {
        case .home:
            "house"
        case .practiceHome:
            "music.quarternote.3"
        case .devMIDIInput:
            "pianokeys"
        case .devPractice:
            "metronome"
        case .devConverter:
            "music.note.list"
        }
    }
}
