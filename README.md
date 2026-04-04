# Familiar for macOS

![Tests](https://img.shields.io/badge/tests-72-blue)
![Coverage](https://img.shields.io/badge/coverage-84.71%25-green)

A macOS menubar app that recreates the classic eSheep desktop pet experience. Your pet walks on screen edges and window title bars, falls with gravity, sleeps, runs, climbs walls, and responds to drag interactions.

## Features

- **eSheep XML compatible** -- Load any community-created pet from the eSheep ecosystem
- **Window walking** -- Pet detects other app windows and walks on their title bars
- **Full screen interaction** -- Walks along screen edges, climbs walls, walks upside down
- **Gravity & physics** -- Falls when surfaces disappear, lands on windows below
- **Multiple pets** -- Up to 16 simultaneous pets, each independent
- **Menubar app** -- Lives in the menu bar, no Dock icon
- **Drag & drop** -- Drag your pet around, drop XML files to load new pets
- **Multi-monitor** -- Pets roam across all connected displays

## Requirements

- macOS 15 (Sequoia) or later
- Screen Recording permission (optional, for window walking)

## Architecture

Clean Architecture with framework-free domain layer:

```
Domain/       -- Pure logic: state machine, animation engine, expression evaluator
Infrastructure/ -- Framework adapters: XML parser, sprite loader, window detection
Presentation/ -- UI: pet panels, menu bar, onboarding
App/          -- Composition root: wires everything together
```

## Origins

Inspired by the original eSheep (1995) by Tatsutoshi Nomura and the modern [eSheep 64bit](https://github.com/Adrianotiger/desktopPet) recreation by Adrianotiger. Parses the same XML animation format for full community compatibility.

## Documentation

- [Design Document](docs/plans/2026-04-04-desktop-pet-design.md)
- [Research & References](docs/research.md)
- [Implementation History](docs/history.md)
- [Quality Metrics Dashboard](docs/metrics/index.html)
