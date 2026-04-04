public struct AnimationSequence: Sendable {
    public let frames: [Int]
    public let repeatCount: Expression
    public let repeatFrom: Int
    public let action: String?

    public init(frames: [Int], repeatCount: Expression, repeatFrom: Int, action: String?) {
        self.frames = frames
        self.repeatCount = repeatCount
        self.repeatFrom = repeatFrom
        self.action = action
    }

    public func totalSteps(repeatValue: Int) -> Int {
        frames.count + (frames.count - repeatFrom) * repeatValue
    }

    public func frameIndex(at step: Int) -> Int {
        if step < frames.count {
            return frames[step]
        }
        let cycleLength = frames.count - repeatFrom
        guard cycleLength > 0 else { return frames.last ?? 0 }
        return frames[((step - frames.count) % cycleLength) + repeatFrom]
    }
}
