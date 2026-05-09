import Foundation
import PianoPracticeCore

struct MIDIInputNoteMessage: Sendable, Equatable {
    var timestampSeconds: Double
    var status: UInt8
    var data1: UInt8
    var data2: UInt8
}

final class MIDIInputRecordingBuilder {
    private struct PendingKey: Hashable {
        var channel: Int
        var pitch: Int
    }

    private let options: MIDIInputRecordingOptions
    private var firstNoteOnTimestamp: Double?
    private var pending: [PendingKey: [(timestampSeconds: Double, velocity: Int)]] = [:]
    private var notes: [NoteEvent] = []
    private var warnings: [String] = []

    init(options: MIDIInputRecordingOptions) throws {
        try Self.validate(options)
        self.options = options
    }

    static func validate(_ options: MIDIInputRecordingOptions) throws {
        guard options.tempoBPM > 0 else {
            throw MIDIInputError.invalidTempo(options.tempoBPM)
        }
        guard options.ticksPerBeat > 0 else {
            throw MIDIInputError.invalidTicksPerBeat(options.ticksPerBeat)
        }
    }

    func record(_ message: MIDIInputNoteMessage) {
        let statusClass = message.status & 0xF0
        let channel = Int(message.status & 0x0F)
        let pitch = Int(message.data1)
        let velocity = Int(message.data2)

        switch statusClass {
        case 0x90 where velocity > 0:
            recordNoteOn(
                channel: channel,
                pitch: pitch,
                velocity: velocity,
                timestampSeconds: message.timestampSeconds
            )
        case 0x80, 0x90:
            recordNoteOff(
                channel: channel,
                pitch: pitch,
                timestampSeconds: message.timestampSeconds
            )
        default:
            break
        }
    }

    func finish() -> MIDIInputRecording {
        for (key, queue) in pending where !queue.isEmpty {
            warnings.append("Discarded \(queue.count) unclosed note(s) channel=\(key.channel) pitch=\(key.pitch)")
        }
        pending.removeAll()

        return MIDIInputRecording(
            options: options,
            notes: notes.sorted {
                if $0.onsetBeat != $1.onsetBeat { return $0.onsetBeat < $1.onsetBeat }
                if $0.pitch != $1.pitch { return $0.pitch < $1.pitch }
                return $0.id < $1.id
            },
            warnings: warnings
        )
    }

    private func recordNoteOn(
        channel: Int,
        pitch: Int,
        velocity: Int,
        timestampSeconds: Double
    ) {
        if firstNoteOnTimestamp == nil {
            firstNoteOnTimestamp = timestampSeconds
        }

        let key = PendingKey(channel: channel, pitch: pitch)
        pending[key, default: []].append((timestampSeconds, velocity))
    }

    private func recordNoteOff(
        channel: Int,
        pitch: Int,
        timestampSeconds: Double
    ) {
        let key = PendingKey(channel: channel, pitch: pitch)
        guard var queue = pending[key], !queue.isEmpty else {
            warnings.append("Ignoring unmatched noteOff channel=\(channel) pitch=\(pitch)")
            return
        }

        let start = queue.removeFirst()
        pending[key] = queue.isEmpty ? nil : queue

        guard let zeroTimestamp = firstNoteOnTimestamp else {
            warnings.append("Ignoring noteOff before first noteOn channel=\(channel) pitch=\(pitch)")
            return
        }

        let durationSeconds = timestampSeconds - start.timestampSeconds
        guard durationSeconds > 0 else {
            warnings.append("Ignoring non-positive note duration channel=\(channel) pitch=\(pitch)")
            return
        }

        let onsetBeat = secondsToBeats(start.timestampSeconds - zeroTimestamp)
        let durationBeat = secondsToBeats(durationSeconds)
        let note = NoteEvent(
            id: "\(options.idPrefix)-\(String(format: "%06d", notes.count))",
            pitch: pitch,
            onsetBeat: onsetBeat,
            durationBeat: durationBeat,
            velocity: start.velocity,
            trackIndex: 0,
            channel: channel
        )
        notes.append(note)
    }

    private func secondsToBeats(_ seconds: Double) -> Double {
        seconds * options.tempoBPM / 60.0
    }
}
