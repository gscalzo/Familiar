# Familiar for macOS - Design Document

**Date:** 2026-04-04
**Status:** Final Draft (post-review)

---

## 1. Overview

A macOS menubar-only app that recreates the classic eSheep desktop pet experience. The pet walks on screen edges and window title bars, falls with gravity, sleeps, runs, climbs walls, and responds to drag interactions. It parses the original eSheep XML animation format, enabling any community-created pet to be loaded.

### Key Decisions

| Decision | Choice |
|----------|--------|
| Character system | Pluggable (eSheep XML compatible) |
| Surface interaction | Full: screen edges + window title bars + climbing |
| Sprite assets | Parse base64 from XML directly |
| Sound | Silent first, add later |
| Multi-pet | Multiple pets (max 16), no children initially |
| macOS target | macOS 15 (Sequoia)+ |
| Menu bar | Enhanced: pet list, pause, options, custom XML loading |

---

## 2. Architecture

### Clean Architecture Layers

Dependencies flow inward only. The Domain layer has ZERO framework imports (no AppKit, no CoreGraphics). This enables testing the animation engine, state machine, and expression evaluator in isolation.

```
┌─────────────────────────────────────────────────────────┐
│                       App Layer                          │
│  (Composition Root: wires everything together)           │
│  FamiliarApp.swift, AppDelegate.swift, PetManager.swift│
├─────────────────────────────────────────────────────────┤
│                   Presentation Layer                     │
│  (UI: AppKit panels, SwiftUI menus, sprite rendering)    │
│  PetPanel, PetSpriteView, MenuBarView, OnboardingView   │
├─────────────────────────────────────────────────────────┤
│                  Infrastructure Layer                    │
│  (Framework adapters: XML parsing, image loading, OS)    │
│  XMLAnimationParser, SpriteSheetLoader, WindowDetector   │
├─────────────────────────────────────────────────────────┤
│                     Domain Layer                         │
│  (Pure logic: state machine, engine, models, protocols)  │
│  AnimationEngine, TransitionPicker, ExpressionEvaluator  │
│  Animation, Spawn, Movement, Sequence, NextAnim          │
│  WindowDetecting, SpriteProviding protocols              │
└─────────────────────────────────────────────────────────┘
```

### Component Diagram

```
┌─────────────────────────────────────────────────────────┐
│                    FamiliarApp                          │
│  MenuBarExtra + NSApplicationDelegateAdaptor              │
├─────────────────────────────────────────────────────────┤
│               PetManager (@Observable)                   │
│  - activePets: [PetInstance]                             │
│  - loadedPetData: PetAnimationData?                      │
│  - animationTimer: DispatchSourceTimer (single, shared)  │
│  - addPet() / removePet(id:) / removeAll()              │
│  - loadXML(from:) / pause() / resume()                  │
├─────────┬───────────────────────────┬───────────────────┤
│ PetInstance 1 │ PetInstance 2 │ PetInstance N            │
│  - panel      │  - panel      │  - panel                 │
│  - stateMach  │  - stateMach  │  - stateMach             │
│  - spriteView │  - spriteView │  - spriteView            │
└─────────┴───────────────────────────┴───────────────────┘
         │                    │
    ┌────┴────┐         ┌────┴────────────┐
    │ XML     │         │ Environment     │
    │ Parser  │         │ Detector        │
    └─────────┘         │ (screens +      │
                        │  windows)       │
                        └─────────────────┘
```

---

## 3. Domain Layer (Framework-Free)

### 3.1 Data Model

