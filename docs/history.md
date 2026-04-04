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
