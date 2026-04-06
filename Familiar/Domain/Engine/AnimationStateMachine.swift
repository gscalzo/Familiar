// MARK: - Delegate Protocol

public protocol AnimationStateMachineDelegate: AnyObject {
    func stateMachine(_ sm: AnimationStateMachine, didChangeFrame index: Int)
    func stateMachine(_ sm: AnimationStateMachine, didMove dx: Int, dy: Int)
    func stateMachine(_ sm: AnimationStateMachine, didChangeOpacity opacity: Double)
    func stateMachine(_ sm: AnimationStateMachine, didChangeInterval ms: Int)
    func stateMachineDidRequestRespawn(_ sm: AnimationStateMachine)
    func stateMachineDidFlipSprites(_ sm: AnimationStateMachine)
}

// MARK: - AnimationStateMachine

public final class AnimationStateMachine {
    // Current state
    public private(set) var currentAnimationID: Int = 0
    public private(set) var animationStep: Int = 0
    public private(set) var isMovingLeft: Bool = .random()
    public private(set) var isDragging: Bool = false

    // Dependencies
    private let animations: [Int: Animation]
    private let spawns: [Spawn]
    private let expressionContext: () -> ExpressionContext
    public weak var delegate: AnimationStateMachineDelegate?

    // Special animation IDs (resolved by name at init)
    private let fallAnimationID: Int?
    private let fallFastAnimationID: Int?
    private let dragAnimationID: Int?
    private let killAnimationID: Int?

    // Mood / event state
    private var moodAnimationID: Int?
    private var returnToMoodID: Int?

    // Internal state
    private var totalSteps: Int = 0
    private var repeatValue: Int = 0

    public init(
        animations: [Int: Animation],
        spawns: [Spawn],
        expressionContext: @escaping () -> ExpressionContext
    ) {
        self.animations = animations
        self.spawns = spawns
        self.expressionContext = expressionContext

        func findAnimation(named name: String) -> Int? {
            animations.values.first(where: { $0.name == name })?.id
        }
        self.fallAnimationID = findAnimation(named: "fall")
        self.dragAnimationID = findAnimation(named: "drag")
        self.killAnimationID = findAnimation(named: "kill")
        self.fallFastAnimationID = findAnimation(named: "fall fast")
    }

    // MARK: - Public API

    public func tick(currentSurface: SurfaceType?) {
        guard let anim = animations[currentAnimationID] else { return }

        let ctx = expressionContext()

        emitFrame(anim: anim)
        emitMovement(anim: anim, ctx: ctx)
        emitInterval(anim: anim, ctx: ctx)
        emitOpacity(anim: anim)

        animationStep += 1

        if animationStep >= totalSteps {
            handleSequenceComplete(anim, currentSurface: currentSurface)
        }
    }

    private func emitFrame(anim: Animation) {
        let frameIndex = anim.sequence.frameIndex(at: animationStep)
        delegate?.stateMachine(self, didChangeFrame: frameIndex)
    }

    private func emitMovement(anim: Animation, ctx: ExpressionContext) {
        let startX = anim.start.x.evaluate(context: ctx)
        let endX = anim.end.x.evaluate(context: ctx)
        let startY = anim.start.y.evaluate(context: ctx)
        let endY = anim.end.y.evaluate(context: ctx)

        var dx = Interpolator.movement(start: startX, end: endX, step: animationStep, totalSteps: totalSteps)
        let dy = Interpolator.movement(start: startY, end: endY, step: animationStep, totalSteps: totalSteps)

        if !isMovingLeft { dx = -dx }
        if dx != 0 || dy != 0 { delegate?.stateMachine(self, didMove: dx, dy: dy) }
    }

    private func emitInterval(anim: Animation, ctx: ExpressionContext) {
        let startInterval = anim.start.interval.evaluate(context: ctx)
        let endInterval = anim.end.interval.evaluate(context: ctx)
        let interval = Interpolator.value(
            start: startInterval, end: endInterval,
            step: animationStep, totalSteps: totalSteps
        )
        delegate?.stateMachine(self, didChangeInterval: interval)
    }

    private func emitOpacity(anim: Animation) {
        let opacity = anim.start.opacity + (anim.end.opacity - anim.start.opacity)
            * Double(animationStep) / Double(max(totalSteps, 1))
        delegate?.stateMachine(self, didChangeOpacity: opacity)
    }

