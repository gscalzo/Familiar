public struct ChildDefinition: Sendable {
    public let animationId: Int
    public let x: Expression
    public let y: Expression
    public let nextAnimationId: Int

    public init(animationId: Int, x: Expression, y: Expression, nextAnimationId: Int) {
        self.animationId = animationId
        self.x = x
        self.y = y
        self.nextAnimationId = nextAnimationId
    }
}
