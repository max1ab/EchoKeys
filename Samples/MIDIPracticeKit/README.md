# MIDIPracticeKit Samples

This directory contains MIDI files for manual and command-line testing of `MIDIPracticeKit`.

## Generate

From the repository root:

```bash
cd Tools/MIDIPracticeSamples
swift run MIDIPracticeSampleGenerator
```

This writes:

```text
Samples/MIDIPracticeKit/manifest.json
Samples/MIDIPracticeKit/generated/basic/target.mid
Samples/MIDIPracticeKit/generated/basic/perfect.mid
Samples/MIDIPracticeKit/generated/basic/wrong-pitch.mid
Samples/MIDIPracticeKit/generated/basic/loose.mid
Samples/MIDIPracticeKit/generated/basic/pause.mid
Samples/MIDIPracticeKit/generated/basic/fix.mid
Samples/MIDIPracticeKit/generated/basic/short.mid
Samples/MIDIPracticeKit/generated/basic/lead-in.mid
Samples/MIDIPracticeKit/generated/basic/speed.mid
```

## Run

From the repository root:

```bash
cd Tools/MIDIPracticeSamples
swift run MIDIPracticeSampleRunner
```

Expected output:

```text
PASS perfect
PASS wrong-pitch
PASS loose
PASS pause
PASS fix
PASS short
PASS lead-in
PASS speed

case         match  miss  extra  wrong  pitch   complete  onset   inter   duration  offset  scale
-----------  -----  ----  -----  -----  ------  --------  ------  ------  --------  ------  -----
...
```

## Cases

The first target is a simple two-measure phrase:

```text
pitch: 60  62  64  67  | 65  64  62  60
beat:  0   .5  1   2   | 4   4.5 5   6
dur:   .5  .5  1   2   | .5  .5  1   2
```

Current cases:

```text
perfect      exact performance
wrong-pitch  one wrong pitch, timing intact
loose        light human timing variation
pause        mid-phrase pause before continuing
fix          wrong note followed quickly by the correct note
short        correct onsets with shortened durations
lead-in      two beats of silence before the performance starts
speed        same phrase played at a faster tempo
```
