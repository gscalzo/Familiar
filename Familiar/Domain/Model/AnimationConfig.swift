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
            "think": ["sleep1a", "sleep2a"],
            "work": ["run"],
            "wait": ["eat"],
            "sleep": ["sleep3a"],
        ],
        events: [
            "yay": ["batha"],
            "oops": ["fall"],
            "hmm": ["boing"],
            "go": ["jump"],
            "done": ["flower"],
        ]
    )
}
