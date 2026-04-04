# Pluggable Animations & `fam` CLI Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make the desktop pet controllable via a `fam` CLI so agent hooks can set moods and trigger animation events, with each agent session spawning its own named pet.

**Architecture:** File-based IPC via `~/.familiar/state.json`. CLI writes, app reads every tick. Animation mapping via `~/.familiar/animations.json`. Domain-layer AnimationMapper resolves mood/event names to animation IDs. New `fam` SPM executable target.

**Tech Stack:** Swift 6.0, Foundation, Swift Testing, no external dependencies.

**Design Reference:** `docs/plans/2026-04-04-pluggable-animations-design.md`

---

## Task 1: PetState model + AnimationConfig model (Domain)

**Files:**
- Create: `Familiar/Domain/Model/PetState.swift`
- Create: `Familiar/Domain/Model/AnimationConfig.swift`
- Test: `FamiliarTests/Domain/PetStateTests.swift`

**Step 1: Write failing tests**

```swift
import Testing
import Foundation
@testable import FamiliarDomain

@Suite("PetState")
struct PetStateTests {
    @Test func decodesFromJSON() throws {
        let json = """
        {"mood": "work", "event": "yay", "eventTimestamp": "2026-04-04T17:45:00Z"}
        """
        let state = try JSONDecoder().decode(PetState.self, from: Data(json.utf8))
        #expect(state.mood == "work")
        #expect(state.event == "yay")
        #expect(state.eventTimestamp != nil)
    }

    @Test func decodesWithNullEvent() throws {
        let json = """
        {"mood": "chill", "event": null, "eventTimestamp": null}
        """
        let state = try JSONDecoder().decode(PetState.self, from: Data(json.utf8))
        #expect(state.mood == "chill")
        #expect(state.event == nil)
    }

    @Test func encodesRoundTrip() throws {
        let state = PetState(mood: "think", event: "go", eventTimestamp: Date())
        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(PetState.self, from: data)
        #expect(decoded.mood == "think")
        #expect(decoded.event == "go")
    }

    @Test func defaultStateIsChill() {
        let state = PetState.default
        #expect(state.mood == "chill")
        #expect(state.event == nil)
    }
}
```

**Step 2: Run to verify failure**

Run: `swift test --filter PetState`
Expected: FAIL — PetState not found

**Step 3: Implement PetState and AnimationConfig**

`Familiar/Domain/Model/PetState.swift`:

```swift
public struct PetState: Codable, Sendable {
    public var mood: String
    public var event: String?
    public var eventTimestamp: Date?

    public init(mood: String, event: String? = nil, eventTimestamp: Date? = nil) {
        self.mood = mood
        self.event = event
        self.eventTimestamp = eventTimestamp
    }

    public static let `default` = PetState(mood: "chill")
}
```

`Familiar/Domain/Model/AnimationConfig.swift`:

```swift
public struct AnimationConfig: Codable, Sendable {
    public var moods: [String: [String]]
    public var events: [String: [String]]

    public init(moods: [String: [String]], events: [String: [String]]) {
        self.moods = moods
        self.events = events
    }

    public static let `default` = AnimationConfig(
        moods: [
            "chill": ["walk"],
            "think": ["sleep 1a", "sleep 2a"],
            "work": ["run"],
            "wait": ["eat"],
            "sleep": ["sleep 3a"],
        ],
        events: [
            "yay": ["bath a"],
            "oops": ["fall"],
            "hmm": ["boing"],
            "go": ["jump"],
            "done": ["flower"],
        ]
    )
}
```

**Step 4: Run tests**

Run: `swift test`
Expected: All pass

**Step 5: Commit**

```
feat: add PetState and AnimationConfig domain models
```

---

## Task 2: AnimationMapper (Domain, TDD)

**Files:**
- Create: `Familiar/Domain/Engine/AnimationMapper.swift`
- Test: `FamiliarTests/Domain/AnimationMapperTests.swift`

**Step 1: Write failing tests**

