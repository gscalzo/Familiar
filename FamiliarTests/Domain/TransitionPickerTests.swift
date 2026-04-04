@testable import FamiliarDomain
import Testing

@Suite("TransitionPicker")
struct TransitionPickerTests {
    @Test func pickFromEmptyCandidates() {
        let result = TransitionPicker.pick(from: [], context: .none)
        #expect(result == nil)
    }

    @Test func pickSingleCandidate() {
        let candidates = [NextAnim(animationId: 5, probability: 100, only: .none)]
        let result = TransitionPicker.pick(from: candidates, context: .none)
        #expect(result == 5)
    }

    @Test func filtersByBorderType() {
        let candidates = [
            NextAnim(animationId: 1, probability: 100, only: .taskbar),
            NextAnim(animationId: 2, probability: 100, only: .window),
        ]
        // Context is window — only candidate 2 should match
        let result = TransitionPicker.pick(from: candidates, context: .window)
        #expect(result == 2)
    }

    @Test func noneMatchesEverything() {
        let candidates = [
            NextAnim(animationId: 7, probability: 100, only: .none),
        ]
        let result = TransitionPicker.pick(from: candidates, context: .taskbar)
        #expect(result == 7)
    }

    @Test func zeroProbabilityReturnsNil() {
        let candidates = [
            NextAnim(animationId: 1, probability: 0, only: .none),
        ]
        let result = TransitionPicker.pick(from: candidates, context: .none)
        #expect(result == nil)
    }

    @Test func allFilteredOutReturnsNil() {
        let candidates = [
            NextAnim(animationId: 1, probability: 100, only: .taskbar),
        ]
        // Context is vertical — taskbar doesn't match
        let result = TransitionPicker.pick(from: candidates, context: .vertical)
        #expect(result == nil)
    }

    @Test func weightedDistribution() {
        let candidates = [
            NextAnim(animationId: 1, probability: 90, only: .none),
            NextAnim(animationId: 2, probability: 10, only: .none),
        ]
        var seen: Set<Int> = []
        for _ in 0 ..< 200 {
            if let id = TransitionPicker.pick(from: candidates, context: .none) {
                seen.insert(id)
            }
        }
        #expect(seen.contains(1))
        #expect(seen.contains(2))
    }

    @Test func horizontalPlusMatchesWindowContext() {
        let candidates = [
            NextAnim(animationId: 1, probability: 100, only: .horizontalPlus),
        ]
        // horizontalPlus = window | horizontal. Context is window, should match.
        let result = TransitionPicker.pick(from: candidates, context: .window)
        #expect(result == 1)
    }
}
