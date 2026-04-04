# Familiar Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a macOS menubar desktop pet app that parses eSheep XML animations and renders an interactive pet on screen edges and window title bars.

**Architecture:** Clean Architecture with 4 layers — Domain (framework-free pure logic), Infrastructure (XML parsing, sprite loading, OS integration), Presentation (NSPanel, SwiftUI menus), App (composition root). SPM Package.swift for library/test targets; Xcode project added later for the app bundle.

**Tech Stack:** Swift, SwiftUI, AppKit (NSPanel), CoreGraphics, macOS 15+, Swift Testing framework, no external dependencies.

**Design Reference:** `docs/plans/2026-04-04-desktop-pet-design.md`

---

## Phase 1: Project Scaffold & Domain Models

### Task 1: Create SPM Package Structure

**Files:**
- Create: `Package.swift`
- Create: `Familiar/Domain/Model/.gitkeep` (placeholder — removed after real files land)

**Step 1: Create Package.swift**

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Familiar",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "FamiliarDomain", targets: ["FamiliarDomain"]),
    ],
    targets: [
        .target(
            name: "FamiliarDomain",
            path: "Familiar/Domain"
        ),
        .testTarget(
            name: "FamiliarTests",
            dependencies: ["FamiliarDomain"],
            path: "FamiliarTests/Domain"
        ),
    ]
)
```

**Step 2: Create minimal source so SPM resolves**

Create `Familiar/Domain/Model/BorderType.swift` with just the `BorderType` OptionSet (it has no dependencies).

**Step 3: Create minimal test file**

Create `FamiliarTests/Domain/BorderTypeTests.swift`:

```swift
import Testing
@testable import FamiliarDomain

@Suite("BorderType")
struct BorderTypeTests {
    @Test func noneContainsAllBits() {
        let none = BorderType.none
        #expect(none.contains(.taskbar))
        #expect(none.contains(.window))
        #expect(none.contains(.horizontal))
        #expect(none.contains(.vertical))
    }

    @Test func horizontalPlusIncludesWindowAndHorizontal() {
        let hp = BorderType.horizontalPlus
        #expect(hp.contains(.horizontal))
        #expect(hp.contains(.window))
        #expect(!hp.contains(.taskbar))
    }
}
```

**Step 4: Verify build and tests pass**

Run: `swift build && swift test`
Expected: Build succeeds, 2 tests pass.

**Step 5: Commit**

```
feat: initialize SPM package with Domain target and BorderType model
```

---

### Task 2: Domain Models — Core Value Types

**Files:**
- Create: `Familiar/Domain/Model/SurfaceType.swift`
- Create: `Familiar/Domain/Model/WalkableSurface.swift`
- Create: `Familiar/Domain/Model/NextAnim.swift`
- Create: `Familiar/Domain/Model/Spawn.swift`
- Create: `Familiar/Domain/Model/ChildDefinition.swift`
- Create: `Familiar/Domain/Model/PetHeader.swift`
- Create: `Familiar/Domain/Model/SpriteSheetInfo.swift`

**Step 1: Create all simple value types**

These are plain structs with no logic, from the design doc section 3.1. No framework imports. `WalkableSurface` uses a custom `Rect` and `Point` struct instead of CGRect (domain must be framework-free).

Domain-local geometry types (in a new file `Familiar/Domain/Model/Geometry.swift`):

```swift
struct Vec2 {
    let x: Double
    let y: Double
}

struct Rect {
    let origin: Vec2
    let width: Double
    let height: Double
}
```

`WalkableSurface` uses `Rect` instead of `CGRect`.

**Step 2: Build**

Run: `swift build`
Expected: PASS

**Step 3: Commit**

```
feat: add core domain value types (SurfaceType, WalkableSurface, NextAnim, Spawn, etc.)
```

---

### Task 3: Domain Models — Expression, Movement, Sequence, Animation

**Files:**
- Create: `Familiar/Domain/Model/Expression.swift`
- Create: `Familiar/Domain/Model/Movement.swift`
- Create: `Familiar/Domain/Model/AnimationSequence.swift`
- Create: `Familiar/Domain/Model/Animation.swift`
- Create: `Familiar/Domain/Model/PetAnimationData.swift`

**Step 1: Create Expression stub**

`Expression` holds a raw string and metadata flags. The `evaluate` method will be implemented in Task 5 (ExpressionEvaluator). For now, just the struct:

```swift
struct Expression {
    let raw: String
    let isDynamic: Bool
    let isScreenDependent: Bool

