import Foundation

public struct PetState: Codable, Sendable {
    public var mood: String
    public var event: String?
    public var eventTimestamp: Date?

    public init(mood: String, event: String? = nil, eventTimestamp: Date? = nil) {
        self.mood = mood
        self.event = event
        self.eventTimestamp = eventTimestamp
    }

    public static let `default` = PetState(mood: "chill")
}
