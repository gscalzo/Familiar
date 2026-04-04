public struct Spawn: Sendable {
    public let id: Int
    public let probability: Int
    public let x: Expression
    public let y: Expression
    public let nextAnimations: [NextAnim]

    public init(id: Int, probability: Int, x: Expression, y: Expression, nextAnimations: [NextAnim]) {
        self.id = id
        self.probability = probability
        self.x = x
        self.y = y
        self.nextAnimations = nextAnimations
    }
}
