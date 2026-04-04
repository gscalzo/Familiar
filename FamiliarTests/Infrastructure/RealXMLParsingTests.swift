@testable import FamiliarDomain
@testable import FamiliarInfrastructure
import Foundation
import Testing

@Suite("Real eSheep XML Parsing")
struct RealXMLParsingTests {
    @Test func parsesRealSheepXML() throws {
        // Load the bundled animations.xml
        guard let url = findAnimationsXML() else {
            Issue.record("Could not find animations.xml")
            return
        }

        let data = try Data(contentsOf: url)
        let parser = XMLAnimationParser()
        let (petData, base64PNG) = try parser.parse(data)

        // Header
        #expect(petData.header.petName == "eSheep")
        #expect(petData.header.author == "Adriano")
        #expect(petData.header.version == "1.8")

        // Sprite info
        #expect(petData.spriteInfo.tilesX > 0)
        #expect(petData.spriteInfo.tilesY > 0)

        // Spawns
        #expect(!petData.spawns.isEmpty)

        // Animations — the real sheep has 54 animations
        #expect(petData.animations.count >= 50)

        // Check known animations exist
        let walk = petData.animations[1]
        #expect(walk?.name == "walk")

        let fall = petData.animations.values.first(where: { $0.name == "fall" })
        #expect(fall != nil)

        let drag = petData.animations.values.first(where: { $0.name == "drag" })
        #expect(drag != nil)

        let kill = petData.animations.values.first(where: { $0.name == "kill" })
        #expect(kill != nil)

        // Base64 PNG should be substantial
        #expect(base64PNG.count > 1000)
    }

    @Test func spriteSheetLoadsFromRealXML() throws {
        let url = findAnimationsXML()
        guard let url else {
            Issue.record("Could not find animations.xml")
            return
        }

        let data = try Data(contentsOf: url)
        let parser = XMLAnimationParser()
        let (petData, base64PNG) = try parser.parse(data)

        let spriteSheet = try SpriteSheetLoader(
            base64PNG: base64PNG,
            tilesX: petData.spriteInfo.tilesX,
            tilesY: petData.spriteInfo.tilesY
        )

        #expect(spriteSheet.frameCount == petData.spriteInfo.tilesX * petData.spriteInfo.tilesY)
        #expect(spriteSheet.frameWidth > 0)
        #expect(spriteSheet.frameHeight > 0)
    }

    private func findAnimationsXML() -> URL? {
        // Walk up from current file to find the project root
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0 ..< 5 {
            let candidate = dir.appendingPathComponent("Familiar/App/Resources/animations.xml")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
            dir = dir.deletingLastPathComponent()
        }
        return nil
    }
}
