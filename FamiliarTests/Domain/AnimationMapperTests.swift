@testable import FamiliarDomain
import Testing

@Suite("AnimationMapper")
struct AnimationMapperTests {
    static let testAnimations: [Int: Animation] = {
        func anim(id: Int, name: String) -> Animation {
            let mov = Movement(
                x: .constant(0), y: .constant(0),
                interval: .constant(100), offsetY: 0, opacity: 1.0
            )
            let seq = AnimationSequence(
                frames: [0], repeatCount: .constant(0),
                repeatFrom: 0, action: nil
            )
            return Animation(
                id: id, name: name, start: mov, end: mov, sequence: seq,
                endAnimation: [], endBorder: [], endGravity: []
            )
        }
        return [
            1: anim(id: 1, name: "walk"),
            5: anim(id: 5, name: "fall"),
            7: anim(id: 7, name: "run"),
            15: anim(id: 15, name: "sleep1a"),
            16: anim(id: 16, name: "sleep2a"),
            21: anim(id: 21, name: "batha"),
            25: anim(id: 25, name: "jump"),
            26: anim(id: 26, name: "eat"),
            27: anim(id: 27, name: "flower"),
            8: anim(id: 8, name: "boing"),
        ]
    }()

    let config = AnimationConfig.default

    @Test func resolvesMoodToAnimationID() {
        let id = AnimationMapper.resolve(
            mood: "work", config: config, animations: Self.testAnimations
        )
        #expect(id == 7) // "run" -> id 7
    }

    @Test func resolvesMoodWithMultipleOptions() {
        let id = AnimationMapper.resolve(
            mood: "think", config: config, animations: Self.testAnimations
        )
        #expect(id == 15 || id == 16)
    }

    @Test func unknownMoodFallsToChill() {
        let id = AnimationMapper.resolve(
            mood: "unknown", config: config, animations: Self.testAnimations
        )
        #expect(id == 1) // "chill" -> "walk" -> id 1
    }

    @Test func resolvesEventToAnimationID() {
        let id = AnimationMapper.resolveEvent(
            event: "yay", config: config, animations: Self.testAnimations
        )
        #expect(id == 21) // "bath a" -> id 21
    }

    @Test func unknownEventReturnsNil() {
        let id = AnimationMapper.resolveEvent(
            event: "unknown", config: config, animations: Self.testAnimations
        )
        #expect(id == nil)
    }
}
