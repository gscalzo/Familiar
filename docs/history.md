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
