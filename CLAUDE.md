# Project Rules

## Design Documents

- Always save and update design plans in `docs/plans/`.
- Before starting implementation of a new feature or major change, ensure a plan exists in `docs/plans/`.
- When a plan is updated during implementation, update the file in `docs/plans/` to reflect the current state.

## Implementation History

- Record every user prompt/instruction in `docs/history.md` with a timestamp.
- Each entry should capture: the user's request, key decisions made, and what was done.
- This file serves as a chronological log of the project's evolution.
- Append new entries at the bottom of the file, never overwrite previous entries.

## Tech Stack

- Swift, SwiftUI, AppKit (NSPanel), CoreGraphics
- macOS 15 (Sequoia)+ target
- No external dependencies
- Clean Architecture: Domain (framework-free) / Infrastructure / Presentation / App

## Coding Standards

- Use `@Observable` (not `ObservableObject`) for state management
- Use Swift Testing framework (not XCTest) for new tests
- Domain layer must have zero framework imports (no AppKit, no CoreGraphics)
- All initialization in `AppDelegate.applicationDidFinishLaunching`, not in SwiftUI `onAppear`
- Single shared timer for all pets, not per-pet timers

## Quality Checks (MANDATORY)

Before considering a session done, ALL of these must pass:

1. **SwiftLint** -- `swiftlint lint --quiet` (zero warnings/errors)
2. **SwiftFormat** -- `swiftformat --lint Familiar/` (zero formatting issues)
3. **Build** -- `swift build` or `xcodebuild` succeeds
4. **Tests** -- `swift test` or `xcodebuild test` passes

Run `./scripts/check.sh` to verify all at once.

### Hooks in Place

- **PostToolUse (Write|Edit)**: Auto-formats `.swift` files with SwiftFormat after every write/edit
- **Stop**: Reminds to run `./scripts/check.sh` before ending session
- **Git pre-commit**: Blocks commits if SwiftLint or SwiftFormat fail on staged `.swift` files

### Session End Protocol

1. Run `./scripts/check.sh all`
2. Fix any failures
3. Commit all changes with a descriptive message
4. Update `docs/history.md` with session summary
