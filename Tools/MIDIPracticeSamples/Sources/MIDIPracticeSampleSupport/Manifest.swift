import Foundation

public struct SampleManifest: Codable, Equatable {
    public var cases: [SampleCase]

    public init(cases: [SampleCase]) {
        self.cases = cases
    }
}

public struct SampleCase: Codable, Equatable {
    public var name: String
    public var target: String
    public var performance: String
    public var expected: ExpectedCounts
    public var scoreRanges: ScoreRanges?

    public init(
        name: String,
        target: String,
        performance: String,
        expected: ExpectedCounts,
        scoreRanges: ScoreRanges? = nil
    ) {
        self.name = name
        self.target = target
        self.performance = performance
        self.expected = expected
        self.scoreRanges = scoreRanges
    }
}

public struct ExpectedCounts: Codable, Equatable {
    public var matchedCount: Int
    public var missedCount: Int
    public var extraCount: Int
    public var wrongPitchCount: Int

    public init(
        matchedCount: Int,
        missedCount: Int,
        extraCount: Int,
        wrongPitchCount: Int
    ) {
        self.matchedCount = matchedCount
        self.missedCount = missedCount
        self.extraCount = extraCount
        self.wrongPitchCount = wrongPitchCount
    }
}

public struct ScoreRanges: Codable, Equatable {
    public var onsetTimingScore: ScoreRange?
    public var interOnsetScore: ScoreRange?
    public var durationScore: ScoreRange?

    public init(
        onsetTimingScore: ScoreRange? = nil,
        interOnsetScore: ScoreRange? = nil,
        durationScore: ScoreRange? = nil
    ) {
        self.onsetTimingScore = onsetTimingScore
        self.interOnsetScore = interOnsetScore
        self.durationScore = durationScore
    }
}

public struct ScoreRange: Codable, Equatable {
    public var min: Double
    public var max: Double

    public init(min: Double, max: Double) {
        self.min = min
        self.max = max
    }

    public func contains(_ value: Double) -> Bool {
        value >= min && value <= max
    }
}

public enum SamplePaths {
    public static func repositoryRoot(from start: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)) throws -> URL {
        var current = start.standardizedFileURL
        let fileManager = FileManager.default

        while true {
            let marker = current
                .appendingPathComponent("Packages")
                .appendingPathComponent("MIDIPracticeKit")
                .appendingPathComponent("Package.swift")
            if fileManager.fileExists(atPath: marker.path) {
                return current
            }

            let parent = current.deletingLastPathComponent()
            if parent.path == current.path {
                throw SampleToolError.repositoryRootNotFound
            }
            current = parent
        }
    }

    public static func samplesRoot(from repositoryRoot: URL) -> URL {
        repositoryRoot
            .appendingPathComponent("Samples")
            .appendingPathComponent("MIDIPracticeKit")
    }
}

public enum SampleToolError: LocalizedError {
    case repositoryRootNotFound

    public var errorDescription: String? {
        switch self {
        case .repositoryRootNotFound:
            "Could not find repository root containing Packages/MIDIPracticeKit/Package.swift."
        }
    }
}
