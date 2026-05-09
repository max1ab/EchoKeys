# EchoKeys

Learn piano by ear.

macOS SwiftUI playground for MIDI/JTF conversion, playback, rendering, and MIDI practice scoring.

## Structure

```text
piano-learn/                    EchoKeys macOS app
Packages/MIDIAudioConverter/    MIDI playback/render helpers
Packages/MIDINotationConverter/ JTF <-> MIDI conversion
Packages/MIDIPracticeKit/       event-based MIDI practice scoring
Tools/MIDIPracticeSamples/      sample generator and regression runner
Samples/MIDIPracticeKit/        practice scoring fixtures
docs/                           format and scoring notes
```

## Common Commands

```bash
cd Packages/MIDIPracticeKit
swift test

cd ../../Tools/MIDIPracticeSamples
swift run MIDIPracticeSampleGenerator
swift run MIDIPracticeSampleRunner
```

The sample runner prints PASS/FAIL plus a score table for the committed MIDI fixtures.
