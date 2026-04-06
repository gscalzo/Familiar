import AppKit
import FamiliarDomain
import FamiliarInfrastructure
import QuartzCore

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

    let stateFileWatcher: StateFileWatcher
    private(set) var animationConfig: AnimationConfig = .default
    private var knownMoods: [String: String] = [:]

    init(stateFileWatcher: StateFileWatcher = StateFileWatcher()) {
        self.stateFileWatcher = stateFileWatcher
    }

    // MARK: - Configuration

    func loadAnimationConfig() {
        animationConfig = stateFileWatcher.readAnimationConfig()
    }

    // MARK: - XML Loading

    func loadXML(from data: Data) throws {
        let parser = XMLAnimationParser()
        let (petData, base64PNG) = try parser.parse(data)
        loadedPetData = petData
        spriteSheetBase64 = base64PNG
    }

    func addPetOfType(named typeName: String) {
        guard let url = AppDelegate.findPetXML(named: typeName) else {
            NSLog("[Familiar] ERROR: XML not found for pet type: \(typeName)")
            return
        }
        guard let data = try? Data(contentsOf: url) else {
            NSLog("[Familiar] ERROR: Could not read XML at: \(url.path)")
            return
        }
        let parser = XMLAnimationParser()
        guard let (petData, base64PNG) = try? parser.parse(data) else {
            NSLog("[Familiar] ERROR: Failed to parse XML for: \(typeName)")
            return
        }
        guard let pet = makePetInstance(
            petData: petData, base64PNG: base64PNG, name: nil
        ) else {
            NSLog("[Familiar] ERROR: Failed to create pet instance for: \(typeName)")
            return
        }

        pet.petTypeName = petData.header.petName
        pet.stateMachine.respawn()
        pet.spriteSheet.setFlipped(!pet.stateMachine.isMovingLeft)
        placeOnScreenBottom(pet)
        showPet(pet)
        NSLog(
            "[Familiar] Pet panel at \(pet.position), frame=\(pet.panel.frame), visible=\(pet.panel.isVisible), frameCount=\(pet.spriteSheet.frameCount)"
        )
        NSLog("[Familiar] Added pet of type: \(typeName)")
    }

    // MARK: - Pet Lifecycle

    func addPet() {
        guard let pet = makePetInstance() else { return }

        pet.stateMachine.respawn()
        pet.spriteSheet.setFlipped(!pet.stateMachine.isMovingLeft)

        placeOnScreenBottom(pet)
        showPet(pet)
    }

    func removePet(id: UUID) {
        guard let pet = activePets.first(where: { $0.id == id }) else { return }
        startKillSequence(pet)
    }

    private func finishRemoval(_ pet: PetInstance) {
        guard let index = activePets.firstIndex(where: { $0.id == pet.id }) else { return }
        activePets.remove(at: index)
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

    // MARK: - State File Reconciliation

    private func reconcileFromStateFile() {
        let states = stateFileWatcher.readStates()
        let stateNames = Set(states.keys)
        let activePetNames = Set(activePets.compactMap(\.name))

        spawnMissingPets(stateNames: stateNames, activePetNames: activePetNames, states: states)
        killRemovedPets(stateNames: stateNames)
        updateMoodsAndEvents(states: states)
    }

    private func spawnMissingPets(
        stateNames: Set<String>,
        activePetNames: Set<String>,
        states: [String: PetState]
    ) {
        for name in stateNames where !activePetNames.contains(name) {
            spawnPet(named: name, mood: states[name]?.mood ?? "chill")
        }
    }

    private func killRemovedPets(stateNames: Set<String>) {
        for pet in activePets {
            guard let name = pet.name, !stateNames.contains(name) else { continue }
            removePetByName(name)
        }
    }

    private func updateMoodsAndEvents(states: [String: PetState]) {
        for pet in activePets {
            guard let name = pet.name, let state = states[name] else { continue }
            handlePendingEvent(pet: pet, name: name, state: state)
            handleMoodChange(pet: pet, name: name, mood: state.mood)
        }
    }

    private func handlePendingEvent(pet: PetInstance, name: String, state: PetState) {
        guard let event = state.event, let petData = loadedPetData else { return }
        if let eventAnimId = AnimationMapper.resolveEvent(
            event: event, config: animationConfig, animations: petData.animations
        ) {
            let moodAnimId = AnimationMapper.resolve(
                mood: state.mood, config: animationConfig, animations: petData.animations
            )
            pet.stateMachine.playEventAnimation(eventAnimId, returnToMood: moodAnimId ?? 0)
        }
        stateFileWatcher.clearEvent(forPet: name)
    }

    private func handleMoodChange(pet: PetInstance, name: String, mood: String) {
        guard knownMoods[name] != mood else { return }
        knownMoods[name] = mood
        if let petData = loadedPetData,
           let animId = AnimationMapper.resolve(
               mood: mood, config: animationConfig, animations: petData.animations
           )
        {
            pet.stateMachine.setMoodAnimation(animId)
        }
    }

    private func spawnPet(named name: String, mood: String) {
        guard let pet = makePetInstance(name: name) else { return }

        applyMoodOrRespawn(pet, mood: mood)
        pet.spriteSheet.setFlipped(!pet.stateMachine.isMovingLeft)
        knownMoods[name] = mood

        placeOnScreenBottom(pet)
        showPet(pet)
        NSLog("[Familiar] Spawned pet '\(name)' with mood '\(mood)'")
    }

    private func removePetByName(_ name: String) {
        guard let pet = activePets.first(where: { $0.name == name }) else { return }
        knownMoods.removeValue(forKey: name)
        startKillSequence(pet)
        NSLog("[Familiar] Killing pet '\(name)'")
    }

    private func startKillSequence(_ pet: PetInstance) {
        pet.isBeingKilled = true
        pet.killTickCount = 0
        pet.stateMachine.handleKill()
    }

    // MARK: - Pet Factory

    private func makePetInstance(name: String? = nil) -> PetInstance? {
        guard let petData = loadedPetData, let base64 = spriteSheetBase64 else { return nil }
        return makePetInstance(petData: petData, base64PNG: base64, name: name)
    }

    private func makePetInstance(
        petData: PetAnimationData, base64PNG: String, name: String?
    ) -> PetInstance? {
        guard activePets.count < maxPets else { return nil }

        guard let spriteSheet = try? SpriteSheetLoader(
            base64PNG: base64PNG,
            tilesX: petData.spriteInfo.tilesX,
            tilesY: petData.spriteInfo.tilesY
        ) else { return nil }

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
            spriteSheet: spriteSheet,
            name: name
        )

        stateMachine.delegate = pet
        panel.onRemove = { [weak self] in
            self?.removePet(id: pet.id)
        }
        environmentDetector.registerOwnPanel(panel.windowNumber)

        return pet
    }

    // MARK: - Pet Placement

    private func placeOnScreenBottom(_ pet: PetInstance) {
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        pet.position = CGPoint(
            x: screen.minX + CGFloat.random(in: 100 ... max(screen.width - 100, 200)),
            y: screen.minY
        )
        pet.panel.setFrameOrigin(pet.position)
    }

    private func showPet(_ pet: PetInstance) {
        activePets.append(pet)
        pet.panel.orderFront(nil)
        if sharedTimer == nil { startTimer() }
    }

    private func applyMoodOrRespawn(_ pet: PetInstance, mood: String) {
        if let petData = loadedPetData,
           let animId = AnimationMapper.resolve(
               mood: mood, config: animationConfig, animations: petData.animations
           )
        {
            pet.stateMachine.setMoodAnimation(animId)
        } else {
            pet.stateMachine.respawn()
        }
    }

    // MARK: - Timer

    func ensureTimerStarted() {
        if sharedTimer == nil { startTimer() }
    }

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

        reconcileFromStateFile()

        let now = CACurrentMediaTime()
        let petsToRemove = activePets.compactMap { tickSinglePet($0, now: now) }
        petsToRemove.forEach { finishRemoval($0) }

        updatePanelLevels()
    }

    /// Ticks a single pet. Returns the pet if it should be removed, nil otherwise.
    private func tickSinglePet(_ pet: PetInstance, now: CFTimeInterval) -> PetInstance? {
        guard isReadyForTick(pet, now: now) else { return nil }
        pet.lastTickTime = now
        guard !pet.stateMachine.isDragging else { return nil }

        pet.stateMachine.tick(currentSurface: pet.currentSurface)
        return processPostTick(pet)
    }

    private func processPostTick(_ pet: PetInstance) -> PetInstance? {
        if pet.isBeingKilled {
            return fadeOutKilledPet(pet) ? pet : nil
        }
        checkBounds(pet)
        return nil
    }

    private func isReadyForTick(_ pet: PetInstance, now: CFTimeInterval) -> Bool {
        let elapsedMs = (now - pet.lastTickTime) * 1000
        return elapsedMs >= Double(pet.currentInterval)
    }

    /// Returns true when the pet has fully faded out and should be removed.
    private func fadeOutKilledPet(_ pet: PetInstance) -> Bool {
        pet.killTickCount += 1
        let opacity = max(0, 1.0 - Double(pet.killTickCount) / 20.0)
        pet.panel.alphaValue = opacity
        return opacity <= 0
    }

    private func updatePanelLevels() {
        let level: NSWindow.Level = environmentDetector.isFullScreenActive() ? .normal : .statusBar
        activePets.forEach { $0.panel.level = level }
    }

    private func checkBounds(_ pet: PetInstance) {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return }

        let petSize = CGSize(
            width: CGFloat(pet.spriteSheet.frameWidth),
            height: CGFloat(pet.spriteSheet.frameHeight)
        )
        let totalBounds = screens.reduce(screens[0].frame) { $0.union($1.frame) }
        let visibleBottom = findVisibleBottom(for: pet, screens: screens, totalBounds: totalBounds)

        // If climbing a vertical wall, handle separately
        if isClimbingWall(pet) {
            handleVerticalWalk(pet, totalBounds: totalBounds, petSize: petSize)
            return
        }
        // If walking on top, handle separately
        if isWalkingOnTop(pet) {
            handleTopWalk(pet, totalBounds: totalBounds, petSize: petSize)
            return
        }

        snapToScreenBottom(pet, visibleBottom: visibleBottom)
        detectLanding(pet, visibleBottom: visibleBottom)
        clampToHorizontalEdges(pet, petWidth: petSize.width, totalBounds: totalBounds)
        clampAboveBottom(pet, visibleBottom: visibleBottom)
        respawnIfOffScreen(pet, petHeight: petSize.height, totalBounds: totalBounds)
    }

    private func isClimbingWall(_ pet: PetInstance) -> Bool {
        guard let surface = pet.currentSurface else { return false }
        let onWall = surface == .screenLeft || surface == .screenRight
        if onWall, !isVerticalWalkAnimation(pet) {
            // Animation no longer vertical — pet is leaving the wall
            pet.currentSurface = nil
            return false
        }
        return onWall
    }

    private func isWalkingOnTop(_ pet: PetInstance) -> Bool {
        guard pet.currentSurface == .screenTop else { return false }
        if !isOnTopAnimation(pet) {
            pet.currentSurface = nil
            return false
        }
        return true
    }

    private func isOnTopAnimation(_ pet: PetInstance) -> Bool {
        guard let anim = pet.stateMachine.currentAnimation else { return false }
        return anim.name.hasPrefix("top_walk")
    }

    private func handleVerticalWalk(_ pet: PetInstance, totalBounds: NSRect, petSize: CGSize) {
        // Lock X to the wall edge
        if pet.currentSurface == .screenLeft {
            pet.position.x = totalBounds.minX
        } else if pet.currentSurface == .screenRight {
            pet.position.x = totalBounds.maxX - petSize.width
        }

        // Check if hit screen top
        let visibleTop = NSScreen.main?.visibleFrame.maxY ?? totalBounds.maxY
        if pet.position.y + petSize.height >= visibleTop {
            pet.position.y = visibleTop - petSize.height
            pet.panel.setFrameOrigin(pet.position)
            pet.currentSurface = .screenTop
            pet.stateMachine.handleBorderHit(type: .horizontal)
            return
        }

        // Check if dropped back to bottom (could happen if anim ended)
        let visibleBottom = NSScreen.main?.visibleFrame.minY ?? totalBounds.minY
        if pet.position.y <= visibleBottom {
            pet.position.y = visibleBottom
            pet.currentSurface = .screenBottom
            pet.stateMachine.handleBorderHit(type: .taskbar)
        }

        pet.panel.setFrameOrigin(pet.position)
    }

    private func handleTopWalk(_ pet: PetInstance, totalBounds: NSRect, petSize: CGSize) {
        // Lock Y to the screen top
        let visibleTop = NSScreen.main?.visibleFrame.maxY ?? totalBounds.maxY
        pet.position.y = visibleTop - petSize.height

        // Check side collisions while on top
        if pet.position.x <= totalBounds.minX {
            pet.position.x = totalBounds.minX
            pet.currentSurface = .screenLeft
            pet.stateMachine.handleBorderHit(type: .vertical)
        } else if pet.position.x + petSize.width >= totalBounds.maxX {
            pet.position.x = totalBounds.maxX - petSize.width
            pet.currentSurface = .screenRight
            pet.stateMachine.handleBorderHit(type: .vertical)
        }

        pet.panel.setFrameOrigin(pet.position)
    }

    private func findVisibleBottom(
        for pet: PetInstance,
        screens: [NSScreen],
        totalBounds: NSRect
    ) -> CGFloat {
        let petW = CGFloat(pet.spriteSheet.frameWidth)
        let petH = CGFloat(pet.spriteSheet.frameHeight)
        let petCenter = CGPoint(x: pet.position.x + petW / 2, y: pet.position.y + petH / 2)
        let currentScreen = screens.first(where: { $0.frame.contains(petCenter) })
            ?? screens.min(by: { $0.frame.distance(to: petCenter) < $1.frame.distance(to: petCenter) })
        return currentScreen?.visibleFrame.minY ?? totalBounds.minY
    }

    private func snapToScreenBottom(_ pet: PetInstance, visibleBottom: CGFloat) {
        guard pet.currentSurface == .screenBottom else { return }
        pet.position.y = visibleBottom
        pet.panel.setFrameOrigin(pet.position)
    }

    private func detectLanding(_ pet: PetInstance, visibleBottom: CGFloat) {
        let wasInAir = pet.currentSurface == nil
        if pet.position.y <= visibleBottom + 5 {
            pet.currentSurface = .screenBottom
            pet.position.y = visibleBottom
            pet.panel.setFrameOrigin(pet.position)
            if wasInAir {
                pet.stateMachine.handleBorderHit(type: .taskbar)
            }
        } else {
            pet.currentSurface = nil
        }
    }

    private func clampToHorizontalEdges(_ pet: PetInstance, petWidth: CGFloat, totalBounds: NSRect) {
        guard let side = sideEdgeHit(pet, petWidth: petWidth, totalBounds: totalBounds) else { return }
        snapPetToWall(pet, side: side, petWidth: petWidth, totalBounds: totalBounds)
        pet.stateMachine.handleBorderHit(type: .vertical)
        if isVerticalWalkAnimation(pet) {
            pet.currentSurface = side
        }
    }

    private func sideEdgeHit(
        _ pet: PetInstance, petWidth: CGFloat, totalBounds: NSRect
    ) -> SurfaceType? {
        if pet.position.x <= totalBounds.minX, pet.stateMachine.isMovingLeft {
            return .screenLeft
        }
        if pet.position.x + petWidth >= totalBounds.maxX, !pet.stateMachine.isMovingLeft {
            return .screenRight
        }
        return nil
    }

    private func snapPetToWall(
        _ pet: PetInstance, side: SurfaceType, petWidth: CGFloat, totalBounds: NSRect
    ) {
        pet.position.x = side == .screenLeft ? totalBounds.minX : totalBounds.maxX - petWidth
        pet.panel.setFrameOrigin(pet.position)
    }

    private func isVerticalWalkAnimation(_ pet: PetInstance) -> Bool {
        guard let anim = pet.stateMachine.currentAnimation else { return false }
        // Vertical walk: y movement is non-zero, x is zero
        return anim.start.y.raw != "0" && anim.start.x.raw == "0"
    }

    private func clampAboveBottom(_ pet: PetInstance, visibleBottom: CGFloat) {
        guard pet.position.y < visibleBottom else { return }
        pet.position.y = visibleBottom
        pet.panel.setFrameOrigin(pet.position)
    }

    private func respawnIfOffScreen(_ pet: PetInstance, petHeight: CGFloat, totalBounds: NSRect) {
        let margin = petHeight * 3
        guard pet.position.y < totalBounds.minY - margin
            || pet.position.y > totalBounds.maxY + margin
        else { return }
        let screen = NSScreen.main?.visibleFrame ?? totalBounds
        pet.position = CGPoint(x: screen.midX, y: screen.minY)
        pet.panel.setFrameOrigin(pet.position)
        pet.stateMachine.respawn()
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

private extension NSRect {
    func distance(to point: CGPoint) -> CGFloat {
        let dx = max(minX - point.x, 0, point.x - maxX)
        let dy = max(minY - point.y, 0, point.y - maxY)
        return sqrt(dx * dx + dy * dy)
    }
}
