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
