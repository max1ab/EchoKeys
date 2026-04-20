import Foundation

public enum MIDIAudioConverterModule {
    public static func makePlayer(options: MIDIPlaybackOptions = .default) -> MIDIFilePlayer {
        MIDIFilePlayer(options: options)
    }

    public static func makeRenderer() -> MIDIFileRenderer {
        MIDIFileRenderer()
    }
}