    static func constant(_ value: Int) -> Expression {
        Expression(raw: "\(value)", isDynamic: false, isScreenDependent: false)
    }
}
```

**Step 2: Create Movement, AnimationSequence, Animation, PetAnimationData**

From design doc section 3.1. `AnimationSequence` (renamed from `Sequence` to avoid stdlib collision) includes `totalSteps(repeatValue:)` and `frameIndex(at:)`.

**Step 3: Write tests for AnimationSequence logic**

Create `FamiliarTests/Domain/AnimationSequenceTests.swift`:

```swift
import Testing
@testable import FamiliarDomain

@Suite("AnimationSequence")
struct AnimationSequenceTests {
    @Test func totalStepsNoRepeat() {
        let seq = AnimationSequence(
            frames: [0, 1, 2],
            repeatCount: .constant(0),
            repeatFrom: 0,
            action: nil
        )
        #expect(seq.totalSteps(repeatValue: 0) == 3)
    }

    @Test func totalStepsWithRepeat() {
        let seq = AnimationSequence(
            frames: [0, 1, 2, 3],
            repeatCount: .constant(2),
            repeatFrom: 1,
            action: nil
        )
        // 4 + (4 - 1) * 2 = 10
        #expect(seq.totalSteps(repeatValue: 2) == 10)
    }

    @Test func frameIndexInInitialRange() {
        let seq = AnimationSequence(
            frames: [10, 20, 30],
            repeatCount: .constant(0),
            repeatFrom: 0,
            action: nil
        )
        #expect(seq.frameIndex(at: 0) == 10)
        #expect(seq.frameIndex(at: 1) == 20)
        #expect(seq.frameIndex(at: 2) == 30)
    }

    @Test func frameIndexInRepeatCycle() {
        let seq = AnimationSequence(
            frames: [10, 20, 30, 40],
            repeatCount: .constant(3),
            repeatFrom: 1,
            action: nil
        )
        // step 4 -> cycle over [20, 30, 40] -> index 1 -> 20
        #expect(seq.frameIndex(at: 4) == 20)
        // step 5 -> index 2 -> 30
        #expect(seq.frameIndex(at: 5) == 30)
        // step 6 -> index 3 -> 40
        #expect(seq.frameIndex(at: 6) == 40)
        // step 7 -> wraps -> 20
        #expect(seq.frameIndex(at: 7) == 20)
    }
}
```

**Step 4: Run tests**

Run: `swift test`
Expected: All tests pass.

**Step 5: Commit**

```
feat: add Expression, Movement, AnimationSequence, Animation domain models
```

---

## Phase 2: Domain Engine (TDD)

### Task 4: Interpolator

**Files:**
- Create: `Familiar/Domain/Engine/Interpolator.swift`
- Create: `FamiliarTests/Domain/InterpolatorTests.swift`

**Step 1: Write failing tests**

```swift
import Testing
@testable import FamiliarDomain

@Suite("Interpolator")
struct InterpolatorTests {
    @Test func valueAtStart() {
        #expect(Interpolator.value(start: 10, end: 50, step: 0, totalSteps: 4) == 10)
    }

    @Test func valueAtEnd() {
        #expect(Interpolator.value(start: 10, end: 50, step: 4, totalSteps: 4) == 50)
    }

    @Test func valueMidpoint() {
        #expect(Interpolator.value(start: 0, end: 100, step: 2, totalSteps: 4) == 50)
    }

    @Test func valueZeroSteps() {
        #expect(Interpolator.value(start: 10, end: 50, step: 0, totalSteps: 0) == 10)
    }

    @Test func movementAtStart() {
        #expect(Interpolator.movement(start: 0, end: 30, step: 0, totalSteps: 4) == 0)
    }

    @Test func movementAtEnd() {
        // Uses totalSteps-1 as denominator: 0 + 30 * 3 / 3 = 30
        #expect(Interpolator.movement(start: 0, end: 30, step: 3, totalSteps: 4) == 30)
    }

    @Test func movementSingleStep() {
        #expect(Interpolator.movement(start: 5, end: 20, step: 0, totalSteps: 1) == 5)
    }
}
```

**Step 2: Run to verify failure**

Run: `swift test`
Expected: FAIL — `Interpolator` not found.

**Step 3: Implement Interpolator**

```swift
enum Interpolator {
    static func value(start: Int, end: Int, step: Int, totalSteps: Int) -> Int {
        guard totalSteps > 0 else { return start }
        return start + (end - start) * step / totalSteps
    }

