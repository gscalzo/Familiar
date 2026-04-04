public struct WalkableSurface: Sendable {
    public let rect: Rect
    public let type: SurfaceType

    public init(rect: Rect, type: SurfaceType) {
        self.rect = rect
        self.type = type
    }
}
