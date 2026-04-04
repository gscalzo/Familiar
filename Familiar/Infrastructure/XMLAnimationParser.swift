import FamiliarDomain
import Foundation

public enum XMLParseError: Error, Sendable {
    case invalidFormat(String)
    case missingElement(String)
}

// swiftlint:disable type_body_length

public final class XMLAnimationParser: NSObject, @unchecked Sendable, XMLParserDelegate {
    // MARK: - Collected state

    private var elementPath: [String] = []
    private var currentText = ""

    // Header fields
    private var headerAuthor = ""
    private var headerTitle = ""
    private var headerPetName = ""
    private var headerVersion = ""
    private var headerInfo = ""

    // Image fields
    private var tilesX = 0
    private var tilesY = 0
    private var base64PNG = ""

    // Spawns
    private var spawns: [Spawn] = []
    private var currentSpawnId = 0
    private var currentSpawnProbability = 0
    private var currentSpawnX = ""
    private var currentSpawnY = ""
    private var currentSpawnNextAnims: [NextAnim] = []

    // Animations
    private var animations: [Int: Animation] = [:]
    private var currentAnimId = 0
    private var currentAnimName = ""

    // Movement fields (start/end)
    private var startX = ""
    private var startY = ""
    private var startInterval = ""
    private var startOffsetY = 0
    private var startOpacity = 1.0
    private var endX = ""
    private var endY = ""
    private var endInterval = ""
    private var endOffsetY = 0
    private var endOpacity = 1.0

    // Sequence fields
    private var sequenceRepeat = ""
    private var sequenceRepeatFrom = 0
    private var sequenceFrames: [Int] = []
    private var sequenceAction: String?
    private var sequenceNextAnims: [NextAnim] = []

    // Border / Gravity
    private var borderNextAnims: [NextAnim] = []
    private var gravityNextAnims: [NextAnim] = []

    // Next element attributes (temporarily stored)
    private var currentNextProbability = 0
    private var currentNextOnly = ""

    // Children
    private var children: [ChildDefinition] = []
    private var currentChildAnimId = 0
    private var currentChildX = ""
    private var currentChildY = ""
    private var currentChildNext = 0

    // Error tracking
    private var parseError: Error?

    // MARK: - Public API

    override public init() {
        super.init()
    }

    public func parse(_ data: Data) throws -> (PetAnimationData, String) {
        resetState()

        guard !data.isEmpty else {
            throw XMLParseError.invalidFormat("Empty data")
        }

        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = self
        xmlParser.shouldProcessNamespaces = false

        let success = xmlParser.parse()

        if let error = parseError {
            throw error
        }

        guard success else {
            let errorDesc = xmlParser.parserError?.localizedDescription ?? "Unknown error"
            throw XMLParseError.invalidFormat(errorDesc)
        }

        let header = PetHeader(
            author: headerAuthor,
            title: headerTitle,
            petName: headerPetName,
            version: headerVersion,
            info: headerInfo
        )

        let spriteInfo = SpriteSheetInfo(tilesX: tilesX, tilesY: tilesY)

        let petData = PetAnimationData(
            header: header,
            spriteInfo: spriteInfo,
            spawns: spawns,
            animations: animations,
            children: children
        )

        return (petData, base64PNG)
    }

    // MARK: - XMLParserDelegate

