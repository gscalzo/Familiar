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

        self.fallAnimationID = animations.values.first(where: { $0.name == "fall" })?.id
        self.dragAnimationID = animations.values.first(where: { $0.name == "drag" })?.id
        self.killAnimationID = animations.values.first(where: { $0.name == "kill" })?.id
        self.fallFastAnimationID = animations.values.first(where: { $0.name == "fall fast" })?.id
    }

    // MARK: - Public API

    public func tick(currentSurface: SurfaceType?) {
        guard let anim = animations[currentAnimationID] else { return }

        let ctx = expressionContext()
        let seq = anim.sequence

        // Compute frame index
        let frameIndex = seq.frameIndex(at: animationStep)
        delegate?.stateMachine(self, didChangeFrame: frameIndex)

        // Interpolate movement
        let startX = anim.start.x.evaluate(context: ctx)
        let endX = anim.end.x.evaluate(context: ctx)
        let startY = anim.start.y.evaluate(context: ctx)
        let endY = anim.end.y.evaluate(context: ctx)

        var dx = Interpolator.movement(start: startX, end: endX, step: animationStep, totalSteps: totalSteps)
        let dy = Interpolator.movement(start: startY, end: endY, step: animationStep, totalSteps: totalSteps)

        // Apply direction
        if !isMovingLeft { dx = -dx }

        if dx != 0 || dy != 0 {
            delegate?.stateMachine(self, didMove: dx, dy: dy)
        }

        // Interpolate interval
        let startInterval = anim.start.interval.evaluate(context: ctx)
        let endInterval = anim.end.interval.evaluate(context: ctx)
        let interval = Interpolator.value(
            start: startInterval, end: endInterval,
            step: animationStep, totalSteps: totalSteps
        )
        delegate?.stateMachine(self, didChangeInterval: interval)

        // Interpolate opacity
        let startOpacity = anim.start.opacity
        let endOpacity = anim.end.opacity
        let opacity = startOpacity + (endOpacity - startOpacity)
            * Double(animationStep) / Double(max(totalSteps, 1))
        delegate?.stateMachine(self, didChangeOpacity: opacity)

        // Advance step
        animationStep += 1

        // Check sequence completion
        if animationStep >= totalSteps {
            handleSequenceComplete(anim, currentSurface: currentSurface)
        }
    }

    public func respawn() {
        guard !spawns.isEmpty else { return }

        // Pick spawn by weighted probability
        let totalProb = spawns.reduce(0) { $0 + $1.probability }
        guard totalProb > 0 else { return }

        var roll = Int.random(in: 1 ... totalProb)
        var selectedSpawn = spawns[0]
        for spawn in spawns {
            roll -= spawn.probability
            if roll <= 0 {
                selectedSpawn = spawn
                break
            }
        }

        // Pick initial animation from spawn's next list
        if let nextId = TransitionPicker.pick(from: selectedSpawn.nextAnimations, context: .none) {
            setAnimation(nextId)
        }

        delegate?.stateMachineDidRequestRespawn(self)
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
            setAnimation(nextId)
        } else if let moodId = moodAnimationID {
            // No transition — loop mood animation
            setAnimation(moodId)
        } else {
            respawn()
        }
    }

    private func borderType(from surface: SurfaceType?) -> BorderType {
        guard let surface else { return .none }
        switch surface {
        case .screenBottom: return .taskbar
        case .screenLeft, .screenRight: return .vertical
        case .screenTop: return .horizontal
        case .windowTop: return .window
        }
    }
}
