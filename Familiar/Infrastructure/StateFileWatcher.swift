import FamiliarDomain
import Foundation

public final class StateFileWatcher: Sendable {
    private let stateURL: URL
    private let configURL: URL
    private let directory: URL

    public init(directory: String) {
        self.directory = URL(fileURLWithPath: directory)
        self.stateURL = self.directory.appendingPathComponent("state.json")
        self.configURL = self.directory.appendingPathComponent("animations.json")
    }

    public convenience init() {
        self.init(directory: NSHomeDirectory() + "/.familiar")
    }

    public func readStates() -> [String: PetState] {
        guard let data = try? Data(contentsOf: stateURL) else { return [:] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([String: PetState].self, from: data)) ?? [:]
    }

    public func clearEvent(forPet name: String) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard var states = try? decoder.decode(
            [String: PetState].self,
            from: Data(contentsOf: stateURL)
        ) else { return }

        states[name]?.event = nil
        states[name]?.eventTimestamp = nil

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(states) {
            try? data.write(to: stateURL)
        }
    }

    public func readAnimationConfig() -> AnimationConfig {
        guard let data = try? Data(contentsOf: configURL),
              let config = try? JSONDecoder().decode(AnimationConfig.self, from: data)
        else { return .default }
        return config
    }

    public func writeDefaultConfigIfNeeded() {
        guard !FileManager.default.fileExists(atPath: configURL.path) else { return }
        try? FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(AnimationConfig.default) {
            try? data.write(to: configURL)
        }
    }
}