    public func respawn() {
        var animId: Int?
        if let spawn = pickWeightedSpawn() {
            animId = TransitionPicker.pick(from: spawn.nextAnimations, context: .none)
        }
        setAnimation(animId ?? findBestStartAnimation())
        delegate?.stateMachineDidRequestRespawn(self)
    }

    private func findBestStartAnimation() -> Int {
        // Prefer "walk" animation, then first with non-zero x movement, then first by ID
        let walkNames = ["walk", "idle", "walk1", "run"]
        for name in walkNames {
            if let id = animations.values.first(where: { $0.name == name })?.id {
                return id
            }
        }
        // Find first animation with horizontal movement
        if let id = animations.values.first(where: {
            $0.start.x.raw != "0" && $0.start.y.raw == "0"
        })?.id {
            return id
        }
        return animations.keys.sorted().first ?? 0
    }

    private func pickWeightedSpawn() -> Spawn? {
        guard !spawns.isEmpty else { return nil }
        let totalProb = spawns.reduce(0) { $0 + $1.probability }
        guard totalProb > 0 else { return nil }

        var roll = Int.random(in: 1 ... totalProb)
        for spawn in spawns {
            roll -= spawn.probability
            if roll <= 0 { return spawn }
        }
        return spawns[0]
    }

    public func handleDragStart() {
        isDragging = true
        if let dragID = dragAnimationID {
            setAnimation(dragID)
        }
    }

    public func handleDragEnd() {
        isDragging = false
        if let fastID = fallFastAnimationID {
            setAnimation(fastID)
        } else if let fallID = fallAnimationID {
            setAnimation(fallID)
        }
    }

    public func handleBorderHit(type: BorderType) {
        guard let anim = animations[currentAnimationID] else { return }
        if let nextId = TransitionPicker.pick(from: anim.endBorder, context: type) {
            let nextName = animations[nextId]?.name ?? "?"
            setAnimation(nextId)
        }
    }

    public func handleGravityLost() {
        guard let anim = animations[currentAnimationID] else { return }
        if let nextId = TransitionPicker.pick(from: anim.endGravity, context: .none) {
            setAnimation(nextId)
        } else if let fallId = fallAnimationID {
            setAnimation(fallId)
        }
    }

    public func handleKill() {
        if let killID = killAnimationID {
            setAnimation(killID)
        }
    }

    public func setMoodAnimation(_ id: Int) {
        moodAnimationID = id
        returnToMoodID = nil
        setAnimation(id)
    }

    public func playEventAnimation(_ id: Int, returnToMood moodId: Int) {
        returnToMoodID = moodId
        setAnimation(id)
    }

    /// Test-only entry point to set current animation without going through respawn.
    public func setAnimationForTesting(_ id: Int) {
        setAnimation(id)
    }

    // MARK: - Private

    private func setAnimation(_ id: Int) {
        guard let anim = animations[id] else { return }
        print(
            "[SM] setAnimation \(anim.name)(\(id)) x=\(anim.start.x.raw) y=\(anim.start.y.raw) flip=\(anim.sequence.action ?? "none")"
        )
        currentAnimationID = id
        animationStep = 0

        let ctx = expressionContext()
        repeatValue = anim.sequence.repeatCount.evaluate(context: ctx)
        totalSteps = anim.sequence.totalSteps(repeatValue: repeatValue)

        // Handle flip action
        if anim.sequence.action == "flip" {
            isMovingLeft.toggle()
            delegate?.stateMachineDidFlipSprites(self)
        }
    }

    private func handleSequenceComplete(_ anim: Animation, currentSurface: SurfaceType?) {
        // If returning from event animation, go back to mood
        if let moodId = returnToMoodID {
            returnToMoodID = nil
            setAnimation(moodId)
            return
        }

        let borderContext = borderType(from: currentSurface)
        if let nextId = TransitionPicker.pick(from: anim.endAnimation, context: borderContext) {
            let nextName = animations[nextId]?.name ?? "?"
            print(
                "[SM] seqComplete \(anim.name)(\(anim.id)) surface=\(String(describing: currentSurface)) border=\(borderContext.rawValue) → \(nextName)(\(nextId))"
            )
            setAnimation(nextId)
        } else if let moodId = moodAnimationID {
            // No transition — loop mood animation
            setAnimation(moodId)
        } else {
            respawn()
        }
    }

    private func borderType(from surface: SurfaceType?) -> BorderType {
        surface?.borderType ?? .none
    }
}
