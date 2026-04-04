public struct NextAnim: Sendable {
    public let animationId: Int
    public let probability: Int
    public let only: BorderType

    public init(animationId: Int, probability: Int, only: BorderType) {
        self.animationId = animationId
        self.probability = probability
        self.only = only
    }
}
