# Pluggable Animations & `fam` CLI Design

**Date:** 2026-04-04
**Status:** Approved

---

## Goal

Make the desktop pet controllable via a lightweight CLI (`fam`) so external tools — especially agent hooks — can set the pet's mood and trigger animation events. Each agent session can spawn its own named pet.

## Architecture

```
┌──────────┐     ~/.familiar/state.json     ┌──────────────┐
│  fam CLI  │ ──────── writes ──────────────>│  Familiar App │
│ (Swift)   │                                │               │
│           │  ~/.familiar/animations.json   │  reads every  │
│           │<──────── reads ───────────────>│  50ms tick    │
└──────────┘                                └──────────────┘
```

No IPC, no sockets. File-based protocol. Any language can write the state file.

## State File Protocol

`~/.familiar/state.json` — dictionary of named pets:

```json
{
  "default": { "mood": "chill", "event": null, "eventTimestamp": null },
  "agent-1234": { "mood": "work", "event": "yay", "eventTimestamp": "2026-04-04T17:45:00Z" }
}
```

- **mood**: persistent background state (string)
- **event**: one-shot reaction, consumed by app (string or null)
- **eventTimestamp**: ISO 8601, used to avoid replaying stale events

The app clears `event` and `eventTimestamp` after consuming them.

Pet lifecycle:
- First command with a name auto-creates the pet (lazy spawn)
- `kill` removes the key; app closes the panel on next tick
- Missing file or empty `{}` → single default pet in `chill` mood

## Animation Mapping Config

`~/.familiar/animations.json`:

```json
{
  "moods": {
    "chill": ["walk"],
    "think": ["sleep 1a", "sleep 2a"],
    "work": ["run"],
    "wait": ["eat"],
    "sleep": ["sleep 3a"]
  },
  "events": {
    "yay": ["bath a"],
    "oops": ["fall"],
    "hmm": ["boing"],
    "go": ["jump"],
    "done": ["flower"]
  }
}
```

- Arrays allow random selection from multiple animations
- App writes default config on first launch if file missing
- Users can add custom mappings without recompiling
- Unknown mood/event names fall back to `chill`

Resolution: mood name → animation name list → pick random → match against eSheep XML `<name>` → animation ID.

## `fam` CLI

```
fam — control your desktop pet

USAGE:
  fam <command> [name]

  name is optional. Omit for default pet.
  Named pets are created automatically on first command.

MOODS (persistent):
  fam chill [name]       idle / normal wandering
  fam think [name]       contemplating
  fam work [name]        busy, running
  fam wait [name]        patient, munching
  fam sleep [name]       deep sleep

EVENTS (one-shot, returns to mood):
  fam yay [name]         celebration
  fam oops [name]        stumble
  fam hmm [name]         warning bump
  fam go [name]          energetic start
  fam done [name]        happy finish

LIFECYCLE:
  fam kill [name]        remove a pet
  fam kill --all         remove all pets

STATUS:
  fam                    list all pets + moods
  fam log [name]         recent events

AGENT HOOK EXAMPLE:
  "PreToolUse": "fam think $$",
  "PostToolUse": "fam work $$",
  "Stop": "fam kill $$"
```

`$$` is the shell PID — unique per agent session, stable across hooks.

## Implementation: SPM Target

```swift
// Package.swift
.executableTarget(
    name: "fam",
    path: "Tools/fam"
)
```

Single file `Tools/fam/main.swift` (~120 lines). No dependencies beyond Foundation. Reads/writes JSON, exits.

Install: `swift build && cp .build/debug/fam /usr/local/bin/fam`

## App Changes

### New: StateFileWatcher (Infrastructure)

- Reads `~/.familiar/state.json` each tick
- Returns `[String: PetState]`
- Handles missing file, corrupt JSON, locked file (falls back to last known state)

### New: AnimationMapper (Domain)

- Loads `~/.familiar/animations.json`
- `resolve(mood:, in:) -> Int?` maps mood name → random animation name → animation ID
- `resolveEvent(event:, in:) -> Int?` same for events
- Pure logic, no framework imports
- Falls back to `chill` for unknown names

### Modified: PetManager

Tick loop becomes:
1. Read state file via StateFileWatcher
2. Reconcile pets: spawn new keys, kill removed keys
3. For each pet: detect mood/event changes, resolve via AnimationMapper
4. Tick each pet's state machine
5. Check bounds

### Modified: AnimationStateMachine

- New method: `setMoodAnimation(_ id: Int)` — switches to animation, loops
- New method: `playEventAnimation(_ id: Int, then moodId: Int)` — plays once, returns to mood
- Current `respawn()` becomes the entry point for new pets in `chill` mood

## File Structure

```
Tools/
  fam/
    main.swift                    # CLI entry point

Familiar/
  Domain/
    Engine/
      AnimationMapper.swift       # mood/event → animation ID resolution
  Infrastructure/
    StateFileWatcher.swift        # reads ~/.familiar/state.json
  App/
    PetManager.swift              # modified: reconcile from state file

~/.familiar/
  state.json                      # pet states (written by fam, read by app)
  animations.json                 # mood/event → animation name mapping
```

## No External Dependencies

- fam CLI: Foundation only
- StateFileWatcher: Foundation only
- AnimationMapper: no imports (domain layer)
- Chart.js CDN for metrics dashboard (already exists)
