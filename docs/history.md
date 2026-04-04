# Implementation History

Chronological log of all user instructions, decisions, and implementation steps.

---

## 2026-04-04 — Project Inception & Design

### User Request
> "I want you to implement a desktop pet for macOS. Some inspirations: desktoppet.app, mentadd.com/sheep, github.com/Adrianotiger/desktopPet. It must be a macOS menubar app. It must follow the original eSheep logic as much as possible. Do research on the internet. Create a comprehensive resource directory. Use superpowers to brainstorm and propose."

### Research Phase
- Deep research on Adrianotiger/desktopPet: full XML schema, 54 animations, state machine logic, physics, window detection, child pets, sounds
- Research on desktoppet.app: commercial Unity-based pet with AI chat, Pomodoro, likely ~191MB
- Research on mentadd.com/sheep: original 1995 eSheep history by Tatsutoshi Nomura
- Research on macOS implementation techniques: NSPanel, CGWindowListCopyWindowInfo, SpriteKit, MenuBarExtra
- Research on existing Swift desktop pets: pet-therapy, Cat, ScreenPets, slime-1.0
- Comprehensive resource directory saved to `docs/research.md`

### Brainstorming Decisions (7 questions)
1. **Character system** → Pluggable: eSheep XML compatible, bundled default sheep, load any community XML
2. **Surface interaction** → Full: screen edges + window title bars + climbing walls + upside-down walking
3. **Sprite assets** → Parse base64 PNG from XML directly (maximum compatibility with eSheep ecosystem)
4. **Sound support** → Silent first, add later (focus on visual pet and state machine first)
5. **Multi-pet** → Multiple pets (max 16), no children initially
6. **macOS target** → macOS 15 (Sequoia)+
7. **Menu bar** → Enhanced: active pet list, pause/resume, options submenu, custom XML loading, per-pet remove

### Skill Installation
Installed 16 skills for implementation guidance:
- SwiftUI: swiftui-expert-skill (12.6K), swiftui-pro (8K), swiftui-performance-audit, swiftui-patterns
- Architecture: architecture-patterns (10.2K), clean-architecture, solid-principles, clean-code-principles, code-quality-principles
- macOS: macos-design-guidelines (2.1K), macos-native, macos-app-structure, swift-macos
- Specialized: axiom-spritekit, spritekit, state-machine-design

### Design Review (against all 16 skills)
Key findings and fixes applied:
- **LSUIElement gotchas** (swift-macos): Added onboarding via NSWindow, `activate(ignoringOtherApps:)` calls, `applicationShouldTerminateAfterLastWindowClosed = false`
- **Clean Architecture** (clean-architecture, solid-principles): Restructured into Domain/Infrastructure/Presentation/App layers with framework-free domain
- **State machine** (state-machine-design): Changed from implicit tick loop to explicit protocol with delegate pattern and events/guards
- **@Observable** (swiftui-expert-skill): PetManager uses `@Observable` + `.environment()` instead of singleton
- **KISS/YAGNI** (code-quality-principles): Merged ScreenManager+SurfaceDetector+CoordinateConverter into single EnvironmentDetector; custom expression parser instead of NSExpression
- **macOS HIG** (macos-design-guidelines): Added right-click context menu on pets, keyboard shortcuts in menu
- **Drag-and-drop** (macos-native): Added XML file drag-and-drop on pet panels
- **Single shared timer** instead of per-pet timers

### Output
- `docs/research.md` — Comprehensive resource directory
- `docs/plans/2026-04-04-desktop-pet-design.md` — Full design document (post-review)
- `README.md` — Project readme
- `CLAUDE.md` — Project rules for AI assistant
- `docs/history.md` — This file

---

## 2026-04-04 — Git Repository Setup

### User Request
> "I suggest to start creating a git repo, add readme.md, add rule to always saving the plans and to collect all the prompts I gave you in a file to create a history of the implementation."

### Actions
- Initialized git repository
- Created `README.md` with project overview, features, architecture summary
- Created `CLAUDE.md` with rules: always save plans, record prompts in history, coding standards
- Created `docs/history.md` with full chronological log of all decisions
- Created `.gitignore` for Xcode/Swift projects

---

## 2026-04-04 — Quality Checks & Hooks Setup

### User Request
> "Add lint, checks, run tests etc, as hooks and be sure that the lints, format, tests etc pass before considering a session done. Commit at the end of each successful session."

### Actions
- Created `.swiftlint.yml` with project-specific rules (line length 130, relaxed identifier names for x/y/dx/dy)
- Created `.swiftformat` config (Swift 6.2, 4-space indent, sorted imports, max width 130)
- Created `scripts/check.sh` — unified quality gate script (lint + format + build + test)
- Created git pre-commit hook (`.git/hooks/pre-commit`) — blocks commits with SwiftLint/SwiftFormat issues
- Created `.claude/settings.json` with Claude Code hooks:
  - **PostToolUse (Write|Edit)**: auto-formats Swift files after every write/edit
  - **Stop**: reminds to run checks before session end
