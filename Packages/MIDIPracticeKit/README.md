# MIDIPracticeKit

Event-based MIDI practice scoring.

## API

Use events when the caller already has normalized notes:

```swift
try MIDIPracticeKit().score(
    targetEvents: target,
    performanceEvents: performance
)
```

Use MIDI data for file-based scoring:

```swift
try MIDIPracticeKit().score(
    targetMIDI: targetData,
    performanceMIDI: performanceData,
    targetJTF: optionalJTF
)
```

`targetJTF` is annotation-only. MIDI remains the source of pitch, onset, and duration facts.

## Report

The report includes:

- normalized target and performance events
- alignment items
- level 1 note correctness
- level 2 timing/duration scores
- level 3 placeholder
- summaries, errors, warnings
- `estimatedOffsetBeat`
- `estimatedTempoScale`

Scores are `0...1`. `estimatedOffsetBeat` and `estimatedTempoScale` are alignment facts, not scores.

## Defaults

```text
onsetToleranceBeat = 0.125
durationToleranceBeat = 0.25
maxMatchWindowBeat = 1.0
offsetAnchorCount = 3
minTempoScale = 0.75
maxTempoScale = 1.35
```

More detail: [../../docs/MIDIPracticeKit-scoring.md](../../docs/MIDIPracticeKit-scoring.md).

