@testable import FamiliarDomain
import Testing

// MARK: - Test Double

final class MockDelegate: AnimationStateMachineDelegate {
    var frameChanges: [Int] = []
    var moves: [(dx: Int, dy: Int)] = []
    var opacityChanges: [Double] = []
    var intervalChanges: [Int] = []
    var respawnCount = 0
    var flipCount = 0

    func stateMachine(_: AnimationStateMachine, didChangeFrame index: Int) {
        frameChanges.append(index)
    }

    func stateMachine(_: AnimationStateMachine, didMove dx: Int, dy: Int) {
        moves.append((dx, dy))
    }

    func stateMachine(_: AnimationStateMachine, didChangeOpacity opacity: Double) {
        opacityChanges.append(opacity)
    }

    func stateMachine(_: AnimationStateMachine, didChangeInterval ms: Int) {
        intervalChanges.append(ms)
    }

    func stateMachineDidRequestRespawn(_: AnimationStateMachine) {
        respawnCount += 1
    }

    func stateMachineDidFlipSprites(_: AnimationStateMachine) {
        flipCount += 1
    }
}

// MARK: - Helpers

private func makeMovement(x: Int = 0, y: Int = 0, interval: Int = 100, opacity: Double = 1.0) -> Movement {
    Movement(x: .constant(x), y: .constant(y), interval: .constant(interval), offsetY: 0, opacity: opacity)
}

private func makeAnimation(
    id: Int,
    name: String = "",
    frames: [Int],
    repeatCount: Int = 0,
    repeatFrom: Int = 0,
    action: String? = nil,
    endAnimation: [NextAnim] = [],
    endBorder: [NextAnim] = [],
    endGravity: [NextAnim] = [],
    startX: Int = 0,
    endX: Int = 0,
    startY: Int = 0,
    endY: Int = 0
) -> Animation {
    Animation(
        id: id, name: name,
        start: makeMovement(x: startX, y: startY),
        end: makeMovement(x: endX, y: endY),
        sequence: AnimationSequence(
            frames: frames,
            repeatCount: .constant(repeatCount),
            repeatFrom: repeatFrom,
            action: action
        ),
        endAnimation: endAnimation,
        endBorder: endBorder,
        endGravity: endGravity
    )
}

private let defaultContext = ExpressionContext(
    screenW: 1920, screenH: 1080, areaW: 1920, areaH: 1055,
    imageW: 64, imageH: 64, imageX: 0, imageY: 0,
    random: 50, randS: 50, scale: 2
)

// MARK: - Tests

@Suite("AnimationStateMachine")
struct AnimationStateMachineTests {
    @Test("respawn sets initial animation from spawn's nextAnimations")
    func respawnSetsInitialAnimation() {
        let anim = makeAnimation(id: 5, frames: [0, 1, 2])
        let spawn = Spawn(
            id: 0, probability: 100,
            x: .constant(0), y: .constant(0),
            nextAnimations: [NextAnim(animationId: 5, probability: 100, only: .none)]
        )
        let sm = AnimationStateMachine(
            animations: [5: anim],
            spawns: [spawn],
            expressionContext: { defaultContext }
        )
        let delegate = MockDelegate()
        sm.delegate = delegate

        sm.respawn()

        #expect(sm.currentAnimationID == 5)
        #expect(delegate.respawnCount == 1)
    }

    @Test("tick reports correct frame index via delegate")
    func tickReportsFrameIndex() {
        let anim = makeAnimation(id: 1, frames: [10, 20, 30])
        let sm = AnimationStateMachine(
            animations: [1: anim],
            spawns: [],
            expressionContext: { defaultContext }
        )
        let delegate = MockDelegate()
        sm.delegate = delegate
        sm.setAnimationForTesting(1)

        sm.tick(currentSurface: nil)

        #expect(delegate.frameChanges == [10])

        sm.tick(currentSurface: nil)

        #expect(delegate.frameChanges == [10, 20])
    }

    @Test("tick advances animationStep each call")
    func tickAdvancesStep() {
        let anim = makeAnimation(id: 1, frames: [0, 1, 2, 3])
        let sm = AnimationStateMachine(
            animations: [1: anim],
            spawns: [],
            expressionContext: { defaultContext }
        )
        sm.setAnimationForTesting(1)

        #expect(sm.animationStep == 0)
        sm.tick(currentSurface: nil)
        #expect(sm.animationStep == 1)
        sm.tick(currentSurface: nil)
        #expect(sm.animationStep == 2)
    }

