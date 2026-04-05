import AppKit
import FamiliarDomain

public final class SpriteSheetLoader: SpriteProviding {
    private var frames: [NSImage] = []
    private var flippedFramesCache: [NSImage]?
    public private(set) var isFlipped = false
    private let tileWidth: Int
    private let tileHeight: Int

    public var frameCount: Int { frames.count }
    public var frameWidth: Int { tileWidth }
    public var frameHeight: Int { tileHeight }

    public init(base64PNG: String, tilesX: Int, tilesY: Int) throws {
        guard let data = Data(base64Encoded: base64PNG, options: .ignoreUnknownCharacters) else {
            throw SpriteSheetError.invalidBase64
        }
        guard let nsImage = NSImage(data: data),
              let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else {
            throw SpriteSheetError.invalidImage
        }

        let tileW = cgImage.width / tilesX
        let tileH = cgImage.height / tilesY
        self.tileWidth = tileW
        self.tileHeight = tileH

        for row in 0 ..< tilesY {
            for col in 0 ..< tilesX {
                let rect = CGRect(x: col * tileW, y: row * tileH, width: tileW, height: tileH)
                if let cropped = cgImage.cropping(to: rect) {
                    frames.append(NSImage(cgImage: cropped, size: NSSize(width: tileW, height: tileH)))
                }
            }
        }
    }

    public func image(at index: Int) -> NSImage {
        let validIndex = max(0, min(index, frames.count - 1))
        if isFlipped {
            return flippedFrames()[validIndex]
        }
        return frames[validIndex]
    }

    public func setFlipped(_ flipped: Bool) {
        if flipped != isFlipped {
            flipAllFrames()
        }
    }

    public func flipAllFrames() {
        if flippedFramesCache == nil {
            flippedFramesCache = frames.map { flippedHorizontally($0) }
        }
        isFlipped.toggle()
    }

    private func flippedFrames() -> [NSImage] {
        flippedFramesCache ?? frames
    }

    private func flippedHorizontally(_ image: NSImage) -> NSImage {
        let flipped = NSImage(size: image.size)
        flipped.lockFocus()
        let transform = NSAffineTransform()
        transform.translateX(by: image.size.width, yBy: 0)
        transform.scaleX(by: -1, yBy: 1)
        transform.concat()
        image.draw(in: NSRect(origin: .zero, size: image.size))
        flipped.unlockFocus()
        return flipped
    }
}

public enum SpriteSheetError: Error, Sendable {
    case invalidBase64
    case invalidImage
}
