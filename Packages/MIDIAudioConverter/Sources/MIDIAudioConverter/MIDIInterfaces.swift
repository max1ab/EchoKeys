import Foundation

public protocol MIDIFilePlaying: AnyObject {
    func load(midiURL: URL) throws
    func play() throws
    func pause()
    func stop()
    var state: MIDIPlaybackState { get }
}

public protocol MIDIFileRendering {
    func renderMIDIFile(
        at midiURL: URL,
        to outputURL: URL,
        options: MIDIRenderOptions
    ) throws -> MIDIAudioRenderResult
}
