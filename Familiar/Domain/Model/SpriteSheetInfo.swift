public struct SpriteSheetInfo: Sendable {
    public let tilesX: Int
    public let tilesY: Int

    public init(tilesX: Int, tilesY: Int) {
        self.tilesX = tilesX
        self.tilesY = tilesY
    }
}
