import Testing

@testable import FamiliarDomain

@Suite("AnimationSequence")
struct AnimationSequenceTests {
    @Test func totalStepsNoRepeat() {
        let seq = AnimationSequence(frames: [0, 1, 2], repeatCount: .constant(0), repeatFrom: 0, action: nil)
        #expect(seq.totalSteps(repeatValue: 0) == 3)
    }

    @Test func totalStepsWithRepeat() {
        let seq = AnimationSequence(frames: [0, 1, 2, 3], repeatCount: .constant(2), repeatFrom: 1, action: nil)
        // 4 + (4 - 1) * 2 = 10
        #expect(seq.totalSteps(repeatValue: 2) == 10)
    }

    @Test func totalStepsRepeatFromZero() {
        let seq = AnimationSequence(frames: [0, 1, 2], repeatCount: .constant(3), repeatFrom: 0, action: nil)
        // 3 + (3 - 0) * 3 = 12
        #expect(seq.totalSteps(repeatValue: 3) == 12)
    }

    @Test func frameIndexInInitialRange() {
        let seq = AnimationSequence(frames: [10, 20, 30], repeatCount: .constant(0), repeatFrom: 0, action: nil)
        #expect(seq.frameIndex(at: 0) == 10)
        #expect(seq.frameIndex(at: 1) == 20)
        #expect(seq.frameIndex(at: 2) == 30)
    }

    @Test func frameIndexInRepeatCycle() {
        let seq = AnimationSequence(
            frames: [10, 20, 30, 40], repeatCount: .constant(3), repeatFrom: 1, action: nil
        )
        // Cycle over frames[1], frames[2], frames[3] = [20, 30, 40]
        #expect(seq.frameIndex(at: 4) == 20) // first repeat
        #expect(seq.frameIndex(at: 5) == 30)
        #expect(seq.frameIndex(at: 6) == 40)
        #expect(seq.frameIndex(at: 7) == 20) // second repeat
    }

    @Test func frameIndexRepeatFromZero() {
        let seq = AnimationSequence(frames: [10, 20, 30], repeatCount: .constant(2), repeatFrom: 0, action: nil)
        // Cycle over all frames
        #expect(seq.frameIndex(at: 3) == 10)
        #expect(seq.frameIndex(at: 4) == 20)
        #expect(seq.frameIndex(at: 5) == 30)
    }
}
