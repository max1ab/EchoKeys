# MIDIPracticeSamples

Command-line tools for MIDIPracticeKit fixtures.

## Generate Fixtures

```bash
swift run MIDIPracticeSampleGenerator
```

Writes `Samples/MIDIPracticeKit/manifest.json` and MIDI files under `Samples/MIDIPracticeKit/generated/`.

## Run Regression

```bash
swift run MIDIPracticeSampleRunner
```

The runner:

- reads the manifest
- scores each target/performance pair
- checks note counts exactly
- checks score ranges when present
- prints a compact score table

Manifest fields:

```text
name
target
performance
expected
scoreRanges?
```

