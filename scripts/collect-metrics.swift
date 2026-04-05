#!/usr/bin/env swift
import Foundation

guard CommandLine.arguments.count == 3,
      let tests = Int(CommandLine.arguments[1]),
      let coverage = Double(CommandLine.arguments[2])
else {
    fputs("Usage: collect-metrics.swift <test_count> <coverage_pct>\n", stderr)
    exit(1)
}

struct MetricEntry: Codable {
    let date: String
    let tests: Int
    let coverage: Double
}

let formatter = DateFormatter()
formatter.dateFormat = "yyyy-MM-dd"
let date = formatter.string(from: Date())

let scriptDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let projectRoot = scriptDir.deletingLastPathComponent()
let metricsDir = projectRoot.appendingPathComponent("docs/metrics")
let historyURL = metricsDir.appendingPathComponent("history.json")

// Ensure directory exists
try FileManager.default.createDirectory(at: metricsDir, withIntermediateDirectories: true)

// Read existing entries or start fresh
var entries: [MetricEntry] = []
if let data = try? Data(contentsOf: historyURL) {
    entries = (try? JSONDecoder().decode([MetricEntry].self, from: data)) ?? []
}

// Replace existing entry for today, or append
let roundedCoverage = (coverage * 100).rounded() / 100
let newEntry = MetricEntry(date: date, tests: tests, coverage: roundedCoverage)
if let index = entries.lastIndex(where: { $0.date == date }) {
    entries[index] = newEntry
} else {
    entries.append(newEntry)
}

// Write back
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
let json = try encoder.encode(entries)
try json.write(to: historyURL)

print("Metrics recorded: \(date) — \(tests) tests, \(roundedCoverage)% coverage")