    static func movement(start: Int, end: Int, step: Int, totalSteps: Int) -> Int {
        guard totalSteps > 1 else { return start }
        return start + (end - start) * step / (totalSteps - 1)
    }
}
```

**Step 4: Run tests**

Run: `swift test`
Expected: All pass.

**Step 5: Commit**

```
feat: add Interpolator with linear interpolation matching eSheep formula
```

---

### Task 5: Expression Evaluator

**Files:**
- Create: `Familiar/Domain/Engine/ExpressionEvaluator.swift`
- Modify: `Familiar/Domain/Model/Expression.swift` (add `evaluate` method)
- Create: `FamiliarTests/Domain/ExpressionEvaluatorTests.swift`

**Step 1: Write failing tests**

```swift
import Testing
@testable import FamiliarDomain

@Suite("ExpressionEvaluator")
struct ExpressionEvaluatorTests {
    let defaultContext = ExpressionContext(
        screenW: 1920, screenH: 1080,
        areaW: 1920, areaH: 1055,
        imageW: 64, imageH: 64,
        imageX: 100, imageY: 200,
        random: 42, randS: 50, scale: 2
    )

    @Test func integerLiteral() {
        #expect(ExpressionEvaluator.evaluate("100", context: defaultContext) == 100)
    }

    @Test func negativeLiteral() {
        #expect(ExpressionEvaluator.evaluate("-5", context: defaultContext) == -5)
    }

    @Test func addition() {
        #expect(ExpressionEvaluator.evaluate("10+20", context: defaultContext) == 30)
    }

    @Test func subtraction() {
        #expect(ExpressionEvaluator.evaluate("50-30", context: defaultContext) == 20)
    }

    @Test func multiplication() {
        #expect(ExpressionEvaluator.evaluate("6*7", context: defaultContext) == 42)
    }

    @Test func division() {
        #expect(ExpressionEvaluator.evaluate("100/3", context: defaultContext) == 33)
    }

    @Test func divisionByZero() {
        #expect(ExpressionEvaluator.evaluate("10/0", context: defaultContext) == 0)
    }

    @Test func operatorPrecedence() {
        // 2 + 3 * 4 = 14
        #expect(ExpressionEvaluator.evaluate("2+3*4", context: defaultContext) == 14)
    }

    @Test func parentheses() {
        // (2 + 3) * 4 = 20
        #expect(ExpressionEvaluator.evaluate("(2+3)*4", context: defaultContext) == 20)
    }

    @Test func variableScreenW() {
        #expect(ExpressionEvaluator.evaluate("screenW", context: defaultContext) == 1920)
    }

    @Test func variableAreaH() {
        #expect(ExpressionEvaluator.evaluate("areaH", context: defaultContext) == 1055)
    }

    @Test func variableRandom() {
        #expect(ExpressionEvaluator.evaluate("random", context: defaultContext) == 42)
    }

    @Test func complexExpression() {
        // screenW - imageW * 2 = 1920 - 128 = 1792
        #expect(ExpressionEvaluator.evaluate("screenW-imageW*2", context: defaultContext) == 1792)
    }

    @Test func expressionWithSpaces() {
        #expect(ExpressionEvaluator.evaluate(" 10 + 20 ", context: defaultContext) == 30)
    }
}
```

**Step 2: Run to verify failure**

Run: `swift test`
Expected: FAIL

**Step 3: Implement ExpressionContext and ExpressionEvaluator**

`ExpressionContext` struct:

```swift
struct ExpressionContext {
    let screenW: Int
    let screenH: Int
    let areaW: Int
    let areaH: Int
    let imageW: Int
    let imageH: Int
    let imageX: Int
    let imageY: Int
    let random: Int
    let randS: Int
    let scale: Int
}
```

`ExpressionEvaluator` — recursive descent parser (~60 lines):
- Tokenize: numbers, identifiers, `+`, `-`, `*`, `/`, `(`, `)`
- `parseExpr`: handles `+` and `-`
- `parseTerm`: handles `*` and `/`
- `parseFactor`: handles numbers, identifiers (variable lookup), parenthesized sub-expressions, unary minus

Wire `Expression.evaluate(context:)` to call `ExpressionEvaluator.evaluate(raw, context:)`.

**Step 4: Run tests**

Run: `swift test`
Expected: All pass.

**Step 5: Commit**

```
feat: add recursive descent expression evaluator for eSheep expression language
```

---

### Task 6: TransitionPicker

**Files:**
- Create: `Familiar/Domain/Engine/TransitionPicker.swift`
- Create: `FamiliarTests/Domain/TransitionPickerTests.swift`

**Step 1: Write failing tests**

```swift
import Testing
@testable import FamiliarDomain