    @Test("sequence completion transitions to next animation")
    func sequenceCompletionTransitions() {
        let anim1 = makeAnimation(
            id: 1, frames: [0, 1],
            endAnimation: [NextAnim(animationId: 2, probability: 100, only: .none)]
        )
        let anim2 = makeAnimation(id: 2, frames: [10, 11, 12])
        let sm = AnimationStateMachine(
            animations: [1: anim1, 2: anim2],
            spawns: [],
            expressionContext: { defaultContext }
        )
        sm.setAnimationForTesting(1)

        // anim1 has 2 frames, 0 repeats => totalSteps = 2
        sm.tick(currentSurface: nil) // step 0 -> 1
        sm.tick(currentSurface: nil) // step 1 -> 2, completes, transitions

        #expect(sm.currentAnimationID == 2)
        #expect(sm.animationStep == 0)
    }

    @Test("handleDragStart switches to drag animation")
    func dragStartSwitchesToDragAnimation() {
        let walk = makeAnimation(id: 1, frames: [0, 1])
        let drag = makeAnimation(id: 2, name: "drag", frames: [5, 6])
        let sm = AnimationStateMachine(
            animations: [1: walk, 2: drag],
            spawns: [],
            expressionContext: { defaultContext }
        )
        sm.setAnimationForTesting(1)

        sm.handleDragStart()

        #expect(sm.isDragging == true)
        #expect(sm.currentAnimationID == 2)
    }

    @Test("handleDragEnd switches to fall animation")
    func dragEndSwitchesToFallAnimation() {
        let drag = makeAnimation(id: 2, name: "drag", frames: [5, 6])
        let fall = makeAnimation(id: 3, name: "fall", frames: [7, 8])
        let sm = AnimationStateMachine(
            animations: [2: drag, 3: fall],
            spawns: [],
            expressionContext: { defaultContext }
        )
        sm.setAnimationForTesting(2)
        sm.handleDragStart()

        sm.handleDragEnd()

        #expect(sm.isDragging == false)
        #expect(sm.currentAnimationID == 3)
    }

    @Test("handleKill switches to kill animation")
    func killSwitchesToKillAnimation() {
        let walk = makeAnimation(id: 1, frames: [0, 1])
        let kill = makeAnimation(id: 4, name: "kill", frames: [9, 10])
        let sm = AnimationStateMachine(
            animations: [1: walk, 4: kill],
            spawns: [],
            expressionContext: { defaultContext }
        )
        sm.setAnimationForTesting(1)

        sm.handleKill()

        #expect(sm.currentAnimationID == 4)
    }

    @Test("flip action toggles direction and notifies delegate")
    func flipActionTogglesDirection() {
        let flipAnim = makeAnimation(id: 1, frames: [0], action: "flip")
        let sm = AnimationStateMachine(
            animations: [1: flipAnim],
            spawns: [],
            expressionContext: { defaultContext }
        )
        let delegate = MockDelegate()
        sm.delegate = delegate

        let initialDirection = sm.isMovingLeft

        sm.setAnimationForTesting(1)

        #expect(sm.isMovingLeft == !initialDirection) // flip toggles direction
        #expect(delegate.flipCount == 1)
    }

    @Test("tick reports movement when dx or dy is non-zero")
    func tickReportsMovement() {
        let anim = makeAnimation(id: 1, frames: [0, 1], startX: 4, endX: 4)
        let sm = AnimationStateMachine(
            animations: [1: anim],
            spawns: [],
            expressionContext: { defaultContext }
        )
        let delegate = MockDelegate()
        sm.delegate = delegate
        sm.setAnimationForTesting(1)

        sm.tick(currentSurface: nil)

        #expect(!delegate.moves.isEmpty)
    }

    @Test("respawn with no spawns does not crash")
    func respawnWithNoSpawnsDoesNotCrash() {
        let sm = AnimationStateMachine(
            animations: [:],
            spawns: [],
            expressionContext: { defaultContext }
        )
        let delegate = MockDelegate()
        sm.delegate = delegate

        sm.respawn()

        #expect(delegate.respawnCount == 1)
    }

