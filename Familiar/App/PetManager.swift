import AppKit
import FamiliarDomain
import FamiliarInfrastructure

@Observable
@MainActor
final class PetManager {
    var activePets: [PetInstance] = []
    var loadedPetData: PetAnimationData?
    var isPaused = false

    private var spriteSheetBase64: String?
    private var sharedTimer: DispatchSourceTimer?
    private let environmentDetector = EnvironmentDetector()
    private let maxPets = 16
    private let randS = Int.random(in: 10 ... 89)

    // MARK: - XML Loading

    func loadXML(from data: Data) throws {
        let parser = XMLAnimationParser()
        let (petData, base64PNG) = try parser.parse(data)
        loadedPetData = petData
        spriteSheetBase64 = base64PNG
    }

    // MARK: - Pet Lifecycle

    func addPet() {
        guard activePets.count < maxPets,
              let petData = loadedPetData,
              let base64 = spriteSheetBase64
        else { return }

        guard let spriteSheet = try? SpriteSheetLoader(
            base64PNG: base64,
            tilesX: petData.spriteInfo.tilesX,
            tilesY: petData.spriteInfo.tilesY
        ) else { return }

        let stateMachine = AnimationStateMachine(
            animations: petData.animations,
            spawns: petData.spawns,
            expressionContext: { [weak self] in
                self?.buildExpressionContext(spriteSheet: spriteSheet) ?? Self.defaultContext
            }
        )

        let panel = PetPanel(frameSize: NSSize(
            width: CGFloat(spriteSheet.frameWidth),
            height: CGFloat(spriteSheet.frameHeight)
        ))

        let pet = PetInstance(
            panel: panel,
            stateMachine: stateMachine,
            spriteSheet: spriteSheet
        )

        stateMachine.delegate = pet
        environmentDetector.registerOwnPanel(panel.windowNumber)

        stateMachine.respawn()

        // Place pet in center of screen for now (spawn logic TBD)
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        pet.position = CGPoint(x: screen.midX, y: screen.minY)
        panel.setFrameOrigin(pet.position)

        activePets.append(pet)
        panel.orderFront(nil)
        NSLog(
            "[Familiar] Panel at pos=\(pet.position), frame=\(panel.frame), spriteSize=\(spriteSheet.frameWidth)x\(spriteSheet.frameHeight), frameCount=\(spriteSheet.frameCount)"
        )

        if sharedTimer == nil { startTimer() }
    }

    func removePet(id: UUID) {
        guard let index = activePets.firstIndex(where: { $0.id == id }) else { return }
        let pet = activePets.remove(at: index)
        environmentDetector.unregisterOwnPanel(pet.panel.windowNumber)
        pet.panel.close()

        if activePets.isEmpty { stopTimer() }
    }

    func removeAll() {
        for pet in activePets {
            environmentDetector.unregisterOwnPanel(pet.panel.windowNumber)
            pet.panel.close()
        }
        activePets.removeAll()
        stopTimer()
    }

    func resetPositions() {
        for pet in activePets {
            pet.stateMachine.respawn()
            if let petData = loadedPetData, let spawn = petData.spawns.first {
                let ctx = buildExpressionContext(spriteSheet: pet.spriteSheet)
                let spawnX = spawn.x.evaluate(context: ctx)
                let spawnY = spawn.y.evaluate(context: ctx)
                pet.position = CGPoint(x: CGFloat(spawnX), y: CGFloat(spawnY))
                pet.panel.setFrameOrigin(pet.position)
            }
        }
    }

    func pause() { isPaused = true }
    func resume() { isPaused = false }
    func togglePause() { isPaused.toggle() }

    // MARK: - Timer

    private func startTimer() {
        sharedTimer = DispatchSource.makeTimerSource(queue: .main)
        sharedTimer?.schedule(deadline: .now(), repeating: .milliseconds(50))
        sharedTimer?.setEventHandler { [weak self] in
            self?.tickAllPets()
        }
        sharedTimer?.resume()
    }

    private func stopTimer() {
        sharedTimer?.cancel()
        sharedTimer = nil
    }

    private func tickAllPets() {
        guard !isPaused else { return }

        for pet in activePets {
            pet.stateMachine.tick(currentSurface: pet.currentSurface)
            checkBounds(pet)
        }

        if environmentDetector.isFullScreenActive() {
            activePets.forEach { $0.panel.level = .normal }
        } else {
            activePets.forEach { $0.panel.level = .statusBar }
        }
    }

    private func checkBounds(_ pet: PetInstance) {
        // Get the union of all screen frames
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return }

        let pos = pet.position
        let size = CGFloat(pet.spriteSheet.frameWidth)

        // Check if pet is completely off all screens (with margin)
        let margin: CGFloat = size * 2
        let isOffScreen = !screens.contains { screen in
            let f = screen.frame
            let expanded = NSRect(
                x: f.minX - margin, y: f.minY - margin,
                width: f.width + margin * 2, height: f.height + margin * 2
            )
            return expanded.contains(pos)
        }

        if isOffScreen {
            // Respawn at center of main screen
            let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
            pet.position = CGPoint(x: screen.midX, y: screen.minY)
            pet.panel.setFrameOrigin(pet.position)
            pet.stateMachine.respawn()
        }
    }

    private func buildExpressionContext(spriteSheet: SpriteSheetLoader) -> ExpressionContext {
        let screenFrame = environmentDetector.currentScreenFrame()
        let visibleFrame = environmentDetector.currentVisibleFrame()
        return ExpressionContext(
            screenW: Int(screenFrame.width),
            screenH: Int(screenFrame.height),
            areaW: Int(visibleFrame.width),
            areaH: Int(visibleFrame.height),
            imageW: spriteSheet.frameWidth,
            imageH: spriteSheet.frameHeight,
            imageX: 0, imageY: 0,
            random: Int.random(in: 0 ... 99),
            randS: randS,
            scale: Int(NSScreen.main?.backingScaleFactor ?? 2)
        )
    }

    static let defaultContext = ExpressionContext(
        screenW: 1920, screenH: 1080, areaW: 1920, areaH: 1055,
        imageW: 64, imageH: 64, imageX: 0, imageY: 0,
        random: 50, randS: 50, scale: 2
    )
}