@Suite("TransitionPicker")
struct TransitionPickerTests {
    @Test func pickFromEmptyCandidates() {
        let result = TransitionPicker.pick(from: [], context: .none)
        #expect(result == nil)
    }

    @Test func pickSingleCandidate() {
        let candidates = [NextAnim(animationId: 5, probability: 100, only: .none)]
        let result = TransitionPicker.pick(from: candidates, context: .none)
        #expect(result == 5)
    }

    @Test func filtersByBorderType() {
        let candidates = [
            NextAnim(animationId: 1, probability: 100, only: .taskbar),
            NextAnim(animationId: 2, probability: 100, only: .window),
        ]
        // Context is window — only candidate 2 matches
        let result = TransitionPicker.pick(from: candidates, context: .window)
        #expect(result == 2)
    }

    @Test func noneMatchesEverything() {
        let candidates = [
            NextAnim(animationId: 7, probability: 100, only: .none),
        ]
        let result = TransitionPicker.pick(from: candidates, context: .taskbar)
        #expect(result == 7)
    }

    @Test func zeroProbabilityReturnsNil() {
        let candidates = [
            NextAnim(animationId: 1, probability: 0, only: .none),
        ]
        let result = TransitionPicker.pick(from: candidates, context: .none)
        #expect(result == nil)
    }

    @Test func weightedDistribution() {
        let candidates = [
            NextAnim(animationId: 1, probability: 90, only: .none),
            NextAnim(animationId: 2, probability: 10, only: .none),
        ]
        // Run many picks, both should appear
        var seen: Set<Int> = []
        for _ in 0 ..< 200 {
            if let id = TransitionPicker.pick(from: candidates, context: .none) {
                seen.insert(id)
            }
        }
        #expect(seen.contains(1))
        #expect(seen.contains(2))
    }
}
```

**Step 2: Run to verify failure**

Run: `swift test`
Expected: FAIL

**Step 3: Implement TransitionPicker**

From design doc section 3.4 — filter by border type, weighted random selection.

**Step 4: Run tests**

Run: `swift test`
Expected: All pass.

**Step 5: Commit**

```
feat: add TransitionPicker for weighted random animation selection
```

---

### Task 7: Domain Protocols

**Files:**
- Create: `Familiar/Domain/Protocols/SpriteProviding.swift`
- Create: `Familiar/Domain/Protocols/EnvironmentDetecting.swift`

**Step 1: Create protocols**

From design doc section 3.3. `EnvironmentDetecting` uses domain `Rect` type, not `CGRect`. Add `ScreenEdge` enum.

**Step 2: Build**

Run: `swift build`
Expected: PASS

**Step 3: Commit**

```
feat: add SpriteProviding and EnvironmentDetecting domain protocols
```

---

### Task 8: AnimationStateMachine — Core Tick Loop

**Files:**
- Create: `Familiar/Domain/Engine/AnimationStateMachine.swift`
- Create: `FamiliarTests/Domain/AnimationStateMachineTests.swift`

**Step 1: Write failing tests**

Test the core behaviors:
- Respawn picks a spawn by weighted probability and sets initial animation
- Tick advances frame step and reports frame index via delegate
- Tick interpolates movement and reports dx/dy via delegate
- Sequence completion picks next animation from endAnimation list
- Drag start/end switches to drag/fall animations
- Kill triggers kill animation

Use mock delegate and mock environment detector (both implemented as test doubles conforming to protocols).

```swift
import Testing
@testable import FamiliarDomain

// Test doubles
final class MockStateMachineDelegate: AnimationStateMachineDelegate {
    var frameChanges: [Int] = []
    var moves: [(dx: Int, dy: Int)] = []
    var opacityChanges: [Double] = []
    var intervalChanges: [Int] = []
    var respawnCount = 0
    var flipCount = 0

