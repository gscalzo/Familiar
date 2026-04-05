#!/usr/bin/env swift
import Foundation

// Usage: collect-metrics.swift <tests> <coverage> [code-metrics-json] [avg-ccn]

guard CommandLine.arguments.count >= 3,
      let tests = Int(CommandLine.arguments[1]),
      let coverage = Double(CommandLine.arguments[2])
else {
    fputs("Usage: collect-metrics.swift <test_count> <coverage_pct> [code-metrics-json] [avg-ccn]\n", stderr)
    exit(1)
}

struct MetricEntry: Codable {
    let date: String
    let tests: Int
    let coverage: Double
    var loc: Int?
    var methods: Int?
    var classes: Int?
    var avgComplexity: Double?
}

let formatter = DateFormatter()
formatter.dateFormat = "yyyy-MM-dd"
let date = formatter.string(from: Date())

let scriptDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let projectRoot = scriptDir.deletingLastPathComponent()
let metricsDir = projectRoot.appendingPathComponent("docs/metrics")
let historyURL = metricsDir.appendingPathComponent("history.json")

try FileManager.default.createDirectory(at: metricsDir, withIntermediateDirectories: true)

var entries: [MetricEntry] = []
if let data = try? Data(contentsOf: historyURL) {
    entries = (try? JSONDecoder().decode([MetricEntry].self, from: data)) ?? []
}

let roundedCoverage = (coverage * 100).rounded() / 100
var newEntry = MetricEntry(date: date, tests: tests, coverage: roundedCoverage)

// Parse code metrics from swift-code-metrics output if provided
if CommandLine.arguments.count >= 4, !CommandLine.arguments[3].isEmpty {
    let metricsPath = CommandLine.arguments[3]
    if let data = try? Data(contentsOf: URL(fileURLWithPath: metricsPath)),
       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
       let frameworks = json["non-test-frameworks"] as? [[String: Any]]
    {
        var totalLoc = 0
        var totalMethods = 0
        var totalClasses = 0
        for fw in frameworks {
            for (_, metrics) in fw {
                guard let m = metrics as? [String: Any] else { continue }
                totalLoc += m["loc"] as? Int ?? 0
                totalMethods += m["nom"] as? Int ?? 0
                totalClasses += m["n_c"] as? Int ?? 0
            }
        }
        newEntry.loc = totalLoc
        newEntry.methods = totalMethods
        newEntry.classes = totalClasses
    }
}

// Parse average cyclomatic complexity from lizard if provided
if CommandLine.arguments.count >= 5, let ccn = Double(CommandLine.arguments[4]) {
    newEntry.avgComplexity = (ccn * 100).rounded() / 100
}

if let index = entries.lastIndex(where: { $0.date == date }) {
    entries[index] = newEntry
} else {
    entries.append(newEntry)
}

let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
let json = try encoder.encode(entries)
try json.write(to: historyURL)

let locInfo = newEntry.loc.map { ", \($0) LOC, \(newEntry.methods ?? 0) methods" } ?? ""
let ccnInfo = newEntry.avgComplexity.map { ", CCN \($0)" } ?? ""
print("Metrics recorded: \(date) — \(tests) tests, \(roundedCoverage)% coverage\(locInfo)\(ccnInfo)")
