# Familiar — Feature Checklist

## Core Behavior
- [x] Walk left/right along screen bottom
- [x] Turn around at screen edges (border hit → rotate)
- [x] Multi-monitor walking with bottom snapping
- [x] Animation transitions (endAnimation/endBorder)
- [x] Animation interval timing (per-animation speed)
- [x] Random idle behaviors (sleep, eat, bathe via endAnimation transitions)
- [x] Run/boing (via endAnimation transitions)
- [ ] Gravity/falling (fall when not on a surface)
- [x] Kill animation (fade-out on remove)

## Interaction
- [ ] Drag interaction (pick up and drop)
- [ ] Wall climbing (walk up screen edges)
- [ ] Upside-down walking on screen top
- [ ] Window walking (walk on app title bars)

## CLI & Pluggability
- [x] `fam` CLI tool
- [x] Mood commands (chill/think/work/wait/sleep)
- [x] Event commands (yay/oops/hmm/go/done)
- [x] Named pets (spawn/kill per agent session)
- [x] Animation config file (~/.familiar/animations.json)
- [ ] Custom mood/event mappings via config

## Menu Bar
- [x] Add/remove pets
- [x] Pause/resume all
- [x] Reset positions
- [x] Load custom XML
- [x] About dialog
- [ ] Launch at login

## Advanced
- [ ] Child pets (black sheep companion)
- [ ] Sound support
- [ ] Multiple pet XML types simultaneously

## Quality
- [x] Pre-commit hook (lint + format)
- [x] Pre-push hook (tests + coverage + metrics)
- [x] Quality metrics dashboard (GitHub Pages)
- [x] README badges (tests + coverage)