    func stateMachine(_ sm: AnimationStateMachine, didChangeFrame index: Int) {
        frameChanges.append(index)
    }
    func stateMachine(_ sm: AnimationStateMachine, didMove dx: Int, dy: Int) {
        moves.append((dx, dy))
    }
    func stateMachine(_ sm: AnimationStateMachine, didChangeOpacity opacity: Double) {
        opacityChanges.append(opacity)
    }
    func stateMachine(_ sm: AnimationStateMachine, didChangeInterval ms: Int) {
        intervalChanges.append(ms)
    }
    func stateMachineDidRequestRespawn(_ sm: AnimationStateMachine) {
        respawnCount += 1
    }
    func stateMachineDidFlipSprites(_ sm: AnimationStateMachine) {
        flipCount += 1
    }
}

final class MockEnvironmentDetector: EnvironmentDetecting {
    var surfaces: [WalkableSurface] = []
    func detectSurfaces() -> [WalkableSurface] { surfaces }
    func isFullScreenActive() -> Bool { false }
    func currentScreenFrame() -> Rect { Rect(origin: .zero, width: 1920, height: 1080) }
    func currentVisibleFrame() -> Rect { Rect(origin: .zero, width: 1920, height: 1055) }
    func hasAdjacentScreen(at edge: ScreenEdge) -> Bool { false }
}

@Suite("AnimationStateMachine")
struct AnimationStateMachineTests {
    // Build a minimal animation set for testing
    static func makeWalkAnimation() -> Animation { /* 3-frame walk, endAnimation loops to self */ }
    static func makeFallAnimation() -> Animation { /* fall animation */ }
    static func makeDragAnimation() -> Animation { /* drag animation */ }

    @Test func respawnSetsInitialAnimation() { /* ... */ }
    @Test func tickAdvancesFrameAndReportsToDelegate() { /* ... */ }
    @Test func tickInterpolatesMovement() { /* ... */ }
    @Test func sequenceCompletionTransitionsToNextAnimation() { /* ... */ }
    @Test func dragStartSwitchesToDragAnimation() { /* ... */ }
    @Test func dragEndSwitchesToFallAnimation() { /* ... */ }
}
```

Note: The exact test implementations will reference concrete animation fixtures. The implementer should create a helper function that builds minimal `Animation` objects for testing.

**Step 2: Run to verify failure**

Run: `swift test`
Expected: FAIL

**Step 3: Implement AnimationStateMachine**

From design doc section 3.4. Key points:
- `tick()` method: advance step, compute frame index via `AnimationSequence.frameIndex(at:)`, interpolate movement via `Interpolator`, notify delegate
- `respawn()`: weighted pick from spawns, evaluate spawn x/y, set initial animation
- `handleDragStart()`/`handleDragEnd()`: switch to drag/fall animations
- `handleKill()`: switch to kill animation
- Special animation IDs resolved by name ("fall", "drag", "kill") at init time

**Step 4: Run tests**

Run: `swift test`
Expected: All pass.

**Step 5: Commit**

```
feat: add AnimationStateMachine with tick loop, spawn, drag, and kill
```

---

## Phase 3: Infrastructure Layer

### Task 9: Add Infrastructure Target to Package.swift

**Files:**
- Modify: `Package.swift`

**Step 1: Add FamiliarInfrastructure target**

```swift
.target(
    name: "FamiliarInfrastructure",
    dependencies: ["FamiliarDomain"],
    path: "Familiar/Infrastructure"
),
.testTarget(
    name: "FamiliarInfrastructureTests",
    dependencies: ["FamiliarInfrastructure"],
    path: "FamiliarTests/Infrastructure"
),
```

**Step 2: Build**

Run: `swift build`
Expected: PASS

**Step 3: Commit**

```
feat: add FamiliarInfrastructure SPM target
```

---

### Task 10: XML Animation Parser

**Files:**
- Create: `Familiar/Infrastructure/XMLAnimationParser.swift`
- Create: `FamiliarTests/Infrastructure/XMLAnimationParserTests.swift`
- Create: `FamiliarTests/Infrastructure/Resources/test-sheep.xml` (minimal valid eSheep XML)

**Step 1: Create a minimal test XML fixture**

A stripped-down valid eSheep XML with: header, image section (tiny base64 PNG, 2x2 tiles), 1 spawn, 2 animations (walk + fall). This is the minimum needed to test the parser.

**Step 2: Write failing tests**

```swift
import Testing
import Foundation
@testable import FamiliarInfrastructure
@testable import FamiliarDomain

@Suite("XMLAnimationParser")
struct XMLAnimationParserTests {
    let parser = XMLAnimationParser()

