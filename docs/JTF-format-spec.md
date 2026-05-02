# JTF (Jianpu Text Format) 规范

简谱纯文本标记语言，用于 MIDI ↔ 简谱双向转换。可嵌入 Markdown 代码块，人可读写，无歧义解析。

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

### 2.1 头信息（必需，第一行）

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

**约束**：附点 `.` 必须在 `_` 之前。`3_.` 非法，`3._` 合法。附点后不能再附点——`3..` 非法。

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

延音线 `~` 和连音线 `^` 是独立的 token。

### 2.7 三连音及其他连音

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

### 2.8 多声部

```
V:声部名
音符行...
```

声部按 `V:` 分组，同名 `V:` 可跨行继续。不同声部的时间线独立但对齐——小节数必须一致。

解析时，不同 `V:` 映射到不同的 MIDI track。

### 2.9 和弦符号（可选标注行）

```
Ch: C Am F G7
```

仅作为标注，不参与 MIDI 转换（除非后续实现织体模板展开）。

---

## 3. EBNF 完整语法

```ebnf
(* 顶层 *)
Score       := Header NL (VoiceBlock NL?)+

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
- 第一条 `V:` → track 0（或 1，取决于 SMF 约定）
- `Ch:` 行不生成 MIDI 事件（纯标注）

### 4.2 MIDI → JTF

#### 提取 Note 事件

遍历每个 MIDI track：
1. 收集 Note On (velocity > 0) 和对应的 Note Off
2. 计算 delta ticks → 时长
3. 聚合同一 tick 位置的所有 Note On → 和弦 `{ }`

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
  优先匹配精确值
  次选最接近的标准时值 + 容差阈值
  连音需要判定（如三拍内三个均等音 → 三连音标记）
```

#### 调号推断（当 MIDI 文件无 Key Signature meta event 时）

算法：统计音符集合，与 24 个大/小调音阶做 Krumhansl-Schmuckler 相关系数匹配，取最高分。

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

## 6. TODO: 织体模板

```
texture alberti: {
    @ = [1 5 3 5]      (* 默认模板：根→五→三→五 *)
}

B: C Am F G7           (* 和弦进行 *)
   alberti             (* 引用织体名，自动展开为分解和弦音符 *)
```

织体模板在 MIDI → JTF 方向无意义（MIDI 里已经是具体音符）。仅在 JTF → MIDI 方向展开。