- Updated `CLAUDE.md` with mandatory session end protocol: run checks, fix failures, commit, update history
- Auto-allow permissions for swiftlint, swiftformat, swift build/test, xcodebuild

---

## 2026-04-04 — Project Rename & Implementation Plan

### User Request
> "We are renaming the project from DesktopPet to Familiar. Before starting the plan, finish this conversion."
> "Continue" (create implementation plan)

### Actions — Rename
- Renamed all references from `DesktopPet` → `Familiar`, `DesktopPetApp` → `FamiliarApp`, `DesktopPetTests` → `FamiliarTests`, `Desktop Pet` → `Familiar`
- Updated: `CLAUDE.md`, `.swiftlint.yml`, `README.md`, `scripts/check.sh`, `docs/plans/2026-04-04-desktop-pet-design.md`, `docs/research.md`

### Actions — Implementation Plan
- Created `docs/plans/2026-04-04-implementation-plan.md` — 24-task TDD implementation plan across 6 phases:
  1. Project scaffold & domain models (Tasks 1-3)
  2. Domain engine with TDD (Tasks 4-8: Interpolator, ExpressionEvaluator, TransitionPicker, AnimationStateMachine)
  3. Infrastructure layer (Tasks 9-12: SPM target, XML parser, sprite loader, environment detector)
  4. Presentation layer (Tasks 13-17: Xcode project, PetPanel, PetInstance, menu bar, onboarding)
  5. App layer wiring (Tasks 18-22: AppSettings, PetManager, AppDelegate, FamiliarApp, bundled XML)
  6. Integration & polish (Tasks 23-24: smoke test, quality checks)

---

## 2026-04-04 — Task 1: Create SPM Package Structure

### User Request
> "Implement Task 1: Create SPM Package Structure"

### Actions
- Created `Package.swift` with `FamiliarDomain` library target (path: `Familiar/Domain`) and `FamiliarTests` test target (path: `FamiliarTests/Domain`)
- Created `Familiar/Domain/Model/BorderType.swift` — `OptionSet` with `Sendable` conformance for Swift 6 strict concurrency
- Created `FamiliarTests/Domain/BorderTypeTests.swift` — 2 tests using Swift Testing framework verifying OptionSet bit logic
- Fixed `.swiftformat` config: `--sortimports` was renamed to `--importgrouping` in SwiftFormat v0.51
- All quality checks pass (SwiftLint, SwiftFormat, build, tests)
- Committed: `efc4395`

---

## 2026-04-04 — Task 2: Domain Models — Core Value Types

### User Request
> "Implement Task 2: Domain Models — Core Value Types"

### Actions
- Created 9 domain model files in `Familiar/Domain/Model/`:
  - `Geometry.swift` — `Vec2` and `Rect` structs (domain-local replacements for CGPoint/CGRect)
  - `SurfaceType.swift` — Enum for screen edges and window tops
  - `WalkableSurface.swift` — Combines `Rect` + `SurfaceType`
  - `Expression.swift` — Minimal stub with `raw`, `isDynamic`, `isScreenDependent` (to be expanded in Tasks 3/5)
  - `NextAnim.swift` — Animation transition with probability and border constraint
  - `Spawn.swift` — Child spawn definition with position expressions and next animations
  - `ChildDefinition.swift` — Child pet definition with animation and position
  - `PetHeader.swift` — Pet metadata (author, title, name, version, info)
  - `SpriteSheetInfo.swift` — Sprite sheet tile dimensions
- All types are `public` with `Sendable` conformance for Swift 6 strict concurrency
- Zero framework imports — pure Swift domain layer
- All quality checks pass (SwiftLint, SwiftFormat, build, tests)

---

## 2026-04-04 — Task 3: Domain Models — Movement, AnimationSequence, Animation, PetAnimationData

### User Request
> "Implement Task 3: Domain Models — Movement, AnimationSequence, Animation, PetAnimationData"

### Actions
- Created 4 domain model files in `Familiar/Domain/Model/`:
  - `Movement.swift` — Movement descriptor with x/y/interval expressions, offsetY, opacity
  - `AnimationSequence.swift` — Frame sequence with repeat logic; `totalSteps(repeatValue:)` and `frameIndex(at:)` methods
  - `Animation.swift` — Full animation definition with start/end movements, sequence, and transition arrays (endAnimation/endBorder/endGravity)
  - `PetAnimationData.swift` — Top-level pet data aggregating header, sprite info, spawns, animations, and children
