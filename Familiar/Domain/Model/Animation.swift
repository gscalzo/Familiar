public struct Animation: Sendable {
    public let id: Int
    public let name: String
    public let start: Movement
    public let end: Movement
    public let sequence: AnimationSequence
    public let endAnimation: [NextAnim]
    public let endBorder: [NextAnim]
    public let endGravity: [NextAnim]

    public var hasGravity: Bool { !endGravity.isEmpty }
    public var hasBorder: Bool { !endBorder.isEmpty }

    public init(
        id: Int,
        name: String,
        start: Movement,
        end: Movement,
        sequence: AnimationSequence,
        endAnimation: [NextAnim],
        endBorder: [NextAnim],
        endGravity: [NextAnim]
    ) {
        self.id = id
        self.name = name
        self.start = start
        self.end = end
        self.sequence = sequence
        self.endAnimation = endAnimation
        self.endBorder = endBorder
        self.endGravity = endGravity
    }
}