```swift
// MARK: - Top-level container
struct PetAnimationData {
    let header: PetHeader
    let spriteInfo: SpriteSheetInfo       // tilesX, tilesY (no images here)
    let spawns: [Spawn]
    let animations: [Int: Animation]      // id -> animation
    let children: [ChildDefinition]
}

struct PetHeader {
    let author: String
    let title: String
    let petName: String                   // max 16 chars
    let version: String
    let info: String                      // supports [br] and [link:url]
}

struct SpriteSheetInfo {
    let tilesX: Int
    let tilesY: Int
}

// MARK: - Animation
struct Animation {
    let id: Int
    let name: String
    let start: Movement
    let end: Movement
    let sequence: Sequence
    let endAnimation: [NextAnim]          // on sequence completion
    let endBorder: [NextAnim]             // on border hit
    let endGravity: [NextAnim]            // on gravity loss
    var hasGravity: Bool { !endGravity.isEmpty }
    var hasBorder: Bool { !endBorder.isEmpty }
}

struct Movement {
    let x: Expression
    let y: Expression
    let interval: Expression              // milliseconds
    let offsetY: Int
    let opacity: Double
}

struct Sequence {
    let frames: [Int]                     // sprite indices into sheet
    let repeatCount: Expression
    let repeatFrom: Int
    let action: String?                   // "flip" or nil

    func totalSteps(repeatValue: Int) -> Int {
        frames.count + (frames.count - repeatFrom) * repeatValue
    }

    func frameIndex(at step: Int) -> Int {
        if step < frames.count {
            return frames[step]
        }
        let cycleLength = frames.count - repeatFrom
        return frames[((step - frames.count + repeatFrom) % cycleLength) + repeatFrom]
    }
}

struct NextAnim {
    let animationId: Int
    let probability: Int
    let only: BorderType
}

// MARK: - Enums
struct BorderType: OptionSet {
    let rawValue: Int
    static let none       = BorderType(rawValue: 0x7F)
    static let taskbar    = BorderType(rawValue: 0x01)
    static let window     = BorderType(rawValue: 0x02)
    static let horizontal = BorderType(rawValue: 0x04)
    static let horizontalPlus = BorderType(rawValue: 0x06)
    static let vertical   = BorderType(rawValue: 0x08)
}

enum SurfaceType {
    case screenBottom     // "taskbar" equivalent
    case screenLeft
    case screenRight
    case screenTop
    case windowTop(windowID: Int)
}

struct WalkableSurface {
    let rect: CGRect
    let type: SurfaceType
}

// MARK: - Spawn
struct Spawn {
    let id: Int
    let probability: Int
    let x: Expression
    let y: Expression
    let nextAnimations: [NextAnim]
}

struct ChildDefinition {
    let animationId: Int
    let x: Expression
    let y: Expression
    let nextAnimationId: Int
}
```

### 3.2 Expression Evaluator

Custom recursive descent parser (not NSExpression). The eSheep expression language is simple: `+`, `-`, `*`, `/`, `(`, `)`, integer literals, and named variables.

```swift
struct Expression {
    let raw: String
    let isDynamic: Bool    // contains "random" or "randS" or "imageX"/"imageY"
    let isScreenDependent: Bool  // contains "screen" or "area"

    func evaluate(context: ExpressionContext) -> Int
}

struct ExpressionContext {
    let screenW: Int
    let screenH: Int
    let areaW: Int
    let areaH: Int
    let imageW: Int
    let imageH: Int
    let imageX: Int       // parent pet X (for children)
    let imageY: Int       // parent pet Y (for children)
    let random: Int       // 0-99, re-evaluated each call
    let randS: Int        // 10-89, fixed per session
    let scale: Int        // HiDPI scale factor
}
```

**Parser:** ~50 lines. Tokenize into numbers, identifiers, operators, parens. Recursive descent: `expr -> term ((+|-) term)*`, `term -> factor ((*|/) factor)*`, `factor -> NUMBER | IDENT | '(' expr ')'`.

### 3.3 Domain Protocols (Ports)

```swift
/// Abstraction for sprite image access (implemented by Infrastructure)
protocol SpriteProviding {
    var frameCount: Int { get }
    var frameWidth: Int { get }
    var frameHeight: Int { get }
    func flipAllFrames()
    var isFlipped: Bool { get }
}

/// Abstraction for window detection (implemented by Infrastructure)
protocol EnvironmentDetecting {
    func detectSurfaces() -> [WalkableSurface]
    func windowPosition(for windowID: Int) -> CGRect?
    func isFullScreenActive() -> Bool
    func currentScreenFrame() -> CGRect
    func currentVisibleFrame() -> CGRect
    func hasAdjacentScreen(at edge: ScreenEdge) -> Bool
}

enum ScreenEdge { case left, right, top, bottom }
```

### 3.4 Animation State Machine

Explicit protocol separating state logic from rendering:

```swift
protocol AnimationStateMachineDelegate: AnyObject {
    func stateMachine(_ sm: AnimationStateMachine, didChangeFrame index: Int)
    func stateMachine(_ sm: AnimationStateMachine, didMove dx: Int, dy: Int)
    func stateMachine(_ sm: AnimationStateMachine, didChangeOpacity opacity: Double)
    func stateMachine(_ sm: AnimationStateMachine, didChangeInterval ms: Int)
    func stateMachineDidRequestRespawn(_ sm: AnimationStateMachine)
    func stateMachineDidFlipSprites(_ sm: AnimationStateMachine)
}

class AnimationStateMachine {
    // Current state
    private(set) var currentAnimationID: Int
    private(set) var animationStep: Int = 0
    private(set) var isMovingLeft: Bool = false
    private(set) var isDragging: Bool = false
    private(set) var isLeavingScreen: Bool = false

    // Dependencies (injected)
    private let animations: [Int: Animation]
    private let spawns: [Spawn]
    private let expressionContext: () -> ExpressionContext
    weak var delegate: AnimationStateMachineDelegate?

    // Special animation IDs (resolved from names)
    private let fallAnimationID: Int?
    private let dragAnimationID: Int?
    private let killAnimationID: Int?

    // MARK: - Events

    /// Called every tick by the shared timer
    func tick(currentSurface: SurfaceType?, environmentDetector: EnvironmentDetecting) {
        // 1. Advance step
        // 2. Compute frame index
        // 3. Interpolate movement values (start -> end)
        // 4. Apply direction (negate x if !isMovingLeft)
        // 5. Check borders
        // 6. Check gravity
        // 7. Notify delegate of frame, movement, opacity, interval changes
        // 8. Check sequence end -> pick next animation
    }

    func handleBorderHit(type: BorderType, context: SurfaceContext) {
        // Pick from endBorder list, or start leaving screen
    }

    func handleGravityLost(context: SurfaceContext) {
        // Pick from endGravity list
    }

    func handleDragStart() {
        isDragging = true
        if let dragID = dragAnimationID {
            setAnimation(dragID)
        }
    }

    func handleDragEnd() {
        isDragging = false
        if let fallID = fallAnimationID {
            setAnimation(fallID)
        }
    }

    func handleKill() {
        if let killID = killAnimationID {
            setAnimation(killID)
        }
    }

    func respawn() {
        // Pick spawn by weighted probability
        // Evaluate spawn x, y expressions
        // Set initial animation from spawn's next list
    }
}
```

**Transition Picker** (separate, testable function):

```swift
struct TransitionPicker {
    /// Pick next animation from candidates filtered by context
    static func pick(
        from candidates: [NextAnim],
        context: BorderType
    ) -> Int? {
        let eligible = candidates.filter { $0.only.rawValue & context.rawValue != 0 }
        guard !eligible.isEmpty else { return nil }

        let totalProb = eligible.reduce(0) { $0 + $1.probability }
        guard totalProb > 0 else { return nil }

        var roll = Int.random(in: 1...totalProb)
        for candidate in eligible {
            roll -= candidate.probability
            if roll <= 0 { return candidate.animationId }
        }
        return eligible.last?.animationId
    }
}
```

**Interpolation** (matching original exactly):

```swift
struct Interpolator {
    /// Linear interpolation matching eSheep's formula
    static func value(start: Int, end: Int, step: Int, totalSteps: Int) -> Int {
        guard totalSteps > 0 else { return start }
        return start + (end - start) * step / totalSteps
    }

    /// Movement uses totalSteps-1 as denominator
    static func movement(start: Int, end: Int, step: Int, totalSteps: Int) -> Int {
        guard totalSteps > 1 else { return start }
        return start + (end - start) * step / (totalSteps - 1)
    }
}
```

---

## 4. Infrastructure Layer

### 4.1 XML Animation Parser

Uses Foundation's `XMLParser` with delegate pattern. Parses the exact eSheep XML format (namespace `https://esheep.petrucci.ch/`).

**Input:** XML file data (from bundle or user file picker)
**Output:** `PetAnimationData` (pure domain struct) + raw base64 PNG data

The parser does NOT decode images -- it returns the raw base64 string. Image decoding is handled by `SpriteSheetLoader` (keeps the parser framework-free except for Foundation).

### 4.2 Sprite Sheet Loader

```swift
class SpriteSheetLoader: SpriteProviding {
    private var frames: [NSImage] = []
    private var flippedFramesCache: [NSImage]?
    private(set) var isFlipped = false

    init(base64PNG: String, tilesX: Int, tilesY: Int) {
        // 1. Decode base64 -> Data
        // 2. Data -> NSImage -> CGImage
        // 3. Slice grid: row by row, left to right, top to bottom
        // 4. Store as [NSImage]
    }

    var frameCount: Int { frames.count }
    var frameWidth: Int { /* from first frame */ }
    var frameHeight: Int { /* from first frame */ }

    func image(at index: Int) -> NSImage { isFlipped ? flippedFrames[index] : frames[index] }

    func flipAllFrames() {
        if flippedFramesCache == nil {
            flippedFramesCache = frames.map { $0.flippedHorizontally() }
        }
        isFlipped.toggle()
    }
}
```

### 4.3 Environment Detector

Single class handling both screen edges and window detection (merged from original separate ScreenManager + SurfaceDetector + CoordinateConverter):

