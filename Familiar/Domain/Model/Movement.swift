public struct Movement: Sendable {
    public let x: Expression
    public let y: Expression
    public let interval: Expression
    public let offsetY: Int
    public let opacity: Double

    public init(x: Expression, y: Expression, interval: Expression, offsetY: Int, opacity: Double) {
        self.x = x
        self.y = y
        self.interval = interval
        self.offsetY = offsetY
        self.opacity = opacity
    }
}