    public func parser(
        _: XMLParser,
        didStartElement elementName: String,
        namespaceURI _: String?,
        qualifiedName _: String?,
        attributes: [String: String]
    ) {
        elementPath.append(elementName)
        currentText = ""

        let path = elementPath.joined(separator: "/")

        if path.hasSuffix("spawns/spawn") {
            currentSpawnId = Int(attributes["id"] ?? "0") ?? 0
            currentSpawnProbability = Int(attributes["probability"] ?? "0") ?? 0
            currentSpawnX = ""
            currentSpawnY = ""
            currentSpawnNextAnims = []
        } else if path.hasSuffix("animations/animation") {
            currentAnimId = Int(attributes["id"] ?? "0") ?? 0
            currentAnimName = ""
            startX = ""
            startY = ""
            startInterval = ""
            startOffsetY = 0
            startOpacity = 1.0
            endX = ""
            endY = ""
            endInterval = ""
            endOffsetY = 0
            endOpacity = 1.0
            sequenceRepeat = ""
            sequenceRepeatFrom = 0
            sequenceFrames = []
            sequenceAction = nil
            sequenceNextAnims = []
            borderNextAnims = []
            gravityNextAnims = []
        } else if path.hasSuffix("animation/sequence") {
            sequenceRepeat = attributes["repeat"] ?? "0"
            sequenceRepeatFrom = Int(attributes["repeatfrom"] ?? "0") ?? 0
        } else if elementName == "next" {
            currentNextProbability = Int(attributes["probability"] ?? "0") ?? 0
            currentNextOnly = attributes["only"] ?? ""
        } else if path.hasSuffix("childs/child") {
            currentChildAnimId = Int(attributes["animationid"] ?? "0") ?? 0
            currentChildX = ""
            currentChildY = ""
            currentChildNext = 0
        }
    }

