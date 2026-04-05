import Foundation
import Testing

@testable import FamiliarDomain
@testable import FamiliarInfrastructure

private let testXML = """
<?xml version="1.0" encoding="utf-8"?>
<animations xmlns="https://esheep.petrucci.ch/">
  <header>
    <author>Test Author</author>
    <title>Test Pet</title>
    <petname>TestSheep</petname>
    <version>1.0</version>
    <info>Test info</info>
    <application>1</application>
  </header>
  <image>
    <tilesx>2</tilesx>
    <tilesy>2</tilesy>
    <png><![CDATA[iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAYAAACp8Z5+AAAADklEQVQIW2P4z8BQDwAEgAF/QualcQ==]]></png>
  </image>
  <spawns>
    <spawn id="1" probability="100">
      <x>screenW/2</x>
      <y>screenH</y>
      <next probability="100">1</next>
    </spawn>
  </spawns>
  <animations>
    <animation id="1">
      <name>walk</name>
      <start>
        <x>3</x><y>0</y>
        <interval>100</interval>
        <offsety>0</offsety><opacity>1</opacity>
      </start>
      <end>
        <x>3</x><y>0</y>
        <interval>100</interval>
        <offsety>0</offsety><opacity>1</opacity>
      </end>
      <sequence repeat="10" repeatfrom="0">
        <frame>0</frame>
        <frame>1</frame>
        <frame>2</frame>
        <frame>3</frame>
        <next probability="100">2</next>
      </sequence>
      <border>
        <next probability="50" only="4">2</next>
        <next probability="50" only="2">1</next>
      </border>
      <gravity>
        <next probability="100">2</next>
      </gravity>
    </animation>
    <animation id="2">
      <name>fall</name>
      <start>
        <x>0</x><y>1</y>
        <interval>50</interval>
        <offsety>0</offsety><opacity>1</opacity>
      </start>
      <end>
        <x>0</x><y>10</y>
        <interval>50</interval>
        <offsety>0</offsety><opacity>1</opacity>
      </end>
      <sequence repeat="20" repeatfrom="0">
        <frame>0</frame>
        <frame>1</frame>
        <next probability="100">1</next>
      </sequence>
    </animation>
  </animations>
</animations>
"""

@Suite("XMLAnimationParser")
struct XMLAnimationParserTests {
    let parser = XMLAnimationParser()

    func parseTestXML() throws -> (PetAnimationData, String) {
        try parser.parse(Data(testXML.utf8))
    }

    @Test func parsesHeader() throws {
        let (data, _) = try parseTestXML()
        #expect(data.header.petName == "TestSheep")
        #expect(data.header.author == "Test Author")
        #expect(data.header.title == "Test Pet")
        #expect(data.header.version == "1.0")
        #expect(data.header.info == "Test info")
    }

    @Test func parsesSpriteInfo() throws {
        let (data, _) = try parseTestXML()
        #expect(data.spriteInfo.tilesX == 2)
        #expect(data.spriteInfo.tilesY == 2)
    }

    @Test func extractsBase64PNG() throws {
        let (_, base64) = try parseTestXML()
        #expect(!base64.isEmpty)
        #expect(base64.hasPrefix("iVBOR"))
    }

    @Test func parsesSpawns() throws {
        let (data, _) = try parseTestXML()
        #expect(data.spawns.count == 1)
        #expect(data.spawns[0].id == 1)
        #expect(data.spawns[0].probability == 100)
        #expect(data.spawns[0].x.raw == "screenW/2")
        #expect(data.spawns[0].x.isScreenDependent == true)
        #expect(data.spawns[0].nextAnimations.count == 1)
        #expect(data.spawns[0].nextAnimations[0].animationId == 1)
    }

    @Test func parsesAnimations() throws {
        let (data, _) = try parseTestXML()
        #expect(data.animations.count == 2)

        let walk = data.animations[1]!
        #expect(walk.name == "walk")
        #expect(walk.sequence.frames == [0, 1, 2, 3])
        #expect(walk.sequence.repeatFrom == 0)
        #expect(walk.endAnimation.count == 1)
        #expect(walk.endAnimation[0].animationId == 2)

        let fall = data.animations[2]!
        #expect(fall.name == "fall")
        #expect(fall.sequence.frames == [0, 1])
    }

    @Test func parsesMovementExpressions() throws {
        let (data, _) = try parseTestXML()
        let walk = data.animations[1]!
        #expect(walk.start.x.raw == "3")
        #expect(walk.start.opacity == 1.0)
        #expect(walk.end.y.raw == "0")
    }

    @Test func parsesBorderAndGravity() throws {
        let (data, _) = try parseTestXML()
        let walk = data.animations[1]!
        #expect(walk.endBorder.count == 2)
        #expect(walk.endBorder[0].only == .horizontal) // only="4"
        #expect(walk.endBorder[1].only == .window) // only="2"
        #expect(walk.endGravity.count == 1)
        #expect(walk.hasGravity == true)

        let fall = data.animations[2]!
        #expect(fall.endBorder.isEmpty)
        #expect(fall.endGravity.isEmpty)
    }