```swift
class EnvironmentDetector: EnvironmentDetecting {
    private var cachedSurfaces: [WalkableSurface] = []
    private var pollTimer: DispatchSourceTimer?

    /// Start polling window positions (500ms interval)
    func startPolling()
    func stopPolling()

    func detectSurfaces() -> [WalkableSurface] {
        var surfaces: [WalkableSurface] = []

        // Screen edges (always available, no permission needed)
        for screen in NSScreen.screens {
            let visible = screen.visibleFrame
            surfaces.append(.init(rect: bottomEdge(visible), type: .screenBottom))
            surfaces.append(.init(rect: leftEdge(visible), type: .screenLeft))
            surfaces.append(.init(rect: rightEdge(visible), type: .screenRight))
            surfaces.append(.init(rect: topEdge(visible), type: .screenTop))
        }

        // Window top edges (requires Screen Recording permission)
        if hasScreenRecordingPermission() {
            let windowList = CGWindowListCopyWindowInfo(
                [.optionOnScreenOnly, .excludeDesktopElements],
                kCGNullWindowID
            ) as? [[String: Any]] ?? []

            for window in windowList {
                // Filter: layer == 0, has bounds, not our own panels
                // Convert CG coords (top-left) to NS coords (bottom-left)
                // Return top edge as WalkableSurface
            }
        }

        cachedSurfaces = surfaces
        return surfaces
    }

    func windowPosition(for windowID: Int) -> CGRect? {
        // Fetch single window position for following
    }

    func isFullScreenActive() -> Bool {
        // Check if frontmost app covers entire screen
    }

    func hasAdjacentScreen(at edge: ScreenEdge) -> Bool {
        // Check if another screen abuts at edge
    }

    // MARK: - Coordinate Conversion (inlined)

    private func toNSCoords(_ cgRect: CGRect) -> CGRect {
        let screenH = NSScreen.screens.first { $0.frame.origin == .zero }?.frame.height ?? 0
        return CGRect(
            x: cgRect.origin.x,
            y: screenH - cgRect.origin.y - cgRect.height,
            width: cgRect.width,
            height: cgRect.height
        )
    }

    private func hasScreenRecordingPermission() -> Bool {
        // Attempt CGWindowListCopyWindowInfo and check if results have names
    }
}
```

---

## 5. Presentation Layer

### 5.1 Pet Panel

```swift
class PetPanel: NSPanel {
    let spriteView: NSImageView

    init(frameSize: NSSize) {
        super.init(
            contentRect: NSRect(origin: .zero, size: frameSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        isMovableByWindowBackground = false

        // Sprite image view (fills entire panel)
        spriteView = NSImageView(frame: NSRect(origin: .zero, size: frameSize))
        spriteView.imageScaling = .scaleNone
        contentView = spriteView

        // Mouse tracking for drag
        let trackingArea = NSTrackingArea(
            rect: NSRect(origin: .zero, size: frameSize),
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        contentView?.addTrackingArea(trackingArea)

        // Drag-and-drop for XML files
        registerForDraggedTypes([.fileURL])
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    // MARK: - Drag & Drop XML
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        // Check for .xml file
        return .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        // Load XML file, notify PetManager
    }

    // MARK: - Mouse Interaction
    // mouseDown -> start drag, notify state machine
    // mouseDragged -> track cursor position
    // mouseUp -> end drag, notify state machine

    // MARK: - Context Menu (right-click)
    override func rightMouseDown(with event: NSEvent) {
        let menu = NSMenu()
        menu.addItem(withTitle: "Remove This Pet", action: #selector(removePet), keyEquivalent: "")
        menu.addItem(withTitle: "Reset Position", action: #selector(resetPosition), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "About", action: #selector(showAbout), keyEquivalent: "")
        NSMenu.popUpContextMenu(menu, with: event, for: contentView!)
    }
}
```

**Rendering pipeline:**
- Each tick, state machine delegate calls `didChangeFrame(index:)` -> `spriteView.image = spriteSheet.image(at: index)`
- State machine delegate calls `didMove(dx:, dy:)` -> `panel.setFrameOrigin(newPosition)`
- State machine delegate calls `didChangeOpacity(opacity:)` -> `panel.alphaValue = opacity`

**Click-through toggling:**
- Default: `ignoresMouseEvents = true` (clicks pass through)
- On `mouseEntered`: `ignoresMouseEvents = false`, cursor = openHand
- On `mouseExited`: `ignoresMouseEvents = true`, cursor = arrow
- During drag: `ignoresMouseEvents = false`, cursor = closedHand

**Leaving screen effect:**
- Crop the NSImage to visible portion
- Shrink panel size to match
- When fully offscreen: request respawn

### 5.2 Pet Instance

One pet = one panel + one state machine + one sprite sheet reference. Conforms to `AnimationStateMachineDelegate`.

