# Desktop Pet Research - Comprehensive Resource Directory

## Reference Projects

| Project | URL | Tech | Notes |
|---------|-----|------|-------|
| **eSheep 64bit** | github.com/Adrianotiger/desktopPet | C# / .NET | Gold standard. XML-driven animations, 54 states, window walking, child pets, sounds |
| **desktoppet.app** | desktoppet.app | Unity (likely) | Commercial. AI chat, Pomodoro, reminders. ~191MB macOS |
| **Original eSheep** | mentadd.com/sheep | Win32 | 1995 classic by Tatsutoshi Nomura. Poe + Merry characters |
| **pet-therapy** | github.com/Chuck-Ray/pet-therapy | Swift/SwiftUI | Mac App Store. Window detection, Aseprite sprites, modular packages |
| **Cat** | github.com/mmar/Cat | Swift/SpriteKit/GameplayKit | Mouse following, retina |
| **ScreenPets** | github.com/sealovesky/ScreenPets | Swift | Menu bar app |
| **Shimeji-ee** | kilkakon.com/shimeji | Java | Community pet ecosystem |
| **Shijima** | getshijima.app | Cross-platform | Modern Shimeji replacement |
| **web-esheep** | github.com/Adrianotiger/web-esheep | JS | Browser version of eSheep |

---

## eSheep XML Animation Format (Complete Schema)

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
    <tilesx>int (sprite sheet columns)</tilesx>
    <tilesy>int (sprite sheet rows)</tilesy>
    <png>base64 PNG sprite sheet in CDATA</png>
    <transparency>color name (e.g. "Magenta")</transparency>
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
        <x>expression</x>
        <y>expression</y>
        <interval>expression (ms)</interval>
        <offsety>int (default 0)</offsety>
        <opacity>double (default 1.0)</opacity>
      </start>
      <end>
        <x>expression</x>
        <y>expression</y>
        <interval>expression (ms)</interval>
        <offsety>int (default 0)</offsety>
        <opacity>double (default 1.0)</opacity>
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
      <x>expression</x>
      <y>expression</y>
      <next>animation_id</next>
    </child>
  </childs>

  <sounds>
    <sound animationid="int">
      <probability>int (0-100)</probability>
      <loop>int (0=once)</loop>
      <base64>base64 MP3</base64>
    </sound>
  </sounds>
