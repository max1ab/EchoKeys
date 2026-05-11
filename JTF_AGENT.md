# JTF Agent Quick Guide

JTF is a plain-text numbered-notation format for reading, writing, and converting simple piano/MIDI music.

## Minimal Shape

```jtf
1=C 4/4 120
| 1 2 3 4 | 5 - 5 - ||
```

First line:

```text
1=<key> <time-signature> [tempo]
```

Examples: `1=C 4/4`, `1=Ab 3/4 90`, `1=F# 6/8 120`.

## Notes

Numbers are scale degrees in the current key:

```text
1 2 3 4 5 6 7
```

`0` is a rest.

Accidentals go before the number:

```text
#4   b7   n4
```

Octaves wrap the note:

```text
1       middle octave
[1]     one octave higher
[[1]]   two octaves higher
(1)     one octave lower
((1))   two octaves lower
[#4]    high sharp 4
(b7)    low flat 7
```

## Durations

Default note/rest length is 1 beat.

```text
3       1 beat
3_      1/2 beat
3__     1/4 beat
3___    1/8 beat
3.      1.5 beats
3._     0.75 beats
0       1 beat rest
0__     1/4 beat rest
```

`-` is a separate token that extends the previous sound by 1 beat:

```text
1 -       2 beats
1 - -     3 beats
1 - - -   4 beats
0 -       2 beats of rest
```

Always put spaces between tokens.

## Measures

Use bars:

```text
| 1 2 3 4 | 5 6 7 [1] ||
```

`|` starts or separates measures. `||` ends the phrase.

## Chords

Use braces for notes that start together in the same voice:

```text
{1 3 5}
{(1) 1 3}
{1_ 3_ 5_}
```

Important rule: all notes inside one chord must have the same duration.

Valid:

```text
{1_ 3_ 5_}
```

Invalid:

```text
{1 3_ 5}
```

If simultaneous notes have different durations, split them into separate voices instead of one chord.

## Voices

Use `V:<name>` for separate musical voices or hands:

```jtf
1=C 4/4 120
V:Right
| 1 2 3 4 | 5 - - - ||
V:Left
| {1 5} - {1 5} - | {1 5} - - - ||
```

Each voice has its own timeline. Use voices when notes overlap, or when simultaneous notes have different lengths.

## Ties And Slurs

These are separate tokens:

```text
3 ~ 3    tie-like mark
3 ^ 5    slur-like mark
```

For actual sustained duration, prefer `-`:

```text
3 - -    one note sustained for 3 beats
```

## Tuplets

Tuplet syntax:

```text
(3 1_ 2_ 3_)
```

This means 3 notes grouped into one beat division.

## Good Composition Defaults

For an AI writing playable JTF:

1. Start with a header like `1=C 4/4 120`.
2. Use `| ... | ... ||` measure structure.
3. Use `V:Right` and `V:Left` for piano.
4. Keep chord notes equal duration.
5. Use separate voices for overlapping rhythms.
6. Use `-` for held notes.
7. Keep tokens space-separated.

## Complete Example

```jtf
1=C 4/4 100
V:Right
| 1 2 3 5 | [1] - 7 6 |
| 5 3 2 1 | 2 - - - ||
V:Left
| {(1) 5} - {(1) 5} - | {(6) 3} - {(6) 3} - |
| {(4) 1} - {(5) 2} - | {(1) 5} - - - ||
```

