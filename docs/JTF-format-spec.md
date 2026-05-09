# JTF (Jianpu Text Format) v0 规范

简谱纯文本标记语言，用于基础 MIDI ↔ 简谱转换。v0 目标是覆盖简单钢琴练习片段：音高、基础时值、休止、和弦、多声部，以及少量 MIDI meta 信息。

JTF v0 不是完整乐谱协议，也不是 MIDI 的无损文本表示。MIDI 中的力度、踏板、音色、复杂 tempo map、channel 语义和多数演奏控制信息不会完整保留。

---

## 1. 快速示例

### 最小示例

```jianpu
1=C 4/4
| 1 2 3 4 | 5 6 7 [1] | (6) (5) 3 2 | 1 - - - ||
```

### 附点节奏

```jianpu
1=C 4/4
| 3 3 4 5 | 5 4 3 2 | 1 1 2 3 | 3._ 2_ 2 - ||
```

### 升降号

```jianpu
1=G 4/4
| 3 2 1 (7) | (6) #4 5 3 | 2 - - - ||
```

### 多声部

```jianpu
1=C 4/4
V:旋律
| 1 3 5 [1] | [2] [1] (6) 5 | 3 2 1 - ||
V:伴奏
| {1 5} {3 5} {1 5} {3 5} | {5 1} {3 1} {6 3} {5 2} | {1 5} {5 3} {2 6} {5 3} ||
```

---

## 2. 元素参考

### 2.1 头信息（可选，推荐第一行）

```
1=C 4/4       调号 + 拍号
1=G 3/4 120   可附加速度 BPM
1=Bb 6/8      降号调
1=F# 2/2     升号调
```

BNF:
```
Header  := "1=" Key " " TimeSig (" " Tempo)?
Key     := [A-G] ("#" | "b")?
TimeSig := Digit+ "/" Digit+
Tempo   := Digit+
```

没有头信息时，当前实现使用默认值：`1=C 4/4 120`。

### 2.2 音高

```
元素          含义          1=C 时对应     MIDI Note
1 ~ 7        唱名          C D E F G A B  60 62 64 65 67 69 71
0            休止符        —              无
#n           升半音        例 #4 = F#      升半音
bn           降半音        例 b7 = Bb      降半音
nn           还原记号      例 n4 = F♮      还原
```

### 2.3 八度

| 标记 | 含义 | 1=C 示例 | MIDI |
|------|------|----------|------|
| `1` | 中央八度 | C4 | 60 |
| `[1]` | 高八度 | C5 | 72 |
| `[[1]]` | 高二个八度 | C6 | 84 |
| `(1)` | 低八度 | C3 | 48 |
| `((1))` | 低二个八度 | C2 | 36 |

嵌套深度无上限：`[[[1]]]` = 高三八度。

BNF:
```
PitchedNote := OctaveOpen? Accidental? Digit OctaveClose?
Digit       := "1" | "2" | "3" | "4" | "5" | "6" | "7"
RestNote    := OctaveOpen? "0" OctaveClose?
Accidental  := "#" | "b" | "n"
OctaveOpen  := "(" | "((" | "(((" | ... | "[" | "[[" | "[[[" | ...
OctaveClose := ")" | "))" | ")))" | ... | "]" | "]]" | "]]]" | ...
```

> 规则：八度括号对称且方向一致。`([1])` 非法；`(1]` 非法。

### 2.4 时值

默认一拍 = 四分音符（以拍号分母为参考）。

| 标记 | 含义 | 拍数（4/4 中） |
|------|------|----------------|
| `3` | 四分音符 | 1 拍 |
| `3_` | 八分音符 | ½ 拍 |
| `3__` | 十六分音符 | ¼ 拍 |
| `3___` | 三十二分音符 | ⅛ 拍 |
| `3.` | 附点四分 | 1½ 拍 |
| `3._` | 附点八分 | ¾ 拍 |
| `3.__` | 附点十六分 | ⅜ 拍 |
| `0` | 四分休止 | 1 拍 |
| `0_` | 八分休止 | ½ 拍 |

**延音线**（独立 token，空格分隔）：

| 标记 | 含义 | 总时长 |
|------|------|--------|
| `3 -` | 二分音符 | 2 拍 |
| `3 - -` | 附点二分 | 3 拍 |
| `3 - - -` | 全音符 | 4 拍 |
| `3. -` | 附点四分 + 一拍 = | 2½ 拍 |

