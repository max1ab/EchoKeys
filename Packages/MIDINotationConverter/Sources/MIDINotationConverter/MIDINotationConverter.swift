import Foundation

public enum MIDINotationConverterModule {
    public static func makeJTFToMIDI() -> JTFToMIDI { JTFToMIDI() }

    public static func makeMIDIToJTF() -> MIDIToJTF { MIDIToJTF() }
}
