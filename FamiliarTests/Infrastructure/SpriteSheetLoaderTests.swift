import AppKit
import Testing

@testable import FamiliarInfrastructure

@Suite("SpriteSheetLoader")
struct SpriteSheetLoaderTests {
    // Create a tiny 4x4 pixel PNG encoded as base64 (exact pixel dimensions, no Retina scaling)
    static let tinyBase64PNG: String = {
        let width = 4
        let height = 4
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: width * 4,
            bitsPerPixel: 32
        )!
        // Fill quadrants with different colors
        for y in 0 ..< height {
            for x in 0 ..< width {
                let color: NSColor = if x < 2, y < 2 {
                    .red
                } else if x >= 2, y < 2 {
                    .green
                } else if x < 2, y >= 2 {
                    .blue
                } else {
                    .white
                }
                bitmap.setColor(color, atX: x, y: y)
            }
        }
        guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
            fatalError("Failed to create test PNG")
        }
        return pngData.base64EncodedString()
    }()

    @Test func slicesCorrectNumberOfFrames() throws {
        let loader = try SpriteSheetLoader(base64PNG: Self.tinyBase64PNG, tilesX: 2, tilesY: 2)
        #expect(loader.frameCount == 4)
    }

    @Test func frameDimensions() throws {
        let loader = try SpriteSheetLoader(base64PNG: Self.tinyBase64PNG, tilesX: 2, tilesY: 2)
        #expect(loader.frameWidth == 2)
        #expect(loader.frameHeight == 2)
    }

    @Test func flipTogglesState() throws {
        let loader = try SpriteSheetLoader(base64PNG: Self.tinyBase64PNG, tilesX: 2, tilesY: 2)
        #expect(!loader.isFlipped)
        loader.flipAllFrames()
        #expect(loader.isFlipped)
        loader.flipAllFrames()
        #expect(!loader.isFlipped)
    }

    @Test func imageAtValidIndex() throws {
        let loader = try SpriteSheetLoader(base64PNG: Self.tinyBase64PNG, tilesX: 2, tilesY: 2)
        let img = loader.image(at: 0)
        // Image pixel dimensions match tile size (NSImage.size may differ due to screen scale)
        guard let cgImage = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            Issue.record("Failed to get CGImage from frame")
            return
        }
        #expect(cgImage.width == 2)
        #expect(cgImage.height == 2)
    }

    @Test func imageAtOutOfBoundsClamps() throws {
        let loader = try SpriteSheetLoader(base64PNG: Self.tinyBase64PNG, tilesX: 2, tilesY: 2)
        let img = loader.image(at: 100)
        guard let cgImage = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            Issue.record("Failed to get CGImage from frame")
            return
        }
        #expect(cgImage.width == 2)
    }

    @Test func invalidBase64Throws() {
        #expect(throws: SpriteSheetError.self) {
            _ = try SpriteSheetLoader(base64PNG: "!!!not-base64!!!", tilesX: 2, tilesY: 2)
        }
    }

    @Test func singleTile() throws {
        let loader = try SpriteSheetLoader(base64PNG: Self.tinyBase64PNG, tilesX: 1, tilesY: 1)
        #expect(loader.frameCount == 1)
        #expect(loader.frameWidth == 4)
        #expect(loader.frameHeight == 4)
    }
}