</animations>
```

### Expression Variables
- `screenW`, `screenH` -- full screen dimensions
- `areaW`, `areaH` -- working area (minus dock/menubar)
- `imageW`, `imageH` -- sprite frame dimensions
- `imageX`, `imageY` -- parent pet position (for children)
- `random` -- 0-99, re-evaluated each use
- `randS` -- 10-89, fixed per session
- `scale` -- HiDPI scale factor
- Full arithmetic: `random*(screenW-imageW-50)/100+25`

### Border Types (`only` attribute)
- `none` (0x7F) -- always matches
- `taskbar` (0x01) -- on dock/taskbar
- `window` (0x02) -- on a window
- `horizontal` (0x04) -- top/bottom screen edge
- `horizontal+` (0x06) -- horizontal OR window
- `vertical` (0x08) -- left/right screen edge

### Special Animation Names
- `fall` -- played after drag release
- `drag` -- played while user holds pet
- `kill` -- played on app close (fades out)
- `sync` -- synchronization dance

---

## Complete Animation State List (54 Animations)

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
| 15-16 | sleep1a/b | Sleep variant 1 |
| 17-18 | sleep2a/b | Sleep variant 2 |
| 19-20 | sleep3a/b | Sleep variant 3 (longest) |
| 21-24 | bath a/b/w/z | Bathing sequence |
| 25 | jump | Jump up |
| 26 | eat | Eating |
| 27 | flower | Flower interaction |
| 28-34 | blacksheep a-z | Black sheep companion (child) |
| 35 | run_begin | Start running |
| 36 | run_end | Stop running |
| 37 | vertical_walk_up | Climb up screen edge |
| 38-40 | top_walk 1-3 | Walking upside down at top |
| 41 | vertical_walk_down | Climb down |
| 42 | vertical_walk_over | Climbing to walking transition |
| 43 | look_down | Peek over window edge |
| 44-46 | jump_down 1-3 | Jump off window edge |
| 47-48 | bathc/d | More bath sequences |
| 49 | walk_win2 | Walking on window variant |
| 50 | walk_task2 | Walking on taskbar variant |
| 51-54 | fall_win a-d | Falling off window sequence |

---

## State Machine Logic

### Tick Loop (each timer fire)
1. Disable timer (prevent re-entrancy)
2. Advance `AnimationStep++`
3. Compute frame index from sequence (with repeat/repeatfrom)
4. Interpolate movement values (start -> end over TotalSteps)
5. Check borders (screen edges, window edges)
6. Check gravity (is ground still there?)
7. Move pet by interpolated (x, y)
8. Update window position and sprite frame
9. Re-enable timer with interpolated interval

### TotalSteps Calculation
`Frames.Count + (Frames.Count - RepeatFrom) * Repeat`

### Frame Index
- If `step < Frames.Count`: `Frames[step]`
- Else: `((step - Frames.Count + RepeatFrom) % (Frames.Count - RepeatFrom)) + RepeatFrom`

### Interpolation (linear, start -> end)
- `value = start + (end - start) * step / totalSteps`
- Movement X/Y use `totalSteps - 1` as denominator

### Three Transition Triggers
1. **Sequence end** -> pick from `EndAnimation` list (weighted probability, filtered by context)
2. **Border hit** -> pick from `EndBorder` list
3. **Gravity lost** -> pick from `EndGravity` list

### Context Filtering
At transition time, determine `where`:
- On a window -> `WINDOW`
- Near screen bottom (dock area) -> `TASKBAR`
- Otherwise -> `NONE`
Filter candidates: `candidate.only & where != 0`

### Flip Action
When sequence has `<action>flip</action>`:
- Toggle `IsMovingLeft`
- Mirror ALL sprite images horizontally

---

## Physics System
- **No continuous physics engine** -- purely frame-based
- Gravity is opt-in per animation via `<gravity>` node
- Fall = animation with increasing Y velocity (start.y=1, end.y=10)
- 3px tolerance before triggering gravity fall
- Landing = border detection when Y movement intersects surface

---

## Window Interaction (macOS adaptation)

### Original (Windows)
- `EnumWindows` API to enumerate visible windows
- `GetWindowRect` for bounds
- Z-order walk via `GetTopWindow`/`GetWindow`

### macOS Equivalent
- `CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)`
- Returns array of dictionaries with `kCGWindowBounds`, `kCGWindowOwnerName`, `kCGWindowLayer`
- **Requires Screen Recording permission** on macOS 10.15+
- Coordinate conversion needed: CG uses top-left origin, NSWindow uses bottom-left

### Window Following
- Poll window position every 16ms
- If window moves, translate pet by delta
- If window disappears, trigger gravity

---

## macOS Technical Stack

### Overlay Window
```swift
NSWindow(styleMask: [.borderless])
  isOpaque = false
  backgroundColor = .clear
  hasShadow = false
  level = .statusBar  // or .floating
  collectionBehavior = [.canJoinAllSpaces, .stationary]
  ignoresMouseEvents = true/false  // toggle for drag
```

### Menu Bar App
```swift
MenuBarExtra("Desktop Pet", systemImage: "pawprint.fill") { ... }
// + LSUIElement = YES in Info.plist
```

### Animation Options
1. **SpriteKit** (recommended) -- `SKSpriteNode` + `SKAction.animate(with:timePerFrame:)`
2. **Core Animation** -- `NSImageView` with timer-driven frame changes
3. **SwiftUI Image** -- `@State` timer cycling frames

### State Machine
- `GKStateMachine` from GameplayKit
- Or custom probability-weighted state machine matching eSheep logic

---

## Key Constants (from original)
- `MAX_SHEEPS = 16`
- Max child nesting: 5 levels
- Window overlap tolerance: `Width/2` each side
- Gravity tolerance: 3px
- FollowWindow timeout: 20 iterations * 16ms
- Kill fade: opacity -= 0.1 per cycle
- `randS` range: 10-89
- `random` range: 0-99

---

## Menu Features (from original)
1. Add new pet (tray double-click also adds)
2. Options dialog
3. About (from XML header)
4. Help
5. Remove all and close
- Tray single-click: bring all to front
- Debug mode (Shift at startup): force any animation/spawn