```swift
class PetInstance: AnimationStateMachineDelegate, Identifiable {
    let id = UUID()
    let panel: PetPanel
    let stateMachine: AnimationStateMachine
    let spriteSheet: SpriteSheetLoader

    var position: CGPoint
    var currentSurface: SurfaceType?
    var currentWindowID: Int?

    // MARK: - AnimationStateMachineDelegate

    func stateMachine(_ sm: AnimationStateMachine, didChangeFrame index: Int) {
        panel.spriteView.image = spriteSheet.image(at: index)
    }

    func stateMachine(_ sm: AnimationStateMachine, didMove dx: Int, dy: Int) {
        position.x += CGFloat(dx)
        position.y -= CGFloat(dy) // NS coords: y increases upward
        panel.setFrameOrigin(position)
    }

    func stateMachine(_ sm: AnimationStateMachine, didChangeOpacity opacity: Double) {
        panel.alphaValue = CGFloat(opacity)
    }

    func stateMachine(_ sm: AnimationStateMachine, didChangeInterval ms: Int) {
        // PetManager reads this when scheduling next tick
    }

    func stateMachineDidRequestRespawn(_ sm: AnimationStateMachine) {
        // Re-evaluate spawn expressions, reposition panel
    }

    func stateMachineDidFlipSprites(_ sm: AnimationStateMachine) {
        spriteSheet.flipAllFrames()
    }
}
```

---

## 6. App Layer

### 6.1 PetManager

```swift
@Observable
final class PetManager {
    var activePets: [PetInstance] = []
    var loadedPetData: PetAnimationData?
    var isPaused = false
    var multiScreenEnabled = true
    var windowWalkingEnabled = true

    private var spriteSheetBase64: String?
    private var sharedTimer: DispatchSourceTimer?
    private let environmentDetector = EnvironmentDetector()
    private let maxPets = 16

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
              let base64 = spriteSheetBase64 else { return }

        let spriteSheet = SpriteSheetLoader(
            base64PNG: base64,
            tilesX: petData.spriteInfo.tilesX,
            tilesY: petData.spriteInfo.tilesY
        )

        let stateMachine = AnimationStateMachine(
            animations: petData.animations,
            spawns: petData.spawns,
            expressionContext: { [weak self] in self?.buildExpressionContext(spriteSheet) ?? .default }
        )

        let panel = PetPanel(frameSize: NSSize(
            width: spriteSheet.frameWidth,
            height: spriteSheet.frameHeight
        ))

        let pet = PetInstance(
            panel: panel,
            stateMachine: stateMachine,
            spriteSheet: spriteSheet
        )

        stateMachine.delegate = pet
        stateMachine.respawn()
        activePets.append(pet)
        panel.orderFront(nil)

        if sharedTimer == nil { startTimer() }
    }

    func removePet(id: UUID) {
        guard let index = activePets.firstIndex(where: { $0.id == id }) else { return }
        let pet = activePets[index]
        pet.stateMachine.handleKill()
        // After kill animation completes (opacity -> 0): panel.close(), remove from array
    }

    func removeAll() {
        for pet in activePets {
            pet.panel.close()
        }
        activePets.removeAll()
        stopTimer()
    }

    // MARK: - Shared Timer (single timer drives all pets)

    private func startTimer() {
        environmentDetector.startPolling()

        sharedTimer = DispatchSource.makeTimerSource(queue: .main)
        sharedTimer?.schedule(deadline: .now(), repeating: .milliseconds(50))
        sharedTimer?.setEventHandler { [weak self] in
            self?.tickAllPets()
        }
        sharedTimer?.resume()
    }

    private func tickAllPets() {
        guard !isPaused else { return }
        let surfaces = windowWalkingEnabled
            ? environmentDetector.detectSurfaces()
            : environmentDetector.detectScreenEdgesOnly()

        for pet in activePets {
            // Check per-pet interval (skip if not enough time elapsed)
            pet.stateMachine.tick(
                currentSurface: pet.currentSurface,
                environmentDetector: environmentDetector
            )
        }

        // Full-screen detection
        if environmentDetector.isFullScreenActive() {
            activePets.forEach { $0.panel.level = .normal }
        } else {
            activePets.forEach { $0.panel.level = .statusBar }
        }
    }

    func pause() {
        isPaused = true
    }

    func resume() {
        isPaused = false
    }
}
```

### 6.2 App Entry Point

```swift
@main
struct FamiliarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var petManager = PetManager()

    var body: some Scene {
        MenuBarExtra("Familiar", systemImage: "pawprint.fill") {
            MenuBarView()
                .environment(petManager)
        }
        .menuBarExtraStyle(.window)

        Settings {
            OptionsView()
                .environment(petManager)
        }
    }
}
```

### 6.3 AppDelegate