```swift
import Testing
@testable import FamiliarDomain

@Suite("AnimationMapper")
struct AnimationMapperTests {
    // Build a minimal animation dictionary for testing
    static let testAnimations: [Int: Animation] = {
        func anim(id: Int, name: String) -> Animation {
            let mov = Movement(
                x: .constant(0), y: .constant(0),
                interval: .constant(100), offsetY: 0, opacity: 1.0
            )
            let seq = AnimationSequence(
                frames: [0], repeatCount: .constant(0),
                repeatFrom: 0, action: nil
            )
            return Animation(
                id: id, name: name, start: mov, end: mov, sequence: seq,
                endAnimation: [], endBorder: [], endGravity: []
            )
        }
        return [
            1: anim(id: 1, name: "walk"),
            5: anim(id: 5, name: "fall"),
            7: anim(id: 7, name: "run"),
            15: anim(id: 15, name: "sleep 1a"),
            16: anim(id: 16, name: "sleep 2a"),
            21: anim(id: 21, name: "bath a"),
            25: anim(id: 25, name: "jump"),
            26: anim(id: 26, name: "eat"),
            27: anim(id: 27, name: "flower"),
            8: anim(id: 8, name: "boing"),
        ]
    }()

    let config = AnimationConfig.default

    @Test func resolvesMoodToAnimationID() {
        let id = AnimationMapper.resolve(
            mood: "work", config: config, animations: Self.testAnimations
        )
        #expect(id == 7) // "run" -> id 7
    }

    @Test func resolvesMoodWithMultipleOptions() {
        // "think" -> ["sleep 1a", "sleep 2a"] -> id 15 or 16
        let id = AnimationMapper.resolve(
            mood: "think", config: config, animations: Self.testAnimations
        )
        #expect(id == 15 || id == 16)
    }

    @Test func unknownMoodFallsToChill() {
        let id = AnimationMapper.resolve(
            mood: "unknown", config: config, animations: Self.testAnimations
        )
        #expect(id == 1) // "chill" -> "walk" -> id 1
    }

    @Test func resolvesEventToAnimationID() {
        let id = AnimationMapper.resolveEvent(
            event: "yay", config: config, animations: Self.testAnimations
        )
        #expect(id == 21) // "bath a" -> id 21
    }

    @Test func unknownEventReturnsNil() {
        let id = AnimationMapper.resolveEvent(
            event: "unknown", config: config, animations: Self.testAnimations
        )
        #expect(id == nil)
    }
}
```

**Step 2: Run to verify failure**

Run: `swift test --filter AnimationMapper`
Expected: FAIL

**Step 3: Implement AnimationMapper**

```swift
public enum AnimationMapper {
    public static func resolve(
        mood: String,
        config: AnimationConfig,
        animations: [Int: Animation]
    ) -> Int? {
        let names = config.moods[mood] ?? config.moods["chill"] ?? ["walk"]
        return pickAnimation(from: names, in: animations)
    }

    public static func resolveEvent(
        event: String,
        config: AnimationConfig,
        animations: [Int: Animation]
    ) -> Int? {
        guard let names = config.events[event] else { return nil }
        return pickAnimation(from: names, in: animations)
    }

    private static func pickAnimation(
        from names: [String],
        in animations: [Int: Animation]
    ) -> Int? {
        guard !names.isEmpty else { return nil }
        let name = names.randomElement()!
        return animations.values.first(where: { $0.name == name })?.id
    }
}
```

**Step 4: Run tests**

Run: `swift test`
Expected: All pass

**Step 5: Commit**

```
feat: add AnimationMapper resolving mood/event names to animation IDs
```

---

## Task 3: AnimationStateMachine — mood and event support

**Files:**
- Modify: `Familiar/Domain/Engine/AnimationStateMachine.swift`
- Test: `FamiliarTests/Domain/AnimationStateMachineTests.swift` (add tests)

**Step 1: Write failing tests**

Add to existing `AnimationStateMachineTests.swift`:

```swift
@Test("setMoodAnimation switches to specified animation and loops")
func setMoodAnimationLoops() {
    let walk = makeAnimation(id: 1, frames: [0, 1, 2], endAnimation: [
        NextAnim(animationId: 1, probability: 100, only: .none)
    ])
    let run = makeAnimation(id: 7, frames: [10, 11], endAnimation: [
        NextAnim(animationId: 7, probability: 100, only: .none)
    ])
    let sm = AnimationStateMachine(
        animations: [1: walk, 7: run], spawns: [],
        expressionContext: { defaultContext }
    )
    let delegate = MockDelegate()
    sm.delegate = delegate

    sm.setMoodAnimation(7)
    #expect(sm.currentAnimationID == 7)

    // Tick through the full sequence — should loop back to 7
    for _ in 0 ..< 10 {
        sm.tick(currentSurface: nil)
    }
    #expect(sm.currentAnimationID == 7)
}

@Test("playEventAnimation plays once then returns to mood")
func playEventAnimationReturnToMood() {
    let walk = makeAnimation(id: 1, frames: [0, 1], endAnimation: [
        NextAnim(animationId: 1, probability: 100, only: .none)
    ])
    let jump = makeAnimation(id: 25, frames: [20, 21], endAnimation: [])
    let sm = AnimationStateMachine(
        animations: [1: walk, 25: jump], spawns: [],
        expressionContext: { defaultContext }
    )
    let delegate = MockDelegate()
    sm.delegate = delegate

    sm.setMoodAnimation(1)
    sm.playEventAnimation(25, returnToMood: 1)
    #expect(sm.currentAnimationID == 25)

    // Tick through event animation — should return to mood (1)
    for _ in 0 ..< 10 {
        sm.tick(currentSurface: nil)
    }
    #expect(sm.currentAnimationID == 1)
}
```

**Step 2: Run to verify failure**

Run: `swift test --filter AnimationStateMachine`
Expected: FAIL — `setMoodAnimation` and `playEventAnimation` not found

**Step 3: Implement**

Add to `AnimationStateMachine`:

```swift
// Mood animation ID to return to after events
private var moodAnimationID: Int?
private var returnToMoodID: Int?

public func setMoodAnimation(_ id: Int) {
    moodAnimationID = id
    returnToMoodID = nil
    setAnimation(id)
}

public func playEventAnimation(_ id: Int, returnToMood moodId: Int) {
    returnToMoodID = moodId
    setAnimation(id)
}
```

Modify `handleSequenceComplete` to check `returnToMoodID`:

```swift
private func handleSequenceComplete(_ anim: Animation, currentSurface: SurfaceType?) {
    // If returning from event animation, go back to mood
    if let moodId = returnToMoodID {
        returnToMoodID = nil
        setAnimation(moodId)
        return
    }

    let borderContext = borderType(from: currentSurface)
    if let nextId = TransitionPicker.pick(from: anim.endAnimation, context: borderContext) {
        setAnimation(nextId)
    } else if let moodId = moodAnimationID {
        // No transition available — loop mood animation
        setAnimation(moodId)
    } else {
        respawn()
    }
}
```

**Step 4: Run tests**

Run: `swift test`
Expected: All pass

**Step 5: Commit**

```
feat: add mood and event animation support to AnimationStateMachine
```

---

## Task 4: StateFileWatcher (Infrastructure, TDD)

**Files:**
- Create: `Familiar/Infrastructure/StateFileWatcher.swift`
- Test: `FamiliarTests/Infrastructure/StateFileWatcherTests.swift`

**Step 1: Write failing tests**

