# Quality Metrics & Dashboard Design

**Date:** 2026-04-04
**Status:** Approved

---

## Goal

Local quality gates with historical tracking: pre-commit runs lint/format, pre-push runs tests + coverage and records metrics. A GitHub Pages dashboard shows test count and coverage over time.

## Components

### 1. Pre-commit hook (updated)

`.git/hooks/pre-commit` — fast checks only (lint + format). Fix all `DesktopPet` references to `Familiar`.

### 2. Pre-push hook (new)

`.git/hooks/pre-push`:
1. Run `swift test --enable-code-coverage`
2. Parse test count from output
3. Extract coverage % via `llvm-cov report`
4. Call `scripts/collect-metrics.swift` to append to `docs/metrics/history.json`
5. Update badge URLs in `README.md` with current values
6. Auto-commit metrics + README changes
7. Block push if tests fail

### 3. Metrics collection script

`scripts/collect-metrics.swift` — standalone Swift script:
- Takes `<test_count> <coverage_pct>` as CLI args
- Reads `docs/metrics/history.json` (or creates it)
- Appends `{ "date": "YYYY-MM-DD", "tests": N, "coverage": N.N }`
- Writes back with pretty-print

### 4. History data

`docs/metrics/history.json`:
```json
[
  { "date": "2026-04-04", "tests": 72, "coverage": 84.5 },
  { "date": "2026-04-05", "tests": 78, "coverage": 86.2 }
]
```

Multiple entries per day allowed (one per push).

### 5. Dashboard page

`docs/metrics/index.html` — single self-contained HTML file:
- Chart.js from CDN for rendering
- Fetches `history.json` via relative path
- Two line charts sharing X-axis (dates):
  - Test count (blue line)
  - Coverage % (green line, Y-axis 0-100)
- Header with current values as badges
- Works locally (`open docs/metrics/index.html`) and on GitHub Pages

### 6. README badges

Static shields.io badges updated by pre-push hook via `sed`:
```
![Tests](https://img.shields.io/badge/tests-72-blue)
![Coverage](https://img.shields.io/badge/coverage-84.5%25-green)
```

### 7. GitHub Pages

- Source: `main` branch, `/docs/metrics` directory
- Configure in repo Settings → Pages
- URL: `https://<user>.github.io/Familiar/`

## File changes

| File | Action |
|------|--------|
| `.git/hooks/pre-commit` | Update: fix DesktopPet → Familiar |
| `.git/hooks/pre-push` | Create: tests + coverage + metrics |
| `scripts/collect-metrics.swift` | Create: JSON append script |
| `docs/metrics/history.json` | Create: empty array `[]` |
| `docs/metrics/index.html` | Create: Chart.js dashboard |
| `README.md` | Update: add badge URLs |

## No external dependencies

- Swift (for collect-metrics.swift)
- Chart.js loaded from CDN in the HTML page
- llvm-cov ships with Xcode toolchain