- Created `FamiliarTests/Domain/AnimationSequenceTests.swift` — 7 tests covering:
  - `totalSteps` with no repeat, with repeat, and repeatFrom=0
  - `frameIndex` in initial range, in repeat cycle, and with repeatFrom=0
- Named `AnimationSequence` to avoid collision with Swift stdlib `Sequence`
- Used corrected `frameIndex` formula: `frames[((step - frames.count) % cycleLength) + repeatFrom]`
- All types are `public` with `Sendable` conformance, zero framework imports
- All quality checks pass (SwiftLint, SwiftFormat, build, 8 tests passing)

---

## 2026-04-04 — Task 7: Domain Protocols

### User Request
> Implement Task 7: create domain protocol files (SpriteProviding, EnvironmentDetecting) and ScreenEdge enum in Domain/Protocols directory.

### Decisions
- `SpriteProviding` is `AnyObject` only (no `Sendable`) since concrete implementations will wrap NSImage
- `EnvironmentDetecting` is `AnyObject` only, returns domain types (`WalkableSurface`, `Rect`, `ScreenEdge`)
- `ScreenEdge` is a simple `Sendable` enum (left/right/top/bottom)
- All types are public with zero framework imports — pure domain ports

### What Was Done
- Created `Familiar/Domain/Protocols/ScreenEdge.swift` — enum for screen edge identification
- Created `Familiar/Domain/Protocols/SpriteProviding.swift` — protocol for sprite sheet access (frameCount, frameWidth, frameHeight, isFlipped, flipAllFrames)
- Created `Familiar/Domain/Protocols/EnvironmentDetecting.swift` — protocol for environment queries (detectSurfaces, isFullScreenActive, currentScreenFrame, currentVisibleFrame, hasAdjacentScreen)
- All quality checks pass (SwiftLint, SwiftFormat, build, 44 tests passing)

---

## 2026-04-04 — Task 8: AnimationStateMachine (TDD)

### User Request
> Implement Task 8: AnimationStateMachine — the core engine that drives all pet behavior, with full TDD.

### Decisions
- Delegate protocol (`AnimationStateMachineDelegate`) with 6 callbacks: frame change, movement, opacity, interval, respawn, flip
- `setAnimationForTesting(_:)` public method exposed for test setup (avoids needing to go through respawn in every test)
- Special animations (fall, drag, kill) resolved by name at init time
- Direction convention: `isMovingLeft` controls sign of dx; when not moving left, dx is negated
- Border type mapping: screenBottom -> taskbar, screenLeft/Right -> vertical, screenTop -> horizontal, windowTop -> window
- No `Sendable` conformance needed — accessed from main thread only

### What Was Done
- Created `Familiar/Domain/Engine/AnimationStateMachine.swift`:
  - `AnimationStateMachineDelegate` protocol with 6 delegate methods
  - `AnimationStateMachine` class with tick loop, spawn, drag/fall/kill handling, flip action, opacity/interval interpolation
  - Resolves special animation IDs (fall, drag, kill) by name at init
  - `borderType(from:)` maps `SurfaceType` to `BorderType` for transition filtering
- Created `FamiliarTests/Domain/AnimationStateMachineTests.swift` — 10 tests:
  1. `respawnSetsInitialAnimation` — verifies spawn resolves to correct animation
  2. `tickReportsFrameIndex` — verifies delegate receives correct frame indices
  3. `tickAdvancesStep` — verifies animationStep increments each tick
  4. `sequenceCompletionTransitions` — verifies transition to next animation after totalSteps
  5. `dragStartSwitchesToDragAnimation` — verifies handleDragStart sets drag animation
  6. `dragEndSwitchesToFallAnimation` — verifies handleDragEnd sets fall animation
  7. `killSwitchesToKillAnimation` — verifies handleKill sets kill animation
  8. `flipActionTogglesDirection` — verifies flip action toggles isMovingLeft and notifies delegate
  9. `tickReportsMovement` — verifies dx/dy reported when non-zero
  10. `respawnWithNoSpawnsDoesNotCrash` — verifies empty spawns handled gracefully
- All quality checks pass (SwiftLint, SwiftFormat, build, 54 tests passing)

---

## 2026-04-04 — Task 10: XML Animation Parser (TDD)

### User Request
> Implement Task 10: XML Animation Parser — create an XML parser that reads eSheep XML animation format and produces domain model types.

### Decisions
- Used Foundation's `XMLParser` with delegate pattern (path-tracking approach)
- Fully qualified `FamiliarDomain.Expression` to avoid ambiguity with Foundation.Expression on macOS 15+
- Parser returns `(PetAnimationData, String)` tuple — domain data + raw base64 PNG string
- Border type mapping from `only` attribute: "0"/empty -> .none, "1" -> .taskbar, "2" -> .window, "4" -> .horizontal, "6" -> .horizontalPlus, "8" -> .vertical
- Expression creation: isDynamic from "random"/"randS"/"imageX"/"imageY", isScreenDependent from "screenW"/"screenH"/"areaW"/"areaH"
- `@unchecked Sendable` on parser class since it's stateful but used synchronously