    func loadTestXML() throws -> Data {
        // Load from test bundle or inline
    }

    @Test func parsesHeader() throws {
        let (data, _) = try parser.parse(loadTestXML())
        #expect(data.header.petName == "TestSheep")
        #expect(data.header.author == "Test")
    }

    @Test func parsesSpriteInfo() throws {
        let (data, _) = try parser.parse(loadTestXML())
        #expect(data.spriteInfo.tilesX == 2)
        #expect(data.spriteInfo.tilesY == 2)
    }

    @Test func parsesSpawns() throws {
        let (data, _) = try parser.parse(loadTestXML())
        #expect(data.spawns.count == 1)
        #expect(data.spawns[0].probability == 100)
    }

    @Test func parsesAnimations() throws {
        let (data, _) = try parser.parse(loadTestXML())
        #expect(data.animations.count == 2)
        #expect(data.animations[1]?.name == "walk")
    }

    @Test func extractsBase64PNG() throws {
        let (_, base64) = try parser.parse(loadTestXML())
        #expect(!base64.isEmpty)
    }

    @Test func invalidXMLThrows() {
        #expect(throws: XMLParseError.self) {
            try parser.parse(Data("not xml".utf8))
        }
    }
}
```

**Step 3: Implement XMLAnimationParser**

Uses Foundation `XMLParser` with delegate pattern. Returns `(PetAnimationData, String)` — the parsed data and raw base64 PNG string.

Key parsing details from design doc section 4.1 and section 11 (XML schema):
- Namespace: `https://esheep.petrucci.ch/`
- Elements are lowercase: `<petname>`, `<tilesx>`, `<tilesy>`, `<png>`
- `<next>` elements appear in spawns, sequences, borders, gravity sections
- `<frame>` and `<action>` are direct children of `<sequence>`
- Expression strings come from element text content (e.g., `<x>screenW/2</x>`)

**Step 4: Run tests**

Run: `swift test`
Expected: All pass.

**Step 5: Commit**

```
feat: add XMLAnimationParser for eSheep XML format
```

---

### Task 11: Sprite Sheet Loader

**Files:**
- Create: `Familiar/Infrastructure/SpriteSheetLoader.swift`
- Create: `FamiliarTests/Infrastructure/SpriteSheetLoaderTests.swift`

**Step 1: Write failing tests**

Test with a programmatically-created base64 PNG (tiny 4x4 image, 2x2 tiles = 4 frames of 2x2 pixels).

```swift
@Suite("SpriteSheetLoader")
struct SpriteSheetLoaderTests {
    @Test func slicesCorrectNumberOfFrames() throws {
        let loader = try SpriteSheetLoader(base64PNG: TestFixtures.tinyBase64PNG, tilesX: 2, tilesY: 2)
        #expect(loader.frameCount == 4)
    }

    @Test func frameDimensions() throws {
        let loader = try SpriteSheetLoader(base64PNG: TestFixtures.tinyBase64PNG, tilesX: 2, tilesY: 2)
        #expect(loader.frameWidth == 2)
        #expect(loader.frameHeight == 2)
    }

    @Test func flipTogglesState() throws {
        let loader = try SpriteSheetLoader(base64PNG: TestFixtures.tinyBase64PNG, tilesX: 2, tilesY: 2)
        #expect(!loader.isFlipped)
        loader.flipAllFrames()
        #expect(loader.isFlipped)
        loader.flipAllFrames()
        #expect(!loader.isFlipped)
    }
}
```

**Step 2: Implement SpriteSheetLoader**

From design doc section 4.2. Uses AppKit `NSImage`/`CGImage` for decoding and slicing. Conforms to `SpriteProviding`.

**Step 3: Run tests**

Run: `swift test`
Expected: All pass.

**Step 4: Commit**

```
feat: add SpriteSheetLoader for base64 PNG sprite sheet slicing
```

---

### Task 12: Environment Detector

**Files:**
- Create: `Familiar/Infrastructure/EnvironmentDetector.swift`

**Step 1: Implement EnvironmentDetector**

From design doc section 4.3. Conforms to `EnvironmentDetecting`. Key behaviors:
- `detectSurfaces()`: screen edges (always) + window top edges (if Screen Recording permission granted)
- Coordinate conversion: CG (top-left origin) → NS (bottom-left origin)
- `hasScreenRecordingPermission()`: attempt `CGWindowListCopyWindowInfo`, check for valid results
- `isFullScreenActive()`: check if frontmost window covers entire screen
- `hasAdjacentScreen(at:)`: check `NSScreen.screens` for abutting edges