BNF:
```
Duration  := Dot? Underscore*
Dot       := "."
Underscore := "_"
Extend    := " -"        // 每个 " -" 延长一拍；空格分隔的独立 token
```

**约束**：附点 `.` 必须在 `_` 之前。`3_.` 非法，`3._` 合法。附点后不能再附点，`3..` 非法。

### 2.5 和弦（柱式，同时发音）

```
{1 3 5}         C 大三和弦，四分音符
{1_ 3_ 5_}      C 大三和弦，八分音符
{1 3 5 7}       C 大七和弦
{(1) 1 3}       F 大三和弦（低音 + 根音 + 三音）
```

和弦内音符可以有不同的八度标记，时值必须一致。和弦内不允许出现延音 `-` token。

BNF:
```
Chord := "{" Note+ "}"
```

### 2.6 结构标记

```
|         小节线
||        终止线（双竖线）
|:        反复开始
:|        反复结束
~         延音线（连接同音高音符，如 3 ~ 3）
^         连音线／圆滑线（连接不同音高，如 3 ^ 5）
```

v0 中：

- `|`、`||`、`|:`、`:|` 会被解析和序列化为结构标记。
- 反复不会展开为重复播放。
- `~` 和 `^` 会被解析和序列化，但当前不改变 MIDI 生成结果。
- 实际持续时值请使用 `-`。

### 2.7 连音符（experimental）

```
(3 1_ 2_ 3_)          三连音（一拍内均分三个八分）
(5 1 2 3 4 5)         五连音（一拍内均分五个音）
(3 1 2_ 3_)           三连音（两拍内均分三个四分）
```

BNF:
```
Tuplet := "(" Count Note+ ")"
Count  := Digit+
```

当前实现可以解析基础 tuplet token，并在 JTF → MIDI 时按一拍均分生成简单 note。MIDI → JTF 不会反推出 tuplet。复杂嵌套、跨拍和精确排版暂不属于 v0 稳定范围。

### 2.8 多声部

```
V:声部名
音符行...
```

声部按 `V:` 分组。不同声部的时间线独立。

解析时，不同 `V:` 映射到不同的 MIDI track。

v0 不强制校验不同声部的小节数或小节时值是否一致。

### 2.9 和弦符号（可选标注行）

```
Ch: C Am F G7
```

仅作为标注，不参与 MIDI 转换。织体模板不属于 v0。

---

## 3. EBNF 语法

```ebnf
(* 顶层 *)
Score       := Header? NL? (VoiceBlock NL?)+

Header      := "1=" Key " " TimeSig (" " Tempo)?
Key         := Letter ("#" | "b")?
Letter      := "A" | "B" | "C" | "D" | "E" | "F" | "G"
TimeSig     := Digits "/" Digits
Tempo       := Digits

(* 声部 *)
VoiceBlock  := VoiceDecl? (Measure | ChordLine)*
VoiceDecl   := "V:" Identifier NL
ChordLine   := "Ch:" ChordName+ NL               (* 可选，标注用 *)

(* 小节 *)
Measure     := BarPrefix? Element+ BarSuffix? " "
BarPrefix   := "|" | "|:"
BarSuffix   := "|" | "||" | ":|"
Element     := Chord | Tuplet | NoteAtom | Extend | Tie | Slur

(* 音符 *)
NoteAtom    := OctaveOpen? Accidental? Pitch OctaveClose? Duration
Pitch       := DigitNoZero | RestChar
DigitNoZero := "1" .. "7"
RestChar    := "0"
Accidental  := "#" | "b" | "n"

(* 八度 *)
OctaveOpen  := "("* | "["*         (* 同一方向重复表示深度 *)
OctaveClose := ")"* | "]"*         (* 必须与 Open 方向一致且深度相等 *)

(* 时值 *)
Duration    := Dot? Underscore*
Dot         := "."
Underscore   := "_"
Extend      := "-"                  (* 独立 token，每个延长一拍 *)

(* 和弦 *)
Chord       := "{" NoteAtom+ "}"

(* 连音符 *)
Tuplet      := "(" Count Element+ ")"
Count       := Digits

(* 连线 *)
Tie         := "~"
Slur        := "^"

(* 基础 *)
Digits      := Digit+
Digit       := "0" .. "9"
Identifier  := (Alnum | "_" | "-")+
NL          := "\n"
```

说明：EBNF 描述当前可解析的文本形状，不代表所有 token 都有完整音乐语义。

