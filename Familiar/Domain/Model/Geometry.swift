public struct Vec2: Sendable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public static let zero = Vec2(x: 0, y: 0)
}

public struct Rect: Sendable {
    public let origin: Vec2
    public let width: Double
    public let height: Double

    public init(origin: Vec2, width: Double, height: Double) {
        self.origin = origin
        self.width = width
        self.height = height
    }
}
