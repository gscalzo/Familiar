public struct AnimationConfig: Codable, Sendable {
    public var moods: [String: [String]]
    public var events: [String: [String]]

    public init(moods: [String: [String]], events: [String: [String]]) {
        self.moods = moods
        self.events = events
    }

    public static let `default` = AnimationConfig(
        moods: [
            "chill": ["walk"],
            "think": ["sleep 1a", "sleep 2a"],
            "work": ["run"],
            "wait": ["eat"],
            "sleep": ["sleep 3a"],
        ],
        events: [
            "yay": ["bath a"],
            "oops": ["fall"],
            "hmm": ["boing"],
            "go": ["jump"],
            "done": ["flower"],
        ]
    )
}
