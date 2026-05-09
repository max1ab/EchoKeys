# MIDIPracticeKit 评分标准说明

`MIDIPracticeKit` 的评分核心只处理 event，不直接处理 MIDI 文件语义。MIDI 只是输入适配器：先被解析并归一化为 `PianoPracticeCore.NoteEvent`，再进入对齐和评分流程。`NoteEvent` 目前只是 `MIDIPracticeKit` 中保留的兼容别名。

---

## 1. 事实层：NoteEvent

评分使用的最小事实单位是：

```text
NoteEvent
- id
- pitch
- onsetBeat
- durationBeat
- velocity
- trackIndex
- channel
- sourceTick?
- sourceDurationTick?
- annotations?
```

其中：

- `pitch` 是 MIDI note number。
- `onsetBeat` 是音符开始的拍位置。
- `durationBeat` 是音符持续拍数。
- `sourceTick` 和 `sourceDurationTick` 只用于追溯/debug，不参与评分。
- `annotations` 只用于声部、左右手、小节、片段等归因，不改变评分事实。

### Beat 和 Tick

`tick` 是 MIDI 文件内部时间单位，`beat` 是音乐拍单位。

```text
onsetBeat = sourceTick / ticksPerQuarter
durationBeat = sourceDurationTick / ticksPerQuarter
```

评分统一使用 beat。这样不同 PPQ 的 MIDI 文件可以直接比较。

### 重复音归一化

目标事件中如果出现几乎同一时间、同一音高的重复音，会合并成一个目标 event：

```text
same pitch
same onsetBeat within duplicateEpsilonBeat
```

合并后保留多个 source/annotation。这样不会要求用户在同一时刻弹两次同一个琴键。

---

## 2. MIDI 输入处理

MIDI wrapper 的处理流程：

```text
MIDI Data
-> parse SMF
-> collect note on/off with absoluteTick
-> pair note on/off
-> convert tick to beat
-> normalize duplicate target notes
-> estimate performance offset and tempo scale
-> align and score
```

规则：

- 支持 SMF tick division，不支持 SMPTE division。
- `0x90 velocity > 0` 是 note on。
- `0x90 velocity == 0` 按 note off 处理。
- `0x80` 是 note off。
- note 配对 key 是 `trackIndex + channel + pitch`。
- 同 key 重叠 note on 使用 FIFO 配对。
- 未闭合音符丢弃，并写入 `warnings`。

Performance 会先估计起始偏移和整体速度比例：

```text
adjustedPerformanceOnset = (performanceOnset - estimatedOffsetBeat) / estimatedTempoScale
adjustedPerformanceDuration = performanceDuration / estimatedTempoScale
```

`estimatedTempoScale` 使用相邻 onset 间隔比例的中位数估计：

```text
ratio = performanceIOI / targetIOI
estimatedTempoScale = median(ratio)
```

其中 `estimatedTempoScale = 1.0` 表示整体速度一致，`> 1.0` 表示用户整体更慢，`< 1.0` 表示用户整体更快。只有落在配置范围内的 ratio 会参与估计，避免把中间停顿误判为整体变慢。

`estimatedOffsetBeat` 是起始校准量，用开头少数 pitch-matched 音符的 onset delta 中位数估计。它用于消除录音前空白或起步等待，不作为分数，也不应该吸收中间停顿。

---

## 3. 对齐规则

目标事件和用户事件使用动态规划对齐，不按数组下标硬比。

对齐结果类型：

```text
matched     音高匹配，时间在可匹配窗口内
wrongPitch  时间接近，但音高不同
missed      目标音没有对应用户音
extra       用户多弹音
```

约束：

- 超出 `maxMatchWindowBeat` 的两个 event 不允许匹配或错音替换。
- 时间附近但音高不同的 event 优先识别为 `wrongPitch`，而不是 `missed + extra`。
- 所有 alignment 和 error 都通过 event `id` 引用具体音符。

每个 `matched` 或 `wrongPitch` 会记录：

```text
onsetDelta = performance.onsetBeat - target.onsetBeat
durationDelta = performance.durationBeat - target.durationBeat
```

`onsetDelta < 0` 表示弹早了，`onsetDelta > 0` 表示弹晚了。

---

## 4. 一级评分：音符正确性

一级评分回答：用户有没有按对音。

字段：

```text
pitchAccuracy
completeness
matchedCount
missedCount
extraCount
wrongPitchCount
```

计数规则：

- `matchedCount` 只统计音高正确的匹配。
- `wrongPitchCount` 统计时间接近但音高错误的替换。
- `missedCount` 统计漏弹目标音。
- `extraCount` 统计多弹用户音。

当前公式：

```text
pitchAccuracy = matchedCount / (targetCount + extraCount)
completeness = matchedCount / targetCount
```

解释：

- `pitchAccuracy` 惩罚错音、漏音和多音。
- `completeness` 只统计目标音中被正确弹出的比例；错音不算完成。
- 所有分数范围是 `0...1`。UI 如需百分制可乘以 100。

一级错误类型：

```text
missedNote
extraNote
wrongPitch
```

---

## 5. 二级评分：时间准确性

二级评分回答：用户按得准不准。

二级只对 `matched` 和 `wrongPitch` 事件计算时间偏差。漏弹和多弹主要由一级评分表达。

字段：

```text
onsetTimingScore
interOnsetScore
durationScore
earlyCount
lateCount
averageOnsetDelta
maxOnsetDelta
```

### onsetTimingScore

基于每个匹配/错音事件的 `onsetDelta` 计算。

```text
normalized = min(abs(onsetDelta) / onsetToleranceBeat, 2) / 2
onsetTimingScore = 1 - average(normalized)
```

结果范围是 `0...1`。

### durationScore

基于每个匹配/错音事件的 `durationDelta` 计算。

```text
normalized = min(abs(durationDelta) / durationToleranceBeat, 2) / 2
durationScore = 1 - average(normalized)
```

结果范围是 `0...1`。

### interOnsetScore

衡量相邻事件 timing 偏差的变化，反映相对节奏稳定性。

```text
interDelta = current.onsetDelta - previous.onsetDelta
```

然后使用和 `onsetTimingScore` 相同的 tolerance 公式计算。

### earlyCount / lateCount

```text
earlyCount = onsetDelta < -onsetToleranceBeat 的数量
lateCount = onsetDelta > onsetToleranceBeat 的数量
```

### averageOnsetDelta / maxOnsetDelta

```text
averageOnsetDelta = average(onsetDelta)
maxOnsetDelta = max(abs(onsetDelta))
```

`averageOnsetDelta` 是带符号平均值，能看出整体偏早或偏晚。

---

## 6. 三级评分：表现力

第一版不实现表现力评分，只输出 placeholder。

未来可能包含：

```text
velocity dynamics
melody/accompaniment balance
articulation
phrase shaping
```

三级评分不参与任何通过判断。

---

## 7. Warnings

`warnings` 表示评分可以继续，但输入或标注存在非致命问题。

常见 warning：

- MIDI 中存在 unmatched note off。
- MIDI 中存在未闭合 note on。
- JTF 标注数量和 target event 数量不一致。
- JTF 没有提取到可用标注。

JTF 标注失败不影响评分。MIDI 仍然是音高、时间和时值的事实来源。
