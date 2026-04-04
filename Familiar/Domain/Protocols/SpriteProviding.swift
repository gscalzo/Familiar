public protocol SpriteProviding: AnyObject {
    var frameCount: Int { get }
    var frameWidth: Int { get }
    var frameHeight: Int { get }
    var isFlipped: Bool { get }
    func flipAllFrames()
}