```swift
class AppDelegate: NSObject, NSApplicationDelegate {
    var petManager: PetManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // CRITICAL: All initialization here, NOT in SwiftUI onAppear

        // 1. Prevent app nap (keeps timers accurate)
        ProcessInfo.processInfo.beginActivity(
            .userInitiated,
            reason: "Desktop pet animation"
        )

        // 2. Check for onboarding (Screen Recording permission)
        if !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
            if !CGPreflightScreenCaptureAccess() {
                showOnboardingWindow()
                return
            }
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        }

        // 3. Load bundled XML and spawn initial pet
        loadDefaultPetAndSpawn()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false // CRITICAL: menu bar app must stay alive when panels close
    }

    // MARK: - Onboarding

    private func showOnboardingWindow() {
        // Must use NSWindow directly (not SwiftUI Window scene)
        // because LSUIElement apps can't reliably open SwiftUI scenes at launch
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 350),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.title = "Familiar Setup"
        window.contentView = NSHostingView(rootView: OnboardingView(onComplete: { [weak self] in
            window.close()
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            self?.loadDefaultPetAndSpawn()
        }))
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func loadDefaultPetAndSpawn() {
        guard let petManager = petManager else { return }
        if let xmlURL = Bundle.main.url(forResource: "animations", withExtension: "xml"),
           let data = try? Data(contentsOf: xmlURL) {
            try? petManager.loadXML(from: data)
            petManager.addPet()
        }
    }
}
```

---

## 7. Menu Bar UI

### 7.1 Menu Structure

```
┌─────────────────────────────┐
│  Familiar                │  <- pet name from XML header
├─────────────────────────────┤
│  Add Pet              ⌘N    │
│  Load Custom Pet...   ⌘O    │
├─────────────────────────────┤
│  Active Pets (3)            │  <- section header
│    Sheep #1          [✕]    │
│    Sheep #2          [✕]    │
│    Sheep #3          [✕]    │
├─────────────────────────────┤
│  ⏸ Pause All          ⌘P   │
│  📍 Reset Positions   ⌘R   │
├─────────────────────────────┤
│  Options                ▶   │
│    │ Multi-Screen      [✓]  │
│    │ Window Walking    [✓]  │
│    │ Launch at Login   [ ]  │
├─────────────────────────────┤
│  About                      │
│  Quit               ⌘Q     │
└─────────────────────────────┘
```

### 7.2 Implementation Notes

- `MenuBarExtra` with `.menuBarExtraStyle(.window)` for the rich layout
- Keyboard shortcuts only work when menu is open (LSUIElement limitation)
- **"Load Custom Pet"**: `NSOpenPanel` filtering for `.xml`. Validates before loading.
  Must call `NSApp.activate(ignoringOtherApps: true)` before showing panel.
- **"About"**: Shows XML header info in a dialog.
  Must call `NSApp.activate(ignoringOtherApps: true)` to avoid opening behind other apps.
- **Per-pet remove**: Plays `kill` animation (fade out), then removes.
- **Pause/Resume**: Toggles `petManager.isPaused`. Menu text toggles.
- **Launch at Login**: Uses `SMAppService.mainApp.register()` (macOS 13+).

### 7.3 Settings Persistence

```swift
@Observable
final class AppSettings {
    @AppStorage("multiScreenEnabled") var multiScreenEnabled = true
    @AppStorage("windowWalkingEnabled") var windowWalkingEnabled = true
    @AppStorage("launchAtLogin") var launchAtLogin = false
    @AppStorage("lastLoadedXMLPath") var lastLoadedXMLPath: String?
    @AppStorage("petCount") var petCount = 1
}
```

---

## 8. Multi-Screen Support

macOS uses a unified coordinate space across all screens. Pet movement naturally spans monitors.

```
┌──────────────┐ ┌──────────────┐
│  Screen 1    │ │  Screen 2    │
│              │ │              │
│         🐑 ──┼─┼─> 🐑        │
│              │ │              │
│  (0,0)───────┤ │(1920,0)─────│
└──────────────┘ └──────────────┘
```

**Behaviors:**
- Walking off screen boundary: if adjacent screen exists, pet continues; if not, border triggers.
- Spawn: random screen selection from `NSScreen.screens`.
- Expression variables (`screenW`, etc.) evaluate against the chosen screen.
- Border detection uses current screen's `visibleFrame` (respects Dock, menu bar, notch).
- `CGWindowListCopyWindowInfo` returns unified coordinates -- window detection works across screens.
- When multi-screen disabled: clamp to spawn screen.

**Adjacent screen detection:**
```swift
func hasAdjacentScreen(at edge: ScreenEdge) -> Bool {
    NSScreen.screens.contains { other in
        other !== currentScreen && edgesAdjacent(currentScreen, other, edge)
    }
}
```

**Display change notification:**
- Listen to `NSApplication.didChangeScreenParametersNotification`
- Re-evaluate which screen each pet is on
- If pet's screen removed: respawn on remaining screen

---

## 9. Edge Cases & Graceful Degradation

### Screen Recording Permission

- **Granted:** Full window detection, pet walks on title bars.
- **Denied:** Screen-edges-only mode. One-time hint in menu: "Enable Screen Recording in System Settings for window walking."
- **Detection:** Call `CGWindowListCopyWindowInfo` and check if returned windows have valid bounds/names. If not, permission is denied.

### Full-Screen Apps

