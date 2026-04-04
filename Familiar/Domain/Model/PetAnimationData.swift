public struct PetAnimationData: Sendable {
    public let header: PetHeader
    public let spriteInfo: SpriteSheetInfo
    public let spawns: [Spawn]
    public let animations: [Int: Animation]
    public let children: [ChildDefinition]

    public init(
        header: PetHeader,
        spriteInfo: SpriteSheetInfo,
        spawns: [Spawn],
        animations: [Int: Animation],
        children: [ChildDefinition]
    ) {
        self.header = header
        self.spriteInfo = spriteInfo
        self.spawns = spawns
        self.animations = animations
        self.children = children
    }
}