### What Was Done
- Deleted `Familiar/Infrastructure/Placeholder.swift` and `FamiliarTests/Infrastructure/PlaceholderTests.swift`
- Created `FamiliarTests/Infrastructure/XMLAnimationParserTests.swift` — 9 tests with inline XML:
  1. `parsesHeader` — verifies petName, author, title, version, info
  2. `parsesSpriteInfo` — verifies tilesX/tilesY
  3. `extractsBase64PNG` — verifies base64 PNG extraction from CDATA
  4. `parsesSpawns` — verifies spawn id, probability, expressions, next animations
  5. `parsesAnimations` — verifies 2 animations with frames, repeatFrom, endAnimation transitions
  6. `parsesMovementExpressions` — verifies start/end movement expression values and opacity
  7. `parsesBorderAndGravity` — verifies border types (.horizontal, .window) and gravity transitions
  8. `invalidXMLThrows` — verifies XMLParseError on invalid input
  9. `emptyDataThrows` — verifies XMLParseError on empty data
- Created `Familiar/Infrastructure/XMLAnimationParser.swift`:
  - `XMLParseError` enum with `invalidFormat` and `missingElement` cases
  - `XMLAnimationParser` class implementing `XMLParserDelegate` with path-tracking approach
  - Parses header, image, spawns, animations (with start/end movements, sequence, border, gravity), and children
  - `makeExpression` helper for dynamic/screen-dependent detection
  - `parseBorderType` helper for `only` attribute mapping
  - `resetState` for parser reuse
- All quality checks pass (SwiftLint, SwiftFormat, build, 63 tests passing)

---

## 2026-04-04 — Task 12: Environment Detector

### User Request
> Implement Task 12: EnvironmentDetector — Infrastructure layer class that detects screen edges and window positions for pets to walk on.

### Decisions
- No unit tests — depends on real system state (screen geometry, window list) which can't be meaningfully mocked
- Split `detectSurfaces()` into `screenEdgeSurfaces()` and `windowTopSurfaces()` private helpers to stay under SwiftLint's 50-line function body limit
- `registerOwnPanel`/`unregisterOwnPanel` methods allow excluding the pet's own panels from window detection
- Coordinate conversion via `toNSCoords()` handles CoreGraphics (top-left origin) to AppKit (bottom-left origin) translation
- Screen Recording permission check: if any window name is readable, permission is granted

### What Was Done
- Created `Familiar/Infrastructure/EnvironmentDetector.swift`:
  - Implements `EnvironmentDetecting` domain protocol
  - `detectSurfaces()` returns screen edge surfaces (bottom/left/right/top for each screen) plus window top edges (when Screen Recording permission is available)
  - `isFullScreenActive()` checks if frontmost app has a window covering the full screen
  - `currentScreenFrame()` / `currentVisibleFrame()` return main screen geometry as domain `Rect`
  - `hasAdjacentScreen(at:)` checks for multi-monitor setups
  - `detectScreenEdgesOnly()` convenience method filters out window surfaces
- All quality checks pass (SwiftLint, SwiftFormat, build)

---

## 2026-04-04 — Task 11: Sprite Sheet Loader (TDD)

**Request:** Implement `SpriteSheetLoader` that decodes a base64 PNG sprite sheet into individual frames, conforming to the `SpriteProviding` domain protocol.

**Decisions:**
- Used TDD approach: wrote tests first, verified they failed, then wrote implementation
- Created test PNG programmatically using `NSBitmapImageRep` with exact pixel dimensions (not `NSImage(size:)`) to avoid Retina scaling issues in CI/test environments
- Stored tile dimensions as pixel integers from CGImage (not NSImage point-based size) for accurate `frameWidth`/`frameHeight`
- `image(at:)` is Infrastructure-only (not part of the domain protocol), used by Presentation layer with concrete type

**What was done:**
- Created `Familiar/Infrastructure/SpriteSheetLoader.swift`:
  - Decodes base64 string to PNG data, then slices into grid of frames (row by row, left to right, top to bottom)
  - Supports horizontal flip with lazy caching (`flippedFramesCache`)
  - Clamps out-of-bounds frame indices
  - Throws `SpriteSheetError.invalidBase64` or `.invalidImage` on bad input
- Created `FamiliarTests/Infrastructure/SpriteSheetLoaderTests.swift` with 7 tests:
  - Frame count, dimensions, flip toggle, valid/invalid index access, invalid base64, single tile
- All 70 tests pass, all quality checks pass