- Detect via frontmost window covering entire screen bounds
- When detected: `panel.level = .normal` (hide behind full-screen)
- When exited: restore `panel.level = .statusBar`

### Pet Off-Screen

- Leaving animation: progressively crop sprite image, shrink panel
- When fully exited: respawn using XML spawn definitions

### Invalid XML

- Parser validates structure before loading
- On failure: show alert via `NSAlert`, keep current pet
- If base64 decode fails: reject XML, alert user

### Display Configuration Changes

- `NSApplication.didChangeScreenParametersNotification`
- Re-evaluate pet positions, respawn if screen removed

### Window Resize (Pet On Window)

- Window following: detect width change, scale pet X proportionally
- If pet falls off shrunk window edge: trigger gravity

### App Nap Prevention

```swift
ProcessInfo.processInfo.beginActivity(.userInitiated, reason: "Desktop pet animation")
```

---

## 10. File Structure

```
Familiar/
├── Familiar.xcodeproj
├── Familiar/
│   ├── App/
│   │   ├── FamiliarApp.swift
│   │   ├── AppDelegate.swift
│   │   ├── PetManager.swift
│   │   ├── AppSettings.swift
│   │   └── Info.plist                   # LSUIElement = YES
│   │
│   ├── Domain/
│   │   ├── Model/
│   │   │   ├── PetAnimationData.swift
│   │   │   ├── Animation.swift
│   │   │   ├── Movement.swift
│   │   │   ├── Sequence.swift
│   │   │   ├── NextAnim.swift
│   │   │   ├── BorderType.swift
│   │   │   ├── Spawn.swift
│   │   │   ├── ChildDefinition.swift
│   │   │   └── WalkableSurface.swift
│   │   ├── Engine/
│   │   │   ├── AnimationStateMachine.swift
│   │   │   ├── TransitionPicker.swift
│   │   │   ├── Interpolator.swift
│   │   │   └── ExpressionEvaluator.swift
│   │   └── Protocols/
│   │       ├── SpriteProviding.swift
│   │       └── EnvironmentDetecting.swift
│   │
│   ├── Infrastructure/
│   │   ├── XMLAnimationParser.swift
│   │   ├── SpriteSheetLoader.swift
│   │   └── EnvironmentDetector.swift
│   │
│   ├── Presentation/
│   │   ├── Pet/
│   │   │   ├── PetPanel.swift
│   │   │   └── PetInstance.swift
│   │   ├── Menu/
│   │   │   ├── MenuBarView.swift
│   │   │   ├── AboutView.swift
│   │   │   └── OptionsView.swift
│   │   └── Onboarding/
│   │       └── OnboardingView.swift
│   │
│   └── Resources/
│       └── animations.xml               # Bundled default sheep
│
├── FamiliarTests/
│   ├── Domain/
│   │   ├── AnimationStateMachineTests.swift
│   │   ├── TransitionPickerTests.swift
│   │   ├── InterpolatorTests.swift
│   │   └── ExpressionEvaluatorTests.swift
│   └── Infrastructure/
│       └── XMLAnimationParserTests.swift
│
├── docs/
│   ├── research.md
│   └── plans/
│       └── 2026-04-04-desktop-pet-design.md
│
└── README.md
```

**No external dependencies.** Foundation, AppKit, CoreGraphics, SwiftUI only.

---

## 11. eSheep XML Format Reference

### Complete Schema

```xml
<animations xmlns="https://esheep.petrucci.ch/">
  <header>
    <author>string</author>
    <title>string</title>
    <petname>string (max 16 chars)</petname>
    <version>string</version>
    <info>string (supports [br] and [link:url])</info>
    <application>1</application>
    <icon>base64 ICO in CDATA</icon>
  </header>
  <image>
    <tilesx>int</tilesx>
    <tilesy>int</tilesy>
    <png>base64 PNG in CDATA</png>
    <transparency>color name</transparency>
  </image>
  <spawns>
    <spawn id="int" probability="int">
      <x>expression</x>
      <y>expression</y>
      <next probability="int">animation_id</next>
    </spawn>
  </spawns>
  <animations>
    <animation id="int">
      <name>string</name>
      <start>
        <x>expression</x> <y>expression</y>
        <interval>expression (ms)</interval>
        <offsety>int</offsety> <opacity>double</opacity>
      </start>
      <end>
        <x>expression</x> <y>expression</y>
        <interval>expression (ms)</interval>
        <offsety>int</offsety> <opacity>double</opacity>
      </end>
      <sequence repeat="expression" repeatfrom="int">
        <frame>int</frame>
        <action>string ("flip")</action>
        <next probability="int" only="borderType">animation_id</next>
      </sequence>
      <border>
        <next probability="int" only="borderType">animation_id</next>
      </border>
      <gravity>
        <next probability="int" only="borderType">animation_id</next>
      </gravity>
    </animation>
  </animations>
  <childs>
    <child animationid="int">
      <x>expression</x> <y>expression</y>
      <next>animation_id</next>
    </child>
  </childs>
  <sounds>
    <sound animationid="int">
      <probability>int</probability>
      <loop>int</loop>
      <base64>base64 MP3</base64>
    </sound>
  </sounds>
</animations>
```