```swift
import Testing
import Foundation
@testable import FamiliarDomain
@testable import FamiliarInfrastructure

@Suite("StateFileWatcher")
struct StateFileWatcherTests {
    let tempDir = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)

    @Test func readsMissingFileAsEmpty() {
        let watcher = StateFileWatcher(
            directory: tempDir.path
        )
        let states = watcher.readStates()
        #expect(states.isEmpty)
    }

    @Test func readsValidStateFile() throws {
        try FileManager.default.createDirectory(
            at: tempDir, withIntermediateDirectories: true
        )
        let json = """
        {
          "default": {"mood": "work", "event": null, "eventTimestamp": null}
        }
        """
        try json.write(
            to: tempDir.appendingPathComponent("state.json"),
            atomically: true, encoding: .utf8
        )

        let watcher = StateFileWatcher(directory: tempDir.path)
        let states = watcher.readStates()
        #expect(states["default"]?.mood == "work")
        #expect(states["default"]?.event == nil)
    }

    @Test func handlesCorruptJSON() throws {
        try FileManager.default.createDirectory(
            at: tempDir, withIntermediateDirectories: true
        )
        try "not json".write(
            to: tempDir.appendingPathComponent("state.json"),
            atomically: true, encoding: .utf8
        )

        let watcher = StateFileWatcher(directory: tempDir.path)
        let states = watcher.readStates()
        #expect(states.isEmpty)
    }

    @Test func clearsEventAfterConsuming() throws {
        try FileManager.default.createDirectory(
            at: tempDir, withIntermediateDirectories: true
        )
        let json = """
        {
          "default": {"mood": "work", "event": "yay", "eventTimestamp": "2026-04-04T17:45:00Z"}
        }
        """
        let stateFile = tempDir.appendingPathComponent("state.json")
        try json.write(to: stateFile, atomically: true, encoding: .utf8)

        let watcher = StateFileWatcher(directory: tempDir.path)
        watcher.clearEvent(forPet: "default")

        let data = try Data(contentsOf: stateFile)
        let states = try JSONDecoder().decode([String: PetState].self, from: data)
        #expect(states["default"]?.event == nil)
        #expect(states["default"]?.mood == "work") // mood preserved
    }

    @Test func readsAnimationConfig() throws {
        try FileManager.default.createDirectory(
            at: tempDir, withIntermediateDirectories: true
        )
        let json = """
        {"moods": {"chill": ["walk"]}, "events": {"yay": ["bath a"]}}
        """
        try json.write(
            to: tempDir.appendingPathComponent("animations.json"),
            atomically: true, encoding: .utf8
        )

        let watcher = StateFileWatcher(directory: tempDir.path)
        let config = watcher.readAnimationConfig()
        #expect(config.moods["chill"] == ["walk"])
        #expect(config.events["yay"] == ["bath a"])
    }

    @Test func missingAnimationConfigReturnsDefault() {
        let watcher = StateFileWatcher(directory: tempDir.path)
        let config = watcher.readAnimationConfig()
        #expect(config.moods["chill"] == ["walk"])
    }
}
```

**Step 2: Run to verify failure**

Run: `swift test --filter StateFileWatcher`
Expected: FAIL

**Step 3: Implement StateFileWatcher**

```swift
import Foundation
import FamiliarDomain

public final class StateFileWatcher {
    private let stateURL: URL
    private let configURL: URL
    private let directory: URL

    public init(directory: String = NSHomeDirectory() + "/.familiar") {
        self.directory = URL(fileURLWithPath: directory)
        self.stateURL = self.directory.appendingPathComponent("state.json")
        self.configURL = self.directory.appendingPathComponent("animations.json")
    }

    public func readStates() -> [String: PetState] {
        guard let data = try? Data(contentsOf: stateURL),
              let states = try? JSONDecoder().decode([String: PetState].self, from: data)
        else { return [:] }
        return states
    }

    public func clearEvent(forPet name: String) {
        guard var states = try? JSONDecoder().decode(
            [String: PetState].self,
            from: Data(contentsOf: stateURL)
        ) else { return }
        states[name]?.event = nil
        states[name]?.eventTimestamp = nil
        if let data = try? JSONEncoder().encode(states) {
            try? data.write(to: stateURL)
        }
    }

    public func readAnimationConfig() -> AnimationConfig {
        guard let data = try? Data(contentsOf: configURL),
              let config = try? JSONDecoder().decode(AnimationConfig.self, from: data)
        else { return .default }
        return config
    }

    public func writeDefaultConfigIfNeeded() {
        guard !FileManager.default.fileExists(atPath: configURL.path) else { return }
        try? FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true
        )
        if let data = try? JSONEncoder().encode(AnimationConfig.default) {
            try? data.write(to: configURL)
        }
    }
}
```

**Step 4: Run tests**

Run: `swift test`
Expected: All pass

**Step 5: Commit**

```
feat: add StateFileWatcher for reading pet states and animation config
```

---

## Task 5: `fam` CLI executable

**Files:**
- Modify: `Package.swift` (add fam target)
- Create: `Tools/fam/main.swift`

