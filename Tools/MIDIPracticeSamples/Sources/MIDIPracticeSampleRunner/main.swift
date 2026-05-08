import Darwin
import Foundation
import MIDIPracticeKit
import MIDIPracticeSampleSupport

let repositoryRoot = try SamplePaths.repositoryRoot()
let samplesRoot = SamplePaths.samplesRoot(from: repositoryRoot)
let manifestURL = samplesRoot.appendingPathComponent("manifest.json")
let manifestData = try Data(contentsOf: manifestURL)
let manifest = try JSONDecoder().decode(SampleManifest.self, from: manifestData)
let kit = MIDIPracticeKit()

var failureCount = 0
var rows: [ScoreRow] = []

for sampleCase in manifest.cases {
    let targetURL = samplesRoot.appendingPathComponent(sampleCase.target)
    let performanceURL = samplesRoot.appendingPathComponent(sampleCase.performance)
    let report = try kit.score(
        targetMIDI: Data(contentsOf: targetURL),
        performanceMIDI: Data(contentsOf: performanceURL)
    )

    let actual = ExpectedCounts(
        matchedCount: report.level1.matchedCount,
        missedCount: report.level1.missedCount,
        extraCount: report.level1.extraCount,
        wrongPitchCount: report.level1.wrongPitchCount
    )
    rows.append(ScoreRow(
        name: sampleCase.name,
        matchedCount: report.level1.matchedCount,
        missedCount: report.level1.missedCount,
        extraCount: report.level1.extraCount,
        wrongPitchCount: report.level1.wrongPitchCount,
        pitchAccuracy: report.level1.pitchAccuracy,
        completeness: report.level1.completeness,
        onsetTimingScore: report.level2.onsetTimingScore,
        interOnsetScore: report.level2.interOnsetScore,
        durationScore: report.level2.durationScore,
        estimatedOffsetBeat: report.estimatedOffsetBeat
    ))

    var failures: [String] = []
    if actual != sampleCase.expected {
        failures.append("expected=\(sampleCase.expected) actual=\(actual)")
    }
    failures.append(contentsOf: scoreRangeFailures(sampleCase: sampleCase, report: report))

    if failures.isEmpty {
        print("PASS \(sampleCase.name)")
    } else {
        failureCount += 1
        print("FAIL \(sampleCase.name) \(failures.joined(separator: "; "))")
    }
}

printScoreTable(rows)

if failureCount > 0 {
    exit(1)
}

func scoreRangeFailures(sampleCase: SampleCase, report: MIDIPracticeReport) -> [String] {
    guard let ranges = sampleCase.scoreRanges else { return [] }
    var failures: [String] = []

    if let range = ranges.onsetTimingScore,
       !range.contains(report.level2.onsetTimingScore) {
        failures.append("onsetTimingScore=\(format(report.level2.onsetTimingScore)) outside \(range)")
    }
    if let range = ranges.interOnsetScore,
       !range.contains(report.level2.interOnsetScore) {
        failures.append("interOnsetScore=\(format(report.level2.interOnsetScore)) outside \(range)")
    }
    if let range = ranges.durationScore,
       !range.contains(report.level2.durationScore) {
        failures.append("durationScore=\(format(report.level2.durationScore)) outside \(range)")
    }

    return failures
}

func format(_ value: Double) -> String {
    String(format: "%.4f", value)
}

struct ScoreRow {
    var name: String
    var matchedCount: Int
    var missedCount: Int
    var extraCount: Int
    var wrongPitchCount: Int
    var pitchAccuracy: Double
    var completeness: Double
    var onsetTimingScore: Double
    var interOnsetScore: Double
    var durationScore: Double
    var estimatedOffsetBeat: Double
}

func printScoreTable(_ rows: [ScoreRow]) {
    guard !rows.isEmpty else { return }

    let headers = [
        "case", "match", "miss", "extra", "wrong",
        "pitch", "complete", "onset", "inter", "duration", "offset",
    ]
    let body = rows.map { row in
        [
            row.name,
            "\(row.matchedCount)",
            "\(row.missedCount)",
            "\(row.extraCount)",
            "\(row.wrongPitchCount)",
            format(row.pitchAccuracy),
            format(row.completeness),
            format(row.onsetTimingScore),
            format(row.interOnsetScore),
            format(row.durationScore),
            format(row.estimatedOffsetBeat),
        ]
    }

    let widths = columnWidths(headers: headers, rows: body)
    print("")
    print(renderRow(headers, widths: widths))
    print(renderRow(widths.map { String(repeating: "-", count: $0) }, widths: widths))
    for row in body {
        print(renderRow(row, widths: widths))
    }
}

func columnWidths(headers: [String], rows: [[String]]) -> [Int] {
    headers.indices.map { index in
        ([headers[index]] + rows.map { $0[index] }).map(\.count).max() ?? headers[index].count
    }
}

func renderRow(_ values: [String], widths: [Int]) -> String {
    values.enumerated()
        .map { index, value in value.padding(toLength: widths[index], withPad: " ", startingAt: 0) }
        .joined(separator: "  ")
}
