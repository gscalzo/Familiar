# Familiar — Feature Checklist

## Core Behavior
- [x] Walk left/right along screen bottom
- [x] Turn around at screen edges (border hit → rotate)
- [x] Multi-monitor walking with bottom snapping
- [x] Animation transitions (endAnimation/endBorder)
- [x] Animation interval timing (per-animation speed)
- [x] Random idle behaviors (sleep, eat, bathe via endAnimation transitions)
- [x] Run/boing (via endAnimation transitions)
- [x] Gravity/falling (fall after drag drop, land on screen bottom)
- [x] Kill animation (fade-out on remove)

## Interaction
- [x] Drag interaction (pick up and drop)
- [x] Wall climbing (walk up screen edges)
- [x] Upside-down walking on screen top
- [ ] Window walking (walk on app title bars)

## CLI & Pluggability
- [x] `fam` CLI tool
- [x] Mood commands (chill/think/work/wait/sleep)
- [x] Event commands (yay/oops/hmm/go/done)
- [x] Named pets (spawn/kill per agent session)
- [x] Animation config file (~/.familiar/animations.json)
- [x] Custom mood/event mappings via config (~/.familiar/animations.json)

## Menu Bar
- [x] Add/remove pets
- [x] Pause/resume all
- [x] Reset positions
- [x] Load custom XML
- [x] About dialog
- [x] Launch at login

## Advanced
- [ ] Child pets (black sheep companion)
- [ ] Sound support
- [x] Multiple pet XML types (22 bundled pets with Choose Pet submenu)

## Quality
- [x] Pre-commit hook (lint + format)
- [x] Pre-push hook (tests + coverage + metrics)
- [x] Quality metrics dashboard (GitHub Pages)
- [x] README badges (tests + coverage)
