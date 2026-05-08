import Foundation
import MIDIPracticeSampleSupport

let ticksPerQuarter = 480
let writer = SimpleMIDIWriter(ticksPerQuarter: ticksPerQuarter)
let repositoryRoot = try SamplePaths.repositoryRoot()
let samplesRoot = SamplePaths.samplesRoot(from: repositoryRoot)
let generatedRoot = samplesRoot.appendingPathComponent("generated")
let basicRoot = generatedRoot
    .appendingPathComponent("basic")

if FileManager.default.fileExists(atPath: generatedRoot.path) {
    try FileManager.default.removeItem(at: generatedRoot)
}

try FileManager.default.createDirectory(
    at: basicRoot,
    withIntermediateDirectories: true
)

let targetNotes = [
    SampleMIDINote(pitch: 60, startTick: tick(0.0), durationTick: tick(0.5)),
    SampleMIDINote(pitch: 62, startTick: tick(0.5), durationTick: tick(0.5)),
    SampleMIDINote(pitch: 64, startTick: tick(1.0), durationTick: tick(1.0)),
    SampleMIDINote(pitch: 67, startTick: tick(2.0), durationTick: tick(2.0)),
    SampleMIDINote(pitch: 65, startTick: tick(4.0), durationTick: tick(0.5)),
    SampleMIDINote(pitch: 64, startTick: tick(4.5), durationTick: tick(0.5)),
    SampleMIDINote(pitch: 62, startTick: tick(5.0), durationTick: tick(1.0)),
    SampleMIDINote(pitch: 60, startTick: tick(6.0), durationTick: tick(2.0)),
]

let wrongPitchNotes = [
    SampleMIDINote(pitch: 60, startTick: tick(0.0), durationTick: tick(0.5)),
    SampleMIDINote(pitch: 62, startTick: tick(0.5), durationTick: tick(0.5)),
    SampleMIDINote(pitch: 66, startTick: tick(1.0), durationTick: tick(1.0)),
    SampleMIDINote(pitch: 67, startTick: tick(2.0), durationTick: tick(2.0)),
    SampleMIDINote(pitch: 65, startTick: tick(4.0), durationTick: tick(0.5)),
    SampleMIDINote(pitch: 64, startTick: tick(4.5), durationTick: tick(0.5)),
    SampleMIDINote(pitch: 62, startTick: tick(5.0), durationTick: tick(1.0)),
    SampleMIDINote(pitch: 60, startTick: tick(6.0), durationTick: tick(2.0)),
]

let looseNotes = zip(targetNotes, [0.00, 0.04, -0.03, 0.07, 0.02, -0.05, 0.06, -0.02]).map { note, delta in
    SampleMIDINote(
        pitch: note.pitch,
        startTick: note.startTick + tick(delta),
        durationTick: note.durationTick,
        velocity: note.velocity
    )
}

let pauseNotes = targetNotes.enumerated().map { index, note in
    let pause = index >= 4 ? 0.75 : 0
    return SampleMIDINote(
        pitch: note.pitch,
        startTick: note.startTick + tick(pause),
        durationTick: note.durationTick,
        velocity: note.velocity
    )
}

let fixNotes = [
    SampleMIDINote(pitch: 60, startTick: tick(0.0), durationTick: tick(0.5)),
    SampleMIDINote(pitch: 62, startTick: tick(0.5), durationTick: tick(0.5)),
    SampleMIDINote(pitch: 65, startTick: tick(1.0), durationTick: tick(0.35)),
    SampleMIDINote(pitch: 64, startTick: tick(1.12), durationTick: tick(1.0)),
    SampleMIDINote(pitch: 67, startTick: tick(2.0), durationTick: tick(2.0)),
    SampleMIDINote(pitch: 65, startTick: tick(4.0), durationTick: tick(0.5)),
    SampleMIDINote(pitch: 64, startTick: tick(4.5), durationTick: tick(0.5)),
    SampleMIDINote(pitch: 62, startTick: tick(5.0), durationTick: tick(1.0)),
    SampleMIDINote(pitch: 60, startTick: tick(6.0), durationTick: tick(2.0)),
]

let shortNotes = targetNotes.map { note in
    SampleMIDINote(
        pitch: note.pitch,
        startTick: note.startTick,
        durationTick: max(tick(0.12), Int(Double(note.durationTick) * 0.35)),
        velocity: note.velocity
    )
}

let leadInNotes = targetNotes.map { note in
    SampleMIDINote(
        pitch: note.pitch,
        startTick: note.startTick + tick(2.0),
        durationTick: note.durationTick,
        velocity: note.velocity
    )
}

let speedNotes = targetNotes.map { note in
    SampleMIDINote(
        pitch: note.pitch,
        startTick: tick((Double(note.startTick) / Double(ticksPerQuarter)) * 0.9),
        durationTick: max(tick(0.12), tick((Double(note.durationTick) / Double(ticksPerQuarter)) * 0.9)),
        velocity: note.velocity
    )
}

try writer.makeFile(notes: targetNotes)
    .write(to: basicRoot.appendingPathComponent("target.mid"))
try writer.makeFile(notes: targetNotes)
    .write(to: basicRoot.appendingPathComponent("perfect.mid"))
try writer.makeFile(notes: wrongPitchNotes)
    .write(to: basicRoot.appendingPathComponent("wrong-pitch.mid"))
try writer.makeFile(notes: looseNotes)
    .write(to: basicRoot.appendingPathComponent("loose.mid"))