---

## 4. MIDI ↔ JTF 映射规则

### 4.1 JTF → MIDI

#### 音高映射

给定调号 `1=K`，确定主音 MIDI 值（以八度 4 为基准）：

```
Tonic(K) := 以 MIDI Note 60 (C4) 为原点，按半音偏移：
  C=0  D=2  E=4  F=5  G=7  A=9  B=11
  # 加 1，b 减 1
  Tonic = 60 + offset(K)
```

音级到半音偏移（大调）：

| 唱名 | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
|------|---|---|---|---|---|---|---|
| 半音偏移 | 0 | 2 | 4 | 5 | 7 | 9 | 11 |

```
MIDINote(n, octave_up, octave_down, accidental, key) :=
  base   = Tonic(key) + ScaleOffset[n]
  base  += accidental_offset           (* # → +1, b → -1, n → 0 *)
  base  += (octave_up - octave_down) × 12
  return base
```

#### 时值映射

```
TicksPerQuarter := MIDI division 值（默认 480）

DurationToTicks(duration, TicksPerQuarter) :=
  base  = TicksPerQuarter               (* 四分音符 *)
  base /= 2  for each "_"
  base *= 1.5 if "."
  return base

TotalTicks := DurationToTicks(note) + count(Extend) × TicksPerQuarter
```

#### 多声部映射

- 每个 `V:` 声部 → 一个 MIDI track
- 单声部输出 format 0；多声部输出 format 1
- `Ch:` 行不生成 MIDI 事件（纯标注）
- 每个 track 写入相同的 tempo、time signature、key signature meta event

### 4.2 MIDI → JTF

#### 提取 Note 事件

遍历每个 MIDI track：
1. 收集 Note On (velocity > 0) 和对应的 Note Off
2. 计算 delta ticks → 时长
3. 同一 voice 内同一 tick、同一时值的 Note On → 和弦 `{ }`
4. 同一 tick 但不同时值、或相互重叠的音符会拆成多个 `V:`

#### 音高反查

```
给定调号 1=K：
  semitone = MIDINote % 12
  octave   = floor(MIDINote / 12) - 1           (* MIDI 60 = C4 → octave=0 *)

  degree   = semitone → 在调 K 大调音阶中查找最近的音级
  accidental = semitone - ScaleSemitone[K][degree]

  octave   > 0 → 输出 [n] × octave 层
  octave   < 0 → 输出 (n) × |octave| 层
  accidental > 0 → "#" 前缀
  accidental < 0 → "b" 前缀
```

#### 时值量化

```
ticks → 拍数 → 匹配最佳时值后缀
  在固定候选集合中取最近值
```

当前候选集合包括：`0.25, 0.375, 0.5, 0.75, 1, 1.5, 2, 3, 4, 6, 8` 拍。MIDI → JTF 不反推 tuplet。

#### 调号推断（当 MIDI 文件无 Key Signature meta event 时）

算法：统计音符集合，与大调候选做 Krumhansl-Schmuckler 相关系数匹配，取最高分。minor key meta event 会映射到相对小调 tonic，但 v0 没有独立大小调语法。

### 4.3 v0 不保证保留的信息

- velocity / dynamics
- pedal / controller
- program change / instrument
- channel 的业务含义
- 多段 tempo map
- pitch bend / aftertouch
- lyric / marker / cue 等 meta event
- 反复展开、slur/tie 演奏语义
- 原始 MIDI 轨道名和复杂排版信息

---

## 5. 解析器 Token 规则

词法分析按空格切分 token，特殊规则：

| Token 类型 | 正则模式 | 示例 |
|------------|----------|------|
| BarMarker | `\|` `\|\|` `\|:` `:\|` | `|` `||` |
| Chord | `\{` ... `\}` | `{1 3 5}` |
| Tuplet | `\(` Digit | `(3` |
| Extend | `-` | `-` |
| Tie | `~` | `~` |
| Slur | `^` | `^` |
| NoteAtom | `[\(\[\]]*[#bn]?[0-7][\)\]]*[._]*` | `1.` `(b7._)` `[[#4]]` |
| Header | `1=[A-G][#b]? \d+/\d+(\s\d+)?` | `1=G 4/4 120` |

---

## 6. 后续 TODO

- 明确大小调语法
- 小节时值校验
- 更完整的量化策略
- tuplet 反推
- tie/slur 的 MIDI 语义
- repeat 展开
- 织体模板