This class requires AppKit/CoreGraphics and real system state — unit testing is limited. Focus on ensuring it builds and the coordinate conversion math is correct.

**Step 2: Build**

Run: `swift build`
Expected: PASS

**Step 3: Commit**

```
feat: add EnvironmentDetector for screen edges and window detection
```

---

## Phase 4: Presentation Layer

### Task 13: Add Presentation and App Targets

**Files:**
- Modify: `Package.swift` — this is where we transition to an Xcode project

At this point we need to create a proper Xcode project for the app bundle (requires Info.plist with LSUIElement, app icon, MenuBarExtra scene). The Domain and Infrastructure code stays testable via `swift test` through Package.swift.

**Step 1: Create Xcode project**

Create `Familiar.xcodeproj` using Xcode or `xcodebuild`. The project should:
- Target macOS 15+
- Set `LSUIElement = YES` in Info.plist
- Include all source files from `Familiar/` directory
- Include test target from `FamiliarTests/` directory
- Use Swift 6.0 language version

**Step 2: Verify build**

Run: `xcodebuild -scheme Familiar -destination 'platform=macOS' build`
Expected: PASS

**Step 3: Commit**

```
feat: add Xcode project for Familiar app bundle
```

---

### Task 14: PetPanel (NSPanel)

**Files:**
- Create: `Familiar/Presentation/Pet/PetPanel.swift`

**Step 1: Implement PetPanel**

From design doc section 5.1. Key configuration:
- `NSPanel` with `[.borderless, .nonactivatingPanel]`
- `isFloatingPanel = true`, `level = .statusBar`
- `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]`
- Transparent background, no shadow, doesn't hide on deactivate
- Contains `NSImageView` for sprite rendering
- Mouse tracking for drag interaction
- Right-click context menu (Remove, Reset Position, About)
- Drag-and-drop for `.xml` file URLs

**Step 2: Build**

Run: `swift build` or `xcodebuild ...`
Expected: PASS

**Step 3: Commit**

```
feat: add PetPanel with transparent NSPanel, drag interaction, and context menu
```

---

### Task 15: PetInstance

**Files:**
- Create: `Familiar/Presentation/Pet/PetInstance.swift`

**Step 1: Implement PetInstance**

From design doc section 5.2. Conforms to `AnimationStateMachineDelegate`. Bridges state machine events to panel updates:
- `didChangeFrame` → update `spriteView.image`
- `didMove` → update panel position
- `didChangeOpacity` → update `panel.alphaValue`
- `didRequestRespawn` → re-evaluate spawn, reposition
- `didFlipSprites` → call `spriteSheet.flipAllFrames()`

**Step 2: Build**

Run: `swift build`
Expected: PASS

**Step 3: Commit**

```
feat: add PetInstance bridging state machine to panel rendering
```

---

### Task 16: Menu Bar UI

**Files:**
- Create: `Familiar/Presentation/Menu/MenuBarView.swift`
- Create: `Familiar/Presentation/Menu/AboutView.swift`
- Create: `Familiar/Presentation/Menu/OptionsView.swift`

**Step 1: Implement MenuBarView**

From design doc section 7. SwiftUI view for `MenuBarExtra` with `.menuBarExtraStyle(.window)`:
- Add Pet (⌘N), Load Custom Pet... (⌘O)
- Active Pets list with per-pet remove buttons
- Pause/Resume All (⌘P)
- Reset Positions (⌘R)
- Options submenu: Multi-Screen toggle, Window Walking toggle, Launch at Login
- About, Quit (⌘Q)

**Step 2: Implement AboutView and OptionsView**

Simple SwiftUI views. AboutView shows pet header info. OptionsView shows toggle settings.

**Step 3: Build**

Run: `swift build`
Expected: PASS

**Step 4: Commit**

```
feat: add menu bar UI with pet list, options, and keyboard shortcuts
```

---

### Task 17: Onboarding View

**Files:**
- Create: `Familiar/Presentation/Onboarding/OnboardingView.swift`

**Step 1: Implement OnboardingView**

Simple SwiftUI view explaining Screen Recording permission. Has a "Request Permission" button that calls `CGRequestScreenCaptureAccess()` and a "Continue Without" option.

**Step 2: Build**

Run: `swift build`
Expected: PASS

**Step 3: Commit**

```
feat: add onboarding view for Screen Recording permission request
```

