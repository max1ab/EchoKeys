import Foundation

enum JTFPlainToken: Equatable {
    case barMarker(BarMarker)
    case chordOpen
    case chordClose
    case tupletOpen(count: Int)
    case tupletClose
    case extend
    case tie
    case slur
    case note(NoteToken)
    case headerLine(String)
    case voiceDecl(String)
    case chordLine([String])
}

struct NoteToken: Equatable {
    var octaveUp: Int
    var octaveDown: Int
    var accidental: Int
    var pitch: Int
    var dot: Bool
    var underscoreCount: Int
}

// MARK: - Tokenizer

struct JTFTokenizer {
    func tokenize(_ text: String) throws -> [[JTFPlainToken]] {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("//") }

        guard !lines.isEmpty else {
            throw NotationConversionError.emptyInput
        }

        return try lines.map { try tokenizeLine(String($0)) }
    }

    private func tokenizeLine(_ line: String) throws -> [JTFPlainToken] {
        guard !line.isEmpty else { return [] }

        // Header line
        if line.hasPrefix("1=") {
            return [.headerLine(line)]
        }

        // Voice declaration
        if line.hasPrefix("V:") {
            return [.voiceDecl(String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces))]
        }

        // Chord symbol line
        if line.hasPrefix("Ch:") {
            let symbols = line.dropFirst(3)
                .split(separator: " ")
                .map { String($0) }
            return [.chordLine(symbols)]
        }

        var tokens: [JTFPlainToken] = []
        var i = line.startIndex

        while i < line.endIndex {
            let ch = line[i]

            if ch.isWhitespace {
                i = line.index(after: i)
                continue
            }

            switch ch {
            case "|":
                if i < line.index(before: line.endIndex) {
                    let next = line[line.index(after: i)]
                    if next == "|" {
                        tokens.append(.barMarker(.doubleBar))
                        i = line.index(after: i)
                    } else if next == ":" {
                        tokens.append(.barMarker(.repeatStart))
                        i = line.index(after: i)
                    } else {
                        tokens.append(.barMarker(.bar))
                    }
                } else {
                    tokens.append(.barMarker(.bar))
                }

            case ":":
                let nextIdx = line.index(after: i)
                if nextIdx < line.endIndex, line[nextIdx] == "|" {
                    tokens.append(.barMarker(.repeatEnd))
                    i = line.index(after: i)
                } else {
                    throw NotationConversionError.parseFailed("Unexpected ':' at position \(i)")
                }

            case "{":
                tokens.append(.chordOpen)

            case "}":
                tokens.append(.chordClose)

            case "-":
                tokens.append(.extend)

            case "~":
                tokens.append(.tie)

            case "^":
                tokens.append(.slur)

            case "(":
                let (count, peekIdx) = try readDigits(from: line, after: i)
                if let count, isTupletAfterCount(at: peekIdx, in: line) {
                    tokens.append(.tupletOpen(count: count))
                    i = peekIdx
                } else {
                    // Not a tuplet — parse as note with octave prefix
                    let note = try readNote(from: line, startingAt: &i)
                    tokens.append(.note(note))
                }

            case ")":
                tokens.append(.tupletClose)

            case "0"..."9", "#", "b", "n", "[", "]":
                let note = try readNote(from: line, startingAt: &i)
                tokens.append(.note(note))

            default:
                throw NotationConversionError.parseFailed("Unexpected character '\(ch)'")
            }

            i = line.index(after: i)
        }

        return tokens
    }

    // MARK: - Note reader

    private func readNote(from line: String, startingAt i: inout String.Index) throws -> NoteToken {
        var octaveDown = 0
        var octaveUp = 0
        var accidental = 0

        // Read prefix octave markers and accidentals
        while i < line.endIndex {
            let ch = line[i]
            if ch == "(" {
                octaveDown += 1
            } else if ch == "[" {
                octaveUp += 1
            } else {
                break
            }
            i = line.index(after: i)
        }

        // Accidental
        if i < line.endIndex {
            let ch = line[i]
            if ch == "#" {
                accidental = 1
                i = line.index(after: i)
            } else if ch == "b" {
                accidental = -1
                i = line.index(after: i)
            } else if ch == "n" {
                accidental = 0
                i = line.index(after: i)
            }
        }

        // Pitch digit
        guard i < line.endIndex,
              let pitch = Int(String(line[i])),
              (0...7).contains(pitch) else {
            throw NotationConversionError.parseFailed("Expected pitch digit 0-7")
        }
        i = line.index(after: i)

        // Read matching suffix octave close markers. The prefix already counted
        // octave shifts; suffix markers only close the visual grouping.
        var remainingOctaveDownClosers = octaveDown
        var remainingOctaveUpClosers = octaveUp
        while i < line.endIndex {
            let ch = line[i]
            if ch == ")" {
                guard remainingOctaveDownClosers > 0 else {
                    throw NotationConversionError.parseFailed("Unexpected ')' after note")
                }
                remainingOctaveDownClosers -= 1
            } else if ch == "]" {
                guard remainingOctaveUpClosers > 0 else {
                    throw NotationConversionError.parseFailed("Unexpected ']' after note")
                }
                remainingOctaveUpClosers -= 1
            } else {
                break
            }
            i = line.index(after: i)
        }

        // Duration: dot and underscores
        var dot = false
        var underscoreCount = 0

        if i < line.endIndex, line[i] == "." {
            dot = true
            i = line.index(after: i)
        }

        while i < line.endIndex, line[i] == "_" {
            underscoreCount += 1
            i = line.index(after: i)
        }

        // Back up one character since the caller will advance by 1
        if i > line.startIndex {
            i = line.index(before: i)
        }

        return NoteToken(
            octaveUp: octaveUp,
            octaveDown: octaveDown,
            accidental: accidental,
            pitch: pitch,
            dot: dot,
            underscoreCount: underscoreCount
        )
    }

    private func isTupletAfterCount(at idx: String.Index, in line: String) -> Bool {
        guard idx < line.endIndex else { return false }
        return line[idx].isWhitespace
    }

    private func readDigits(from line: String, after idx: String.Index) throws -> (Int?, String.Index) {
        var i = line.index(after: idx)
        var digits = ""
        while i < line.endIndex, line[i].isNumber {
            digits.append(line[i])
            i = line.index(after: i)
        }
        if digits.isEmpty {
            return (nil, idx)
        }
        return (Int(digits), i)
    }
}