    @Test("setMoodAnimation switches to specified animation and loops")
    func setMoodAnimationLoops() {
        let walk = makeAnimation(id: 1, frames: [0, 1, 2], endAnimation: [
            NextAnim(animationId: 1, probability: 100, only: .none),
        ])
        let run = makeAnimation(id: 7, frames: [10, 11], endAnimation: [
            NextAnim(animationId: 7, probability: 100, only: .none),
        ])
        let sm = AnimationStateMachine(
            animations: [1: walk, 7: run], spawns: [],
            expressionContext: { defaultContext }
        )
        let delegate = MockDelegate()
        sm.delegate = delegate

        sm.setMoodAnimation(7)
        #expect(sm.currentAnimationID == 7)

        // Tick through full sequence — should loop back to 7
        for _ in 0 ..< 10 {
            sm.tick(currentSurface: nil)
        }
        #expect(sm.currentAnimationID == 7)
    }

    @Test("playEventAnimation plays once then returns to mood")
    func playEventAnimationReturnToMood() {
        let walk = makeAnimation(id: 1, frames: [0, 1], endAnimation: [
            NextAnim(animationId: 1, probability: 100, only: .none),
        ])
        let jump = makeAnimation(id: 25, frames: [20, 21], endAnimation: [])
        let sm = AnimationStateMachine(
            animations: [1: walk, 25: jump], spawns: [],
            expressionContext: { defaultContext }
        )
        let delegate = MockDelegate()
        sm.delegate = delegate

        sm.setMoodAnimation(1)
        sm.playEventAnimation(25, returnToMood: 1)
        #expect(sm.currentAnimationID == 25)

        // Tick through event animation — should return to mood (1)
        for _ in 0 ..< 10 {
            sm.tick(currentSurface: nil)
        }
        #expect(sm.currentAnimationID == 1)
    }

    // MARK: - Border hit tests

    @Test("handleBorderHit transitions to next animation")
    func handleBorderHitTransitionsToNextAnimation() {
        let anim = makeAnimation(
            id: 1, frames: [0, 1],
            endBorder: [NextAnim(animationId: 2, probability: 100, only: .none)]
        )
        let anim2 = makeAnimation(id: 2, frames: [5, 6])
        let sm = AnimationStateMachine(
            animations: [1: anim, 2: anim2], spawns: [],
            expressionContext: { defaultContext }
        )
        sm.setAnimationForTesting(1)

        sm.handleBorderHit(type: .taskbar)

        #expect(sm.currentAnimationID == 2)
    }

    @Test("handleBorderHit no match does nothing")
    func handleBorderHitNoMatchDoesNothing() {
        // endBorder only matches .window (rawValue 0x02)
        let anim = makeAnimation(
            id: 1, frames: [0, 1],
            endBorder: [NextAnim(animationId: 2, probability: 100, only: .window)]
        )
        let anim2 = makeAnimation(id: 2, frames: [5, 6])
        let sm = AnimationStateMachine(
            animations: [1: anim, 2: anim2], spawns: [],
            expressionContext: { defaultContext }
        )
        sm.setAnimationForTesting(1)

        sm.handleBorderHit(type: .vertical)

        #expect(sm.currentAnimationID == 1)
    }

    @Test("handleBorderHit empty border does nothing")
    func handleBorderHitEmptyBorderDoesNothing() {
        let anim = makeAnimation(id: 1, frames: [0, 1], endBorder: [])
        let sm = AnimationStateMachine(
            animations: [1: anim], spawns: [],
            expressionContext: { defaultContext }
        )
        sm.setAnimationForTesting(1)

        sm.handleBorderHit(type: .taskbar)

        #expect(sm.currentAnimationID == 1)
    }

    // MARK: - Gravity tests

    @Test("handleGravityLost transitions via endGravity")
    func handleGravityLostTransitionsViaEndGravity() {
        let anim = makeAnimation(
            id: 1, frames: [0, 1],
            endGravity: [NextAnim(animationId: 3, probability: 100, only: .none)]
        )
        let anim3 = makeAnimation(id: 3, frames: [7, 8])
        let sm = AnimationStateMachine(
            animations: [1: anim, 3: anim3], spawns: [],
            expressionContext: { defaultContext }
        )
        sm.setAnimationForTesting(1)

        sm.handleGravityLost()

        #expect(sm.currentAnimationID == 3)
    }