---

## Phase 5: App Layer — Wiring Everything Together

### Task 18: AppSettings

**Files:**
- Create: `Familiar/App/AppSettings.swift`

**Step 1: Implement AppSettings**

From design doc section 7.3. `@Observable` class with `@AppStorage` properties for persistence.

**Step 2: Build & Commit**

```
feat: add AppSettings with persistent user preferences
```

---

### Task 19: PetManager

**Files:**
- Create: `Familiar/App/PetManager.swift`

**Step 1: Implement PetManager**

From design doc section 6.1. `@Observable` class:
- `loadXML(from:)` — parse XML, store data
- `addPet()` — create SpriteSheetLoader, AnimationStateMachine, PetPanel, PetInstance
- `removePet(id:)` — trigger kill animation, then remove
- `removeAll()` — close all panels
- Shared `DispatchSourceTimer` at 50ms interval driving `tickAllPets()`
- `tickAllPets()` — detect surfaces, tick each pet's state machine
- Full-screen detection: lower panel level when full-screen app detected

**Step 2: Build & Commit**

```
feat: add PetManager orchestrating pet lifecycle and shared timer
```

---

### Task 20: AppDelegate

**Files:**
- Create: `Familiar/App/AppDelegate.swift`

**Step 1: Implement AppDelegate**

From design doc section 6.3:
- `applicationDidFinishLaunching`: prevent App Nap, check onboarding, load bundled XML, spawn initial pet
- `applicationShouldTerminateAfterLastWindowClosed`: return `false`
- Onboarding window via `NSWindow` + `NSHostingView` (not SwiftUI scene — LSUIElement limitation)

**Step 2: Build & Commit**

```
feat: add AppDelegate with initialization, onboarding, and App Nap prevention
```

---

### Task 21: App Entry Point

**Files:**
- Create: `Familiar/App/FamiliarApp.swift`

**Step 1: Implement FamiliarApp**

From design doc section 6.2:

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

**Step 2: Build & Commit**

```
feat: add FamiliarApp entry point with MenuBarExtra scene
```

---

### Task 22: Bundle Default Sheep XML

**Files:**
- Create: `Familiar/Resources/animations.xml`

**Step 1: Add bundled eSheep XML**

Download or embed the default sheep animation XML from the eSheep project (Adrianotiger/desktopPet). This XML file contains the full 54-animation sheep with base64 sprite sheet.

**Step 2: Build and run**

Run: `xcodebuild -scheme Familiar -destination 'platform=macOS' build`
Expected: PASS

**Step 3: Commit**

```
feat: bundle default sheep animation XML
```

---

## Phase 6: Integration & Polish

### Task 23: End-to-End Smoke Test

**Step 1: Run the app**

Launch the app, verify:
- Menu bar icon appears
- Pet spawns on screen bottom
- Pet walks (animation cycles)
- Drag interaction works
- Right-click context menu works
- Add Pet / Remove Pet from menu works
- Load Custom Pet opens file picker

**Step 2: Fix any issues found**

**Step 3: Commit**

```
fix: integration fixes from end-to-end smoke testing
```

---

### Task 24: Quality Checks & Final Commit

**Step 1: Run all quality checks**

Run: `./scripts/check.sh all`
Expected: ALL CHECKS PASSED

**Step 2: Fix any failures**

**Step 3: Update history**

Append session summary to `docs/history.md`.

**Step 4: Final commit**

```
chore: pass all quality checks, update implementation history
```

---

## Dependency Graph

```
Task 1 (scaffold)
  → Task 2 (value types)
    → Task 3 (Expression, Animation models)
      → Task 4 (Interpolator)
      → Task 5 (ExpressionEvaluator)
      → Task 6 (TransitionPicker)
      → Task 7 (Protocols)
        → Task 8 (AnimationStateMachine) [depends on 4,5,6,7]
          → Task 9 (Infra target)
            → Task 10 (XML Parser)
            → Task 11 (Sprite Sheet Loader)
            → Task 12 (Environment Detector)
              → Task 13 (Xcode project)
                → Task 14-17 (Presentation) [parallel]
                  → Task 18-21 (App layer) [sequential]
                    → Task 22 (Bundle XML)
                      → Task 23 (Smoke test)
                        → Task 24 (Quality)
```

Tasks 4, 5, 6 can be done in parallel.
Tasks 10, 11, 12 can be done in parallel.
Tasks 14, 15, 16, 17 can be done in parallel.