**Step 1: Add fam target to Package.swift**

Add to targets array:

```swift
.executableTarget(
    name: "fam",
    path: "Tools/fam"
),
```

**Step 2: Implement `Tools/fam/main.swift`**

The full CLI (~130 lines). Handles:
- `fam` (no args) — list all pets
- `fam <mood> [name]` — set mood (chill/think/work/wait/sleep)
- `fam <event> [name]` — trigger event (yay/oops/hmm/go/done)
- `fam kill [name]` / `fam kill --all` — remove pets
- `fam log [name]` — show recent events (reads from state file timestamps)
- `fam help` — show usage

The CLI reads/writes `~/.familiar/state.json`. It creates the file and directory if missing. Named pets are auto-created on first command.

Moods: `chill`, `think`, `work`, `wait`, `sleep`
Events: `yay`, `oops`, `hmm`, `go`, `done`

**Step 3: Build and verify**

Run: `swift build`
Expected: Both `FamiliarApp` and `fam` build

**Step 4: Manual test**

```bash
.build/debug/fam              # should print "No pets"
.build/debug/fam work         # creates default pet with mood "work"
.build/debug/fam              # should show "default: work"
.build/debug/fam yay          # triggers event
.build/debug/fam think bob    # creates pet "bob" with mood "think"
.build/debug/fam              # shows both pets
.build/debug/fam kill bob     # removes "bob"
cat ~/.familiar/state.json    # verify JSON
```

**Step 5: Commit**

```
feat: add fam CLI for controlling pet moods and events
```

---

## Task 6: Integrate StateFileWatcher into PetManager

**Files:**
- Modify: `Familiar/App/PetManager.swift`
- Modify: `Familiar/App/AppDelegate.swift`
- Modify: `Familiar/App/Presentation/PetInstance.swift`

**Step 1: Add state file reconciliation to PetManager**

PetManager changes:
- Add `StateFileWatcher` and `AnimationConfig` as properties
- Add `petNames: [UUID: String]` mapping pet IDs to state file keys
- In `tickAllPets()`, before ticking: read state file, reconcile pets
- Reconcile: spawn new keys, kill removed keys, update moods/events
- On mood change: resolve via AnimationMapper, call `setMoodAnimation`
- On event present: resolve via AnimationMapper, call `playEventAnimation`, then clear event

Add a `name` property to PetInstance so we can track which state file key each pet belongs to.

**Step 2: Modify AppDelegate**

In `applicationDidFinishLaunching`:
- Call `stateFileWatcher.writeDefaultConfigIfNeeded()` to create `~/.familiar/animations.json` on first launch
- If no state file exists, create one with `{"default": {"mood": "chill"}}` and spawn the default pet
- If state file exists, let the tick loop handle reconciliation

**Step 3: Build and test manually**

Run `FamiliarApp`, then in another terminal:
```bash
.build/debug/fam work         # sheep should start running
.build/debug/fam yay          # sheep celebrates, returns to running
.build/debug/fam think agent  # second sheep appears, contemplating
.build/debug/fam kill agent   # second sheep disappears
```

**Step 4: Commit**

```
feat: integrate StateFileWatcher into PetManager for CLI-driven pets
```

---

## Task 7: Quality checks + history + push

**Step 1: Run quality checks**

Run: `./scripts/check.sh all`
Expected: ALL CHECKS PASSED

**Step 2: Fix any failures**

**Step 3: Update docs/history.md**

**Step 4: Commit and push**

```
chore: quality checks, update history
```

Then `git push` (triggers pre-push metrics collection).

---

## Dependency Graph

```
Task 1 (PetState + AnimationConfig models)
  → Task 2 (AnimationMapper, depends on models)
  → Task 3 (StateMachine mood/event, depends on models)
  → Task 4 (StateFileWatcher, depends on models)
    → Task 5 (fam CLI, independent but needs state.json format)
      → Task 6 (Integration, depends on 2+3+4+5)
        → Task 7 (Quality + push)
```

Tasks 2, 3, 4 can run in parallel after Task 1.
Task 5 can run in parallel with Tasks 2-4.