try writer.makeFile(notes: pauseNotes)
    .write(to: basicRoot.appendingPathComponent("pause.mid"))
try writer.makeFile(notes: fixNotes)
    .write(to: basicRoot.appendingPathComponent("fix.mid"))
try writer.makeFile(notes: shortNotes)
    .write(to: basicRoot.appendingPathComponent("short.mid"))
try writer.makeFile(notes: leadInNotes)
    .write(to: basicRoot.appendingPathComponent("lead-in.mid"))
try writer.makeFile(notes: speedNotes)
    .write(to: basicRoot.appendingPathComponent("speed.mid"))

let manifest = SampleManifest(cases: [
    SampleCase(
        name: "perfect",
        target: "generated/basic/target.mid",
        performance: "generated/basic/perfect.mid",
        expected: ExpectedCounts(
            matchedCount: 8,
            missedCount: 0,
            extraCount: 0,
            wrongPitchCount: 0
        ),
        scoreRanges: ScoreRanges(
            onsetTimingScore: ScoreRange(min: 1, max: 1),
            interOnsetScore: ScoreRange(min: 1, max: 1),
            durationScore: ScoreRange(min: 1, max: 1)
        )
    ),
    SampleCase(
        name: "wrong-pitch",
        target: "generated/basic/target.mid",
        performance: "generated/basic/wrong-pitch.mid",
        expected: ExpectedCounts(
            matchedCount: 7,
            missedCount: 0,
            extraCount: 0,
            wrongPitchCount: 1
        ),
        scoreRanges: ScoreRanges(
            onsetTimingScore: ScoreRange(min: 1, max: 1),
            interOnsetScore: ScoreRange(min: 1, max: 1),
            durationScore: ScoreRange(min: 0.95, max: 1)
        )
    ),
    SampleCase(
        name: "loose",
        target: "generated/basic/target.mid",
        performance: "generated/basic/loose.mid",
        expected: ExpectedCounts(
            matchedCount: 8,
            missedCount: 0,
            extraCount: 0,
            wrongPitchCount: 0
        ),
        scoreRanges: ScoreRanges(
            onsetTimingScore: ScoreRange(min: 0.6, max: 0.99),
            interOnsetScore: ScoreRange(min: 0.3, max: 0.99),
            durationScore: ScoreRange(min: 0.95, max: 1)
        )
    ),
    SampleCase(
        name: "pause",
        target: "generated/basic/target.mid",
        performance: "generated/basic/pause.mid",
        expected: ExpectedCounts(
            matchedCount: 8,
            missedCount: 0,
            extraCount: 0,
            wrongPitchCount: 0
        ),
        scoreRanges: ScoreRanges(
            onsetTimingScore: ScoreRange(min: 0.0, max: 0.5),
            interOnsetScore: ScoreRange(min: 0.0, max: 0.9),
            durationScore: ScoreRange(min: 0.95, max: 1)
        )
    ),
    SampleCase(
        name: "fix",
        target: "generated/basic/target.mid",
        performance: "generated/basic/fix.mid",
        expected: ExpectedCounts(
            matchedCount: 8,
            missedCount: 0,
            extraCount: 1,
            wrongPitchCount: 0
        ),
        scoreRanges: ScoreRanges(
            onsetTimingScore: ScoreRange(min: 0.75, max: 1),
            interOnsetScore: ScoreRange(min: 0.4, max: 1),
            durationScore: ScoreRange(min: 0.9, max: 1)
        )
    ),
    SampleCase(
        name: "short",
        target: "generated/basic/target.mid",
        performance: "generated/basic/short.mid",
        expected: ExpectedCounts(
            matchedCount: 8,
            missedCount: 0,
            extraCount: 0,
            wrongPitchCount: 0
        ),
        scoreRanges: ScoreRanges(
            onsetTimingScore: ScoreRange(min: 1, max: 1),
            interOnsetScore: ScoreRange(min: 1, max: 1),
            durationScore: ScoreRange(min: 0.0, max: 0.85)
        )
    ),
    SampleCase(
        name: "lead-in",
        target: "generated/basic/target.mid",
        performance: "generated/basic/lead-in.mid",
        expected: ExpectedCounts(
            matchedCount: 8,
            missedCount: 0,
            extraCount: 0,
            wrongPitchCount: 0
        ),
        scoreRanges: ScoreRanges(
            onsetTimingScore: ScoreRange(min: 1, max: 1),
            interOnsetScore: ScoreRange(min: 1, max: 1),
            durationScore: ScoreRange(min: 1, max: 1)
        )
    ),
    SampleCase(
        name: "speed",
        target: "generated/basic/target.mid",
        performance: "generated/basic/speed.mid",
        expected: ExpectedCounts(
            matchedCount: 8,
            missedCount: 0,
            extraCount: 0,
            wrongPitchCount: 0
        ),
        scoreRanges: ScoreRanges(
            onsetTimingScore: ScoreRange(min: 0.0, max: 0.95),
            interOnsetScore: ScoreRange(min: 0.0, max: 0.95),
            durationScore: ScoreRange(min: 0.0, max: 0.95)
        )
    ),
])

let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
let manifestData = try encoder.encode(manifest)
try manifestData.write(to: samplesRoot.appendingPathComponent("manifest.json"))

print("Generated MIDIPracticeKit samples in \(samplesRoot.path)")

func tick(_ beat: Double) -> Int {
    Int((beat * Double(ticksPerQuarter)).rounded())
}
