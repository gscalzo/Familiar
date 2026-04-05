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

    public func writeStates(_ states: [String: PetState]) {
        ensureDirectoryExists()
        encodeAndWrite(states, to: stateURL)
    }

    public func stateFileExists() -> Bool {
        FileManager.default.fileExists(atPath: stateURL.path)
    }

    public func readStates() -> [String: PetState] {
        decodeFromFile(stateURL) ?? [:]
    }

    public func clearEvent(forPet name: String) {
        guard var states: [String: PetState] = decodeFromFile(stateURL) else { return }
        states[name]?.event = nil
        states[name]?.eventTimestamp = nil
        encodeAndWrite(states, to: stateURL)
    }

    public func readAnimationConfig() -> AnimationConfig {
        decodeFromFile(configURL) ?? .default
    }

    public func writeDefaultConfigIfNeeded() {
        guard !FileManager.default.fileExists(atPath: configURL.path) else { return }
        ensureDirectoryExists()
        encodeAndWrite(AnimationConfig.default, to: configURL)
    }

    // MARK: - Private Helpers

    private func ensureDirectoryExists() {
        try? FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true
        )
    }

    private func encodeAndWrite(_ value: some Encodable, to url: URL) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(value) {
            try? data.write(to: url)
        }
    }

    private func decodeFromFile<T: Decodable>(_ url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(T.self, from: data)
    }
}