    @Test("handleGravityLost falls back to fall animation")
    func handleGravityLostFallsBackToFall() {
        let anim = makeAnimation(id: 1, frames: [0, 1], endGravity: [])
        let fall = makeAnimation(id: 2, name: "fall", frames: [7, 8])
        let sm = AnimationStateMachine(
            animations: [1: anim, 2: fall], spawns: [],
            expressionContext: { defaultContext }
        )
        sm.setAnimationForTesting(1)

        sm.handleGravityLost()

        #expect(sm.currentAnimationID == 2)
    }

    @Test("handleGravityLost no fall does nothing")
    func handleGravityLostNoFallDoesNothing() {
        let anim = makeAnimation(id: 1, frames: [0, 1], endGravity: [])
        let sm = AnimationStateMachine(
            animations: [1: anim], spawns: [],
            expressionContext: { defaultContext }
        )
        sm.setAnimationForTesting(1)

        sm.handleGravityLost()

        // No fall animation exists, should stay on current
        #expect(sm.currentAnimationID == 1)
    }

    // MARK: - Mood persistence tests

    @Test("mood animation persists after border hit with no transitions")
    func moodAnimationPersistsAfterBorderHit() {
        let walk = makeAnimation(id: 1, frames: [0, 1], endAnimation: [], endBorder: [])
        let sm = AnimationStateMachine(
            animations: [1: walk], spawns: [],
            expressionContext: { defaultContext }
        )
        let delegate = MockDelegate()
        sm.delegate = delegate

        sm.setMoodAnimation(1)

        // Border hit with no transitions should not change animation
        sm.handleBorderHit(type: .taskbar)
        #expect(sm.currentAnimationID == 1)

        // Tick through to sequence completion — mood should loop back
        for _ in 0 ..< 10 {
            sm.tick(currentSurface: nil)
        }
        #expect(sm.currentAnimationID == 1)
    }

    @Test("event animation returns to mood after sequence completes, not the event")
    func eventAnimationReturnsToMoodAfterBorderHit() {
        let walk = makeAnimation(id: 1, frames: [0, 1], endAnimation: [
            NextAnim(animationId: 1, probability: 100, only: .none),
        ])
        let eventAnim = makeAnimation(id: 10, frames: [20, 21], endAnimation: [])
        let sm = AnimationStateMachine(
            animations: [1: walk, 10: eventAnim], spawns: [],
            expressionContext: { defaultContext }
        )
        let delegate = MockDelegate()
        sm.delegate = delegate

        sm.setMoodAnimation(1)
        sm.playEventAnimation(10, returnToMood: 1)
        #expect(sm.currentAnimationID == 10)

        // Tick through event sequence completion
        for _ in 0 ..< 10 {
            sm.tick(currentSurface: nil)
        }

        // Should return to mood (1), not stay on event (10)
        #expect(sm.currentAnimationID == 1)
    }

    // MARK: - Edge cases

    @Test("tick with invalid animation ID does nothing")
    func tickWithInvalidAnimationIDDoesNothing() {
        let anim = makeAnimation(id: 1, frames: [0, 1])
        let sm = AnimationStateMachine(
            animations: [1: anim], spawns: [],
            expressionContext: { defaultContext }
        )
        let delegate = MockDelegate()
        sm.delegate = delegate

        // Set to a valid animation first, then force an invalid ID via setAnimationForTesting
        // setAnimation guards against unknown IDs, so currentAnimationID stays 0
        sm.setAnimationForTesting(999)

        // currentAnimationID should remain 0 since 999 doesn't exist
        #expect(sm.currentAnimationID == 0)

        // Tick should not crash
        sm.tick(currentSurface: nil)
        #expect(delegate.frameChanges.isEmpty)
    }

    @Test("respawn with zero probability spawns does not crash")
    func respawnWithZeroProbabilitySpawns() {
        let spawn = Spawn(
            id: 0, probability: 0,
            x: .constant(0), y: .constant(0),
            nextAnimations: [NextAnim(animationId: 1, probability: 100, only: .none)]
        )
        let anim = makeAnimation(id: 1, frames: [0])
        let sm = AnimationStateMachine(
            animations: [1: anim], spawns: [spawn],
            expressionContext: { defaultContext }
        )
        let delegate = MockDelegate()
        sm.delegate = delegate

        // Should not crash even with probability 0
        sm.respawn()

        // pickWeightedSpawn returns nil when totalProb == 0
        #expect(delegate.respawnCount == 1)
    }
}
