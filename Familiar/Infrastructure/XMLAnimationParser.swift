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
        processStartElement(path: path, elementName: elementName, attributes: attributes)
    }

    private func processStartElement(path: String, elementName: String, attributes: [String: String]) {
        let pathHandlers: [(String, ([String: String]) -> Void)] = [
            ("spawns/spawn", resetSpawnState),
            ("animations/animation", resetAnimationState),
            ("animation/sequence", resetSequenceState),
            ("childs/child", resetChildState),
        ]

        for (suffix, handler) in pathHandlers where path.hasSuffix(suffix) {
            handler(attributes)
            return
        }

        if elementName == "next" { resetNextState(attributes: attributes) }
    }

    private func resetSpawnState(attributes: [String: String]) {
        currentSpawnId = Int(attributes["id"] ?? "0") ?? 0
        currentSpawnProbability = Int(attributes["probability"] ?? "0") ?? 0
        currentSpawnX = ""
        currentSpawnY = ""
        currentSpawnNextAnims = []
    }

    private func resetAnimationState(attributes: [String: String]) {
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
    }

    private func resetSequenceState(attributes: [String: String]) {
        sequenceRepeat = attributes["repeat"] ?? "0"
        sequenceRepeatFrom = Int(attributes["repeatfrom"] ?? "0") ?? 0
    }

    private func resetNextState(attributes: [String: String]) {
        currentNextProbability = Int(attributes["probability"] ?? "0") ?? 0
        currentNextOnly = attributes["only"] ?? ""
    }

    private func resetChildState(attributes: [String: String]) {
        currentChildAnimId = Int(attributes["animationid"] ?? "0") ?? 0
        currentChildX = ""
        currentChildY = ""
        currentChildNext = 0
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

    private func processEndElement(path: String, text: String) {
        let handlers: [(String, (String) -> Void)] = [
            ("header/author", handleHeaderAuthor),
            ("header/title", handleHeaderTitle),
            ("header/petname", handleHeaderPetName),
            ("header/version", handleHeaderVersion),
            ("header/info", handleHeaderInfo),
            ("image/tilesx", handleImageTilesX),
            ("image/tilesy", handleImageTilesY),
            ("image/png", handleImagePNG),
            ("spawn/x", handleSpawnX),
            ("spawn/y", handleSpawnY),
            ("spawn/next", handleSpawnNext),
            ("spawns/spawn", handleSpawnEnd),
            ("animation/name", handleAnimationName),
            ("start/x", handleStartX),
            ("start/y", handleStartY),
            ("start/interval", handleStartInterval),
            ("start/offsety", handleStartOffsetY),
            ("start/opacity", handleStartOpacity),
            ("end/x", handleEndX),
            ("end/y", handleEndY),
            ("end/interval", handleEndInterval),
            ("end/offsety", handleEndOffsetY),
            ("end/opacity", handleEndOpacity),
            ("sequence/frame", handleSequenceFrame),
            ("sequence/action", handleSequenceAction),
            ("sequence/next", handleSequenceNext),
            ("border/next", handleBorderNext),
            ("gravity/next", handleGravityNext),
            ("animations/animation", handleAnimationEnd),
            ("child/x", handleChildX),
            ("child/y", handleChildY),
            ("child/next", handleChildNext),
            ("childs/child", handleChildEnd),
        ]

        for (suffix, handler) in handlers where path.hasSuffix(suffix) {
            handler(text)
            return
        }
    }

    // MARK: - Header handlers

    private func handleHeaderAuthor(_ text: String) { headerAuthor = text }
    private func handleHeaderTitle(_ text: String) { headerTitle = text }
    private func handleHeaderPetName(_ text: String) { headerPetName = text }
    private func handleHeaderVersion(_ text: String) { headerVersion = text }
    private func handleHeaderInfo(_ text: String) { headerInfo = text }

    // MARK: - Image handlers

    private func handleImageTilesX(_ text: String) { tilesX = Int(text) ?? 0 }
    private func handleImageTilesY(_ text: String) { tilesY = Int(text) ?? 0 }
    private func handleImagePNG(_ text: String) { base64PNG = text }

    // MARK: - Spawn handlers

    private func handleSpawnX(_ text: String) { currentSpawnX = text }
    private func handleSpawnY(_ text: String) { currentSpawnY = text }
    private func handleSpawnNext(_ text: String) { currentSpawnNextAnims.append(makeNextAnim(from: text)) }

    private func handleSpawnEnd(_: String) {
        let spawn = Spawn(
            id: currentSpawnId,
            probability: currentSpawnProbability,
            x: makeExpression(currentSpawnX),
            y: makeExpression(currentSpawnY),
            nextAnimations: currentSpawnNextAnims
        )
        spawns.append(spawn)
    }

    // MARK: - Animation name handler

    private func handleAnimationName(_ text: String) { currentAnimName = text }

    // MARK: - Start movement handlers

    private func handleStartX(_ text: String) { startX = text }
    private func handleStartY(_ text: String) { startY = text }
    private func handleStartInterval(_ text: String) { startInterval = text }
    private func handleStartOffsetY(_ text: String) { startOffsetY = Int(text) ?? 0 }
    private func handleStartOpacity(_ text: String) { startOpacity = Double(text) ?? 1.0 }

    // MARK: - End movement handlers

    private func handleEndX(_ text: String) { endX = text }
    private func handleEndY(_ text: String) { endY = text }
    private func handleEndInterval(_ text: String) { endInterval = text }
    private func handleEndOffsetY(_ text: String) { endOffsetY = Int(text) ?? 0 }
    private func handleEndOpacity(_ text: String) { endOpacity = Double(text) ?? 1.0 }

    // MARK: - Sequence handlers

    private func handleSequenceFrame(_ text: String) {
        if let frame = Int(text) { sequenceFrames.append(frame) }
    }

    private func handleSequenceAction(_ text: String) { sequenceAction = text }
    private func handleSequenceNext(_ text: String) { sequenceNextAnims.append(makeNextAnim(from: text)) }
    private func handleBorderNext(_ text: String) { borderNextAnims.append(makeNextAnim(from: text)) }
    private func handleGravityNext(_ text: String) { gravityNextAnims.append(makeNextAnim(from: text)) }

    // MARK: - Animation end handler

    private func handleAnimationEnd(_: String) {
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

    // MARK: - Child handlers

    private func handleChildX(_ text: String) { currentChildX = text }
    private func handleChildY(_ text: String) { currentChildY = text }
    private func handleChildNext(_ text: String) { currentChildNext = Int(text) ?? 0 }

    private func handleChildEnd(_: String) {
        let child = ChildDefinition(
            animationId: currentChildAnimId,
            x: makeExpression(currentChildX),
            y: makeExpression(currentChildY),
            nextAnimationId: currentChildNext
        )
        children.append(child)
    }

    private func makeNextAnim(from text: String) -> NextAnim {
        NextAnim(
            animationId: Int(text) ?? 0,
            probability: currentNextProbability,
            only: parseBorderType(currentNextOnly)
        )
    }

    private static let dynamicTokens = ["random", "randS", "imageX", "imageY"]
    private static let screenTokens = ["screenW", "screenH", "areaW", "areaH"]

    private func makeExpression(_ raw: String) -> FamiliarDomain.Expression {
        let isDynamic = Self.dynamicTokens.contains(where: raw.contains)
        let isScreenDependent = Self.screenTokens.contains(where: raw.contains)
        return FamiliarDomain.Expression(raw: raw, isDynamic: isDynamic, isScreenDependent: isScreenDependent)
    }

    private static let borderTypeMap: [String: BorderType] = [
        // Numeric format
        "1": .taskbar,
        "2": .window,
        "4": .horizontal,
        "6": .horizontalPlus,
        "8": .vertical,
        // String format (used by community pets)
        "none": .none,
        "taskbar": .taskbar,
        "window": .window,
        "horizontal": .horizontal,
        "horizontal+": .horizontalPlus,
        "vertical": .vertical,
    ]

    private func parseBorderType(_ value: String) -> BorderType {
        Self.borderTypeMap[value] ?? .none
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
