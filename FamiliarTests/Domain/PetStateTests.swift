import Foundation
import Testing

@testable import FamiliarDomain

@Suite("PetState")
struct PetStateTests {
    @Test func decodesFromJSON() throws {
        let json = """
        {"mood": "work", "event": "yay", "eventTimestamp": "2026-04-04T17:45:00Z"}
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let state = try decoder.decode(PetState.self, from: Data(json.utf8))
        #expect(state.mood == "work")
        #expect(state.event == "yay")
        #expect(state.eventTimestamp != nil)
    }

    @Test func decodesWithNullEvent() throws {
        let json = """
        {"mood": "chill", "event": null, "eventTimestamp": null}
        """
        let state = try JSONDecoder().decode(PetState.self, from: Data(json.utf8))
        #expect(state.mood == "chill")
        #expect(state.event == nil)
    }

    @Test func encodesRoundTrip() throws {
        let state = PetState(mood: "think", event: "go", eventTimestamp: Date())
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(state)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(PetState.self, from: data)
        #expect(decoded.mood == "think")
        #expect(decoded.event == "go")
    }

    @Test func defaultStateIsChill() {
        let state = PetState.default
        #expect(state.mood == "chill")
        #expect(state.event == nil)
    }
}