    @Test func invalidXMLThrows() {
        #expect(throws: XMLParseError.self) {
            _ = try parser.parse(Data("not xml at all".utf8))
        }
    }

    @Test func emptyDataThrows() {
        #expect(throws: XMLParseError.self) {
            _ = try parser.parse(Data())
        }
    }

    @Test func parsesChildElements() throws {
        let xmlWithChildren = """
        <?xml version="1.0" encoding="utf-8"?>
        <animations xmlns="https://esheep.petrucci.ch/">
          <header>
            <author>Test</author><title>Test</title>
            <petname>Test</petname><version>1</version>
            <info>Test</info><application>1</application>
          </header>
          <image>
            <tilesx>2</tilesx><tilesy>2</tilesy>
            <png><![CDATA[iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAYAAACp8Z5+AAAADklEQVQIW2P4z8BQDwAEgAF/QualcQ==]]></png>
          </image>
          <spawns>
            <spawn id="1" probability="100">
              <x>0</x><y>0</y>
              <next probability="100">1</next>
            </spawn>
          </spawns>
          <animations>
            <animation id="1">
              <name>walk</name>
              <start><x>0</x><y>0</y><interval>100</interval><offsety>0</offsety><opacity>1</opacity></start>
              <end><x>0</x><y>0</y><interval>100</interval><offsety>0</offsety><opacity>1</opacity></end>
              <sequence repeat="0" repeatfrom="0"><frame>0</frame><next probability="100">1</next></sequence>
            </animation>
          </animations>
          <childs>
            <child animationid="1">
              <x>imageX</x><y>imageY</y><next>2</next>
            </child>
          </childs>
        </animations>
        """
        let parser = XMLAnimationParser()
        let (data, _) = try parser.parse(Data(xmlWithChildren.utf8))
        #expect(data.children.count == 1)
        #expect(data.children[0].animationId == 1)
        #expect(data.children[0].x.raw == "imageX")
        #expect(data.children[0].y.raw == "imageY")
        #expect(data.children[0].nextAnimationId == 2)
    }

    @Test func parsesAnimationWithNoEndBorder() throws {
        let (data, _) = try parseTestXML()
        let fall = data.animations[2]!
        #expect(fall.endBorder.isEmpty)
    }

    @Test func parsesAnimationWithFlipAction() throws {
        let xmlWithFlip = """
        <?xml version="1.0" encoding="utf-8"?>
        <animations xmlns="https://esheep.petrucci.ch/">
          <header>
            <author>Test</author><title>Test</title>
            <petname>Test</petname><version>1</version>
            <info>Test</info><application>1</application>
          </header>
          <image>
            <tilesx>2</tilesx><tilesy>2</tilesy>
            <png><![CDATA[iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAYAAACp8Z5+AAAADklEQVQIW2P4z8BQDwAEgAF/QualcQ==]]></png>
          </image>
          <spawns>
            <spawn id="1" probability="100">
              <x>0</x><y>0</y>
              <next probability="100">1</next>
            </spawn>
          </spawns>
          <animations>
            <animation id="1">
              <name>flip_walk</name>
              <start><x>3</x><y>0</y><interval>100</interval><offsety>0</offsety><opacity>1</opacity></start>
              <end><x>3</x><y>0</y><interval>100</interval><offsety>0</offsety><opacity>1</opacity></end>
              <sequence repeat="0" repeatfrom="0">
                <frame>0</frame>
                <action>flip</action>
                <next probability="100">1</next>
              </sequence>
            </animation>
          </animations>
        </animations>
        """
        let parser = XMLAnimationParser()
        let (data, _) = try parser.parse(Data(xmlWithFlip.utf8))
        let anim = data.animations[1]!
        #expect(anim.sequence.action == "flip")
    }

    @Test func parsesMultipleSpawns() throws {
        let xmlMultiSpawn = """
        <?xml version="1.0" encoding="utf-8"?>
        <animations xmlns="https://esheep.petrucci.ch/">
          <header>
            <author>Test</author><title>Test</title>
            <petname>Test</petname><version>1</version>
            <info>Test</info><application>1</application>
          </header>
          <image>
            <tilesx>2</tilesx><tilesy>2</tilesy>
            <png><![CDATA[iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAYAAACp8Z5+AAAADklEQVQIW2P4z8BQDwAEgAF/QualcQ==]]></png>
          </image>
          <spawns>
            <spawn id="1" probability="60">
              <x>0</x><y>0</y>
              <next probability="100">1</next>
            </spawn>
            <spawn id="2" probability="40">
              <x>screenW</x><y>screenH</y>
              <next probability="100">1</next>
            </spawn>
          </spawns>
          <animations>
            <animation id="1">
              <name>walk</name>
              <start><x>0</x><y>0</y><interval>100</interval><offsety>0</offsety><opacity>1</opacity></start>
              <end><x>0</x><y>0</y><interval>100</interval><offsety>0</offsety><opacity>1</opacity></end>
              <sequence repeat="0" repeatfrom="0"><frame>0</frame><next probability="100">1</next></sequence>
            </animation>
          </animations>
        </animations>
        """
        let parser = XMLAnimationParser()
        let (data, _) = try parser.parse(Data(xmlMultiSpawn.utf8))
        #expect(data.spawns.count == 2)
        #expect(data.spawns[0].id == 1)
        #expect(data.spawns[0].probability == 60)
        #expect(data.spawns[1].id == 2)
        #expect(data.spawns[1].probability == 40)
    }

    @Test func parsesExpressionFlags() throws {
        let (data, _) = try parseTestXML()
        // "screenW/2" should be screen-dependent
        let spawn = data.spawns[0]
        #expect(spawn.x.raw == "screenW/2")
        #expect(spawn.x.isScreenDependent == true)
        #expect(spawn.x.isDynamic == false)

        // "screenH" should be screen-dependent
        #expect(spawn.y.raw == "screenH")
        #expect(spawn.y.isScreenDependent == true)

        // Constant "3" should have both false
        let walk = data.animations[1]!
        #expect(walk.start.x.raw == "3")
        #expect(walk.start.x.isScreenDependent == false)
        #expect(walk.start.x.isDynamic == false)
    }
}