### Expression Variables

| Variable | Description |
|----------|-------------|
| `screenW` | Full screen width |
| `screenH` | Full screen height |
| `areaW` | Visible area width (minus Dock) |
| `areaH` | Visible area height (minus menu bar) |
| `imageW` | Sprite frame width |
| `imageH` | Sprite frame height |
| `imageX` | Parent pet X (for children) |
| `imageY` | Parent pet Y (for children) |
| `random` | 0-99, re-evaluated each use |
| `randS` | 10-89, fixed per session |
| `scale` | HiDPI scale factor |

### Border Types

| Type | Value | Meaning |
|------|-------|---------|
| `none` | 0x7F | Always matches |
| `taskbar` | 0x01 | On dock area / screen bottom |
| `window` | 0x02 | On a window title bar |
| `horizontal` | 0x04 | Top/bottom screen edge |
| `horizontal+` | 0x06 | Horizontal OR window |
| `vertical` | 0x08 | Left/right screen edge |

### Special Animation Names

| Name | Behavior |
|------|----------|
| `fall` | Played after drag release |
| `drag` | Played while user holds pet |
| `kill` | Played on close (fades to opacity 0) |
| `sync` | Synchronization dance |

### Key Constants

| Constant | Value |
|----------|-------|
| Max pets | 16 |
| Window overlap tolerance | Width/2 each side |
| Gravity tolerance | 3px before fall triggers |
| Window follow timeout | 20 iterations * 16ms |
| Kill fade | opacity -= 0.1 per cycle |
| `randS` range | 10-89 |
| `random` range | 0-99 |

---

## 12. Complete Animation State List (Default Sheep)

| ID | Name | Behavior |
|----|------|----------|
| 1 | walk | Main idle: horizontal walking |
| 2-3 | rotate1a/b | Turn around (triggers flip) |
| 4 | drag | Being dragged by user |
| 5 | fall | Slow fall (Y: 1->10, accelerating) |
| 6 | fall fast | Fast falling |
| 7 | run | Running animation |
| 8 | boing | Hit wall while running |
| 9 | fall soft | Soft landing |
| 10 | fall hard | Hard landing |
| 11-12 | pissa/b | Urinating on window edge |
| 13 | kill | Death/close (fades to 0) |
| 14 | sync | Synchronization dance |
| 15-20 | sleep 1-3 a/b | Sleep variants |
| 21-24 | bath a/b/w/z | Bathing sequence |
| 25 | jump | Jump up |
| 26 | eat | Eating |
| 27 | flower | Flower interaction |
| 28-34 | blacksheep a-z | Black sheep companion (child) |
| 35-36 | run begin/end | Running transitions |
| 37 | vertical_walk_up | Climb up screen edge |
| 38-40 | top_walk 1-3 | Walking upside down |
| 41 | vertical_walk_down | Climb down |
| 42 | vertical_walk_over | Climbing to walking transition |
| 43 | look_down | Peek over window edge |
| 44-46 | jump_down 1-3 | Jump off window edge |
| 47-48 | bathc/d | More bath sequences |
| 49-50 | walk variants | Window/taskbar walking |
| 51-54 | fall_win a-d | Falling off window sequence |

---

## 13. Skills Applied During Review

| Skill | Key Contribution |
|-------|------------------|
| `swift-macos` | LSUIElement gotchas, onboarding with NSWindow, App Nap prevention, `applicationShouldTerminateAfterLastWindowClosed` |
| `swiftui-expert-skill` | MenuBarExtra patterns, macOS scenes, `@Observable` instead of `ObservableObject` |
| `swiftui-pro` | Modern SwiftUI patterns, Swift 6 concurrency awareness |
| `architecture-patterns` | Clean Architecture layers, dependency inversion |
| `clean-architecture` | Domain purity, framework isolation, testable boundaries |
| `solid-principles` | SRP (PetInstance vs StateMachine split), DIP (protocols for sprites/environment) |
| `clean-code-principles` | KISS (merge ScreenManager+SurfaceDetector), YAGNI (inline CoordinateConverter) |
| `code-quality-principles` | Simplicity-first, no premature abstraction |
| `state-machine-design` | Explicit state modeling, events/guards pattern, delegate-based actions |
| `macos-design-guidelines` | Context menus on pets, keyboard shortcuts in menu |
| `macos-native` | Drag-and-drop XML files, NSPanel configuration |
| `macos-app-structure` | Project organization patterns |