    public func parser(_: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    public func parser(_: XMLParser, foundCDATA CDATABlock: Data) {
        if let str = String(data: CDATABlock, encoding: .utf8) {
            currentText += str
        }
    }

    public func parser(
        _: XMLParser,
        didEndElement _: String,
        namespaceURI _: String?,
        qualifiedName _: String?
    ) {
        let path = elementPath.joined(separator: "/")
        let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        processEndElement(path: path, text: text)

        elementPath.removeLast()
    }

    public func parser(_: XMLParser, parseErrorOccurred error: Error) {
        parseError = XMLParseError.invalidFormat(error.localizedDescription)
    }

    // MARK: - Private helpers

    // swiftlint:disable cyclomatic_complexity function_body_length
    private func processEndElement(path: String, text: String) {
        // Header fields
        if path.hasSuffix("header/author") {
            headerAuthor = text
        } else if path.hasSuffix("header/title") {
            headerTitle = text
        } else if path.hasSuffix("header/petname") {
            headerPetName = text
        } else if path.hasSuffix("header/version") {
            headerVersion = text
        } else if path.hasSuffix("header/info") {
            headerInfo = text
        }

        // Image fields
        else if path.hasSuffix("image/tilesx") {
            tilesX = Int(text) ?? 0
        } else if path.hasSuffix("image/tilesy") {
            tilesY = Int(text) ?? 0
        } else if path.hasSuffix("image/png") {
            base64PNG = text
        }

        // Spawn fields
        else if path.hasSuffix("spawn/x") {
            currentSpawnX = text
        } else if path.hasSuffix("spawn/y") {
            currentSpawnY = text
        } else if path.hasSuffix("spawn/next") {
            let animId = Int(text) ?? 0
            let nextAnim = NextAnim(
                animationId: animId,
                probability: currentNextProbability,
                only: parseBorderType(currentNextOnly)
            )
            currentSpawnNextAnims.append(nextAnim)
        } else if path.hasSuffix("spawns/spawn") {
            let spawn = Spawn(
                id: currentSpawnId,
                probability: currentSpawnProbability,
                x: makeExpression(currentSpawnX),
                y: makeExpression(currentSpawnY),
                nextAnimations: currentSpawnNextAnims
            )
            spawns.append(spawn)
        }

        // Animation fields
        else if path.hasSuffix("animation/name") {
            currentAnimName = text
        }

        // Start movement
        else if path.hasSuffix("start/x") {
            startX = text
        } else if path.hasSuffix("start/y") {
            startY = text
        } else if path.hasSuffix("start/interval") {
            startInterval = text
        } else if path.hasSuffix("start/offsety") {
            startOffsetY = Int(text) ?? 0
        } else if path.hasSuffix("start/opacity") {
            startOpacity = Double(text) ?? 1.0
        }

        // End movement
        else if path.hasSuffix("end/x") {
            endX = text
        } else if path.hasSuffix("end/y") {
            endY = text
        } else if path.hasSuffix("end/interval") {
            endInterval = text
        } else if path.hasSuffix("end/offsety") {
            endOffsetY = Int(text) ?? 0
        } else if path.hasSuffix("end/opacity") {
            endOpacity = Double(text) ?? 1.0
        }

        // Sequence fields
        else if path.hasSuffix("sequence/frame") {
            if let frame = Int(text) {
                sequenceFrames.append(frame)
            }
        } else if path.hasSuffix("sequence/action") {
            sequenceAction = text
        } else if path.hasSuffix("sequence/next") {
            let animId = Int(text) ?? 0
            let nextAnim = NextAnim(
                animationId: animId,
                probability: currentNextProbability,
                only: parseBorderType(currentNextOnly)
            )
            sequenceNextAnims.append(nextAnim)
        }

        // Border
        else if path.hasSuffix("border/next") {
            let animId = Int(text) ?? 0
            let nextAnim = NextAnim(
                animationId: animId,
                probability: currentNextProbability,
                only: parseBorderType(currentNextOnly)
            )
            borderNextAnims.append(nextAnim)
        }

        // Gravity
        else if path.hasSuffix("gravity/next") {
            let animId = Int(text) ?? 0
            let nextAnim = NextAnim(
                animationId: animId,
                probability: currentNextProbability,
                only: parseBorderType(currentNextOnly)
            )
            gravityNextAnims.append(nextAnim)
        }

        // End of animation element — build the Animation
        else if path.hasSuffix("animations/animation") {
            let startMovement = Movement(
                x: makeExpression(startX),
                y: makeExpression(startY),
                interval: makeExpression(startInterval),
                offsetY: startOffsetY,
                opacity: startOpacity
            )
            let endMovement = Movement(
                x: makeExpression(endX),
                y: makeExpression(endY),
                interval: makeExpression(endInterval),
                offsetY: endOffsetY,
                opacity: endOpacity
            )
            let sequence = AnimationSequence(
                frames: sequenceFrames,
                repeatCount: makeExpression(sequenceRepeat),
                repeatFrom: sequenceRepeatFrom,
                action: sequenceAction
            )
            let animation = Animation(
                id: currentAnimId,
                name: currentAnimName,
                start: startMovement,
                end: endMovement,
                sequence: sequence,
                endAnimation: sequenceNextAnims,
                endBorder: borderNextAnims,
                endGravity: gravityNextAnims
            )
            animations[currentAnimId] = animation
        }

        // Child fields
        else if path.hasSuffix("child/x") {
            currentChildX = text
        } else if path.hasSuffix("child/y") {
            currentChildY = text
        } else if path.hasSuffix("child/next") {
            currentChildNext = Int(text) ?? 0
        } else if path.hasSuffix("childs/child") {
            let child = ChildDefinition(
                animationId: currentChildAnimId,
                x: makeExpression(currentChildX),
                y: makeExpression(currentChildY),
                nextAnimationId: currentChildNext
            )
            children.append(child)
        }
    }

    // swiftlint:enable cyclomatic_complexity function_body_length

    private func makeExpression(_ raw: String) -> FamiliarDomain.Expression {
        let isDynamic = raw.contains("random") || raw.contains("randS")
            || raw.contains("imageX") || raw.contains("imageY")
        let isScreenDependent = raw.contains("screenW") || raw.contains("screenH")
            || raw.contains("areaW") || raw.contains("areaH")
        return FamiliarDomain.Expression(raw: raw, isDynamic: isDynamic, isScreenDependent: isScreenDependent)
    }

    private func parseBorderType(_ value: String) -> BorderType {
        switch value {
        case "", "0":
            return .none
        case "1":
            return .taskbar
        case "2":
            return .window
        case "4":
            return .horizontal
        case "6":
            return .horizontalPlus
        case "8":
            return .vertical
        default:
            return .none
        }
    }

    private func resetState() {
        elementPath = []
        currentText = ""
        headerAuthor = ""
        headerTitle = ""
        headerPetName = ""
        headerVersion = ""
        headerInfo = ""
        tilesX = 0
        tilesY = 0
        base64PNG = ""
        spawns = []
        animations = [:]
        children = []
        parseError = nil
    }
}

// swiftlint:enable type_body_length
