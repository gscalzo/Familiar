@testable import FamiliarDomain
@testable import FamiliarInfrastructure
import Foundation
import Testing

@Suite("StateFileWatcher")
struct StateFileWatcherTests {
    func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("familiar-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test func readsMissingFileAsEmpty() {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("nonexistent-\(UUID().uuidString)")
        let watcher = StateFileWatcher(directory: dir.path)
        let states = watcher.readStates()
        #expect(states.isEmpty)
    }

    @Test func readsValidStateFile() throws {
        let dir = try makeTempDir()
        let json = """
        {"default": {"mood": "work", "event": null, "eventTimestamp": null}}
        """
        try json.write(
            to: dir.appendingPathComponent("state.json"),
            atomically: true, encoding: .utf8
        )
        let watcher = StateFileWatcher(directory: dir.path)
        let states = watcher.readStates()
        #expect(states["default"]?.mood == "work")
        #expect(states["default"]?.event == nil)
    }

    @Test func handlesCorruptJSON() throws {
        let dir = try makeTempDir()
        try "not json".write(
            to: dir.appendingPathComponent("state.json"),
            atomically: true, encoding: .utf8
        )
        let watcher = StateFileWatcher(directory: dir.path)
        let states = watcher.readStates()
        #expect(states.isEmpty)
    }

    @Test func clearsEventAfterConsuming() throws {
        let dir = try makeTempDir()
        let json = """
        {"default": {"mood": "work", "event": "yay", "eventTimestamp": "2026-04-04T17:45:00Z"}}
        """
        let stateFile = dir.appendingPathComponent("state.json")
        try json.write(to: stateFile, atomically: true, encoding: .utf8)

        let watcher = StateFileWatcher(directory: dir.path)
        watcher.clearEvent(forPet: "default")

        let data = try Data(contentsOf: stateFile)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let states = try decoder.decode([String: PetState].self, from: data)
        #expect(states["default"]?.event == nil)
        #expect(states["default"]?.mood == "work")
    }

    @Test func readsAnimationConfig() throws {
        let dir = try makeTempDir()
        let json = """
        {"moods": {"chill": ["walk"]}, "events": {"yay": ["bath a"]}}
        """
        try json.write(
            to: dir.appendingPathComponent("animations.json"),
            atomically: true, encoding: .utf8
        )
        let watcher = StateFileWatcher(directory: dir.path)
        let config = watcher.readAnimationConfig()
        #expect(config.moods["chill"] == ["walk"])
        #expect(config.events["yay"] == ["bath a"])
    }

    @Test func missingAnimationConfigReturnsDefault() {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("nonexistent-\(UUID().uuidString)")
        let watcher = StateFileWatcher(directory: dir.path)
        let config = watcher.readAnimationConfig()
        #expect(config.moods["chill"] == ["walk"])
    }

    @Test func writeDefaultConfigCreatesFile() throws {
        let dir = try makeTempDir()
        let watcher = StateFileWatcher(directory: dir.path)
        watcher.writeDefaultConfigIfNeeded()

        let configFile = dir.appendingPathComponent("animations.json")
        #expect(FileManager.default.fileExists(atPath: configFile.path))

        let data = try Data(contentsOf: configFile)
        let config = try JSONDecoder().decode(AnimationConfig.self, from: data)
        #expect(config.moods["chill"] == ["walk"])
    }

    @Test func writeDefaultConfigDoesNotOverwrite() throws {
        let dir = try makeTempDir()
        let customJSON = """
        {"moods": {"custom": ["walk"]}, "events": {}}
        """
        try customJSON.write(
            to: dir.appendingPathComponent("animations.json"),
            atomically: true, encoding: .utf8
        )
        let watcher = StateFileWatcher(directory: dir.path)
        watcher.writeDefaultConfigIfNeeded()

        let config = watcher.readAnimationConfig()
        #expect(config.moods["custom"] == ["walk"])
    }

    @Test func writeStatesCreatesFile() throws {
        let dir = try makeTempDir()
        let watcher = StateFileWatcher(directory: dir.path)
        let states = ["pet1": PetState(mood: "chill")]
        watcher.writeStates(states)

        let stateFile = dir.appendingPathComponent("state.json")
        #expect(FileManager.default.fileExists(atPath: stateFile.path))

        let readBack = watcher.readStates()
        #expect(readBack["pet1"]?.mood == "chill")
    }

    @Test func writeStatesOverwritesExisting() throws {
        let dir = try makeTempDir()
        let watcher = StateFileWatcher(directory: dir.path)

        watcher.writeStates(["pet1": PetState(mood: "work")])
        watcher.writeStates(["pet1": PetState(mood: "sleep")])

        let readBack = watcher.readStates()
        #expect(readBack["pet1"]?.mood == "sleep")
    }

    @Test func readStatesWithMultiplePets() throws {
        let dir = try makeTempDir()
        let json = """
        {
          "alpha": {"mood": "chill", "event": null, "eventTimestamp": null},
          "beta": {"mood": "work", "event": null, "eventTimestamp": null},
          "gamma": {"mood": "sleep", "event": null, "eventTimestamp": null}
        }
        """
        try json.write(
            to: dir.appendingPathComponent("state.json"),
            atomically: true, encoding: .utf8
        )
        let watcher = StateFileWatcher(directory: dir.path)
        let states = watcher.readStates()
        #expect(states.count == 3)
        #expect(states["alpha"]?.mood == "chill")
        #expect(states["beta"]?.mood == "work")
        #expect(states["gamma"]?.mood == "sleep")
    }

    @Test func clearEventPreservesMoodAndOtherPets() throws {
        let dir = try makeTempDir()
        let json = """
        {
          "pet1": {"mood": "work", "event": "yay", "eventTimestamp": "2026-04-04T17:45:00Z"},
          "pet2": {"mood": "chill", "event": "oops", "eventTimestamp": "2026-04-04T18:00:00Z"}
        }
        """
        try json.write(
            to: dir.appendingPathComponent("state.json"),
            atomically: true, encoding: .utf8
        )
        let watcher = StateFileWatcher(directory: dir.path)
        watcher.clearEvent(forPet: "pet1")

        let states = watcher.readStates()
        // pet1 event cleared, mood preserved
        #expect(states["pet1"]?.event == nil)
        #expect(states["pet1"]?.mood == "work")
        // pet2 unchanged
        #expect(states["pet2"]?.event == "oops")
        #expect(states["pet2"]?.mood == "chill")
    }
}
