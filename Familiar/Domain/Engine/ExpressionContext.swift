public struct ExpressionContext: Sendable {
    public let screenW: Int
    public let screenH: Int
    public let areaW: Int
    public let areaH: Int
    public let imageW: Int
    public let imageH: Int
    public let imageX: Int
    public let imageY: Int
    public let random: Int
    public let randS: Int
    public let scale: Int

    public init(
        screenW: Int, screenH: Int,
        areaW: Int, areaH: Int,
        imageW: Int, imageH: Int,
        imageX: Int, imageY: Int,
        random: Int, randS: Int, scale: Int
    ) {
        self.screenW = screenW
        self.screenH = screenH
        self.areaW = areaW
        self.areaH = areaH
        self.imageW = imageW
        self.imageH = imageH
        self.imageX = imageX
        self.imageY = imageY
        self.random = random
        self.randS = randS
        self.scale = scale
    }
}
