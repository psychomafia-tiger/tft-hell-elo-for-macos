# Phase 1 Wave 5 — Major Pivot Plan

**Status**: Plan reviewed (plan-eng-review 2026-04-25), awaiting execute
**Branch**: `feat/v0.1-implementation`
**Supersedes**: `handoff-phase-1-wave-5-major-pivot.md` (consolidated here)
**Research report**: [research-nspanel-fullscreen-overlay.md](./research-nspanel-fullscreen-overlay.md)
**Test plan**: `~/.gstack/projects/psychomafia-tiger-tft-hell-elo-for-macos/mac-feat-v0.1-implementation-eng-review-test-plan-20260425.md`

---

## Context Links

- Dogfood trigger: `docs/weekend-1-dogfood-notes.md` (anh's 3 issues flagging pivot)
- UI target reference: `docs/reference_image/tfttactics_windows.png`
- Current state: 9/10 Phase 1 tasks done, 21/21 unit tests pass, 242ms cold launch, 5 commits since Wave 3
- Previous phase: `phase-01-weekend-1-app-scaffold.md`

## Overview

Wave 5 pivots v0.1 scope based on dogfood findings. Three confirmed decisions (F1/F2/F3) landed via 6 eng-review gates (D1-D6). No architectural surprises; pivot EXTENDS existing code (MenuBarExtra popover, CompCard, catalogs, XCUITest) rather than rewrites.

**Execution order**: 5a rename → 5b NSPanel overlay → 5c UI redesign → 5e re-dogfood.

## Decisions Locked (eng review gates)

| ID | Topic | Choice | Rationale |
|----|-------|--------|-----------|
| D1 | Hotkey trigger | Always-show-both | KISS, no TFTActivityDetector needed |
| D2 | NSPanel lifecycle | Eager at launch | <50ms show latency, +15-20MB acceptable |
| D3 | Bundle ID | `io.psychomafia.tfthellelo` | Indie prefix, matches owner GitHub |
| D4 | View sharing | Single `CompListView(width:)` | DRY, popover 440px + overlay 520px |
| D5 | Icon assets Wave 5c | Placeholder circles + text | Real data swap in Phase 2 pipeline |
| D6 | E2E CI test | Defer | 10-user dogfood, manual verify Wave 5e |

## Architecture

### Component diagram

```
┌─────────────────────── TFTMacApp (main actor) ───────────────────────┐
│                                                                       │
│  ┌───────────────────────┐       ┌──────────────────────────────┐   │
│  │  MenuBarExtra popover │       │  OverlayWindowController     │   │
│  │  (existing, wired)    │       │  (NEW, Wave 5b)              │   │
│  │                       │       │  ├── OverlayPanel (NSPanel)  │   │
│  │  └── CompListView ────┼───────┤      subclass                │   │
│  │      (width: 440)     │       │      canBecomeKey=false      │   │
│  └───────────────────────┘       │      hidesOnDeactivate=false │   │
│                                   │      level=overlayWindowLvl  │   │
│                                   │      collectionBehavior:     │   │
│                                   │        [canJoinAllSpaces,    │   │
│                                   │         fullScreenAuxiliary] │   │
│                                   │  └── CompListView (width:520)│   │
│                                   └──────────────────────────────┘   │
│                                                                       │
│  ┌──────────────────── HotkeyRegistration ─────────────────────┐    │
│  │  onPress(Cmd+Shift+T):                                       │    │
│  │    1. popover.toggle()                                       │    │
│  │    2. overlayController.toggle()  ← NEW in Wave 5b           │    │
│  └──────────────────────────────────────────────────────────────┘    │
└───────────────────────────────────────────────────────────────────────┘

         CompListView (shared, NEW in Wave 5c)
         ├── FilterBar (Champions | Traits | Search)
         ├── ScrollView { LazyVStack {
         │     ForEach(comps) { comp in
         │       CompCardV2(comp)
         │         ├── HeaderRow (comp name + playstyle label)
         │         ├── HStack { ForEach(comp.champions) { ChampionPortrait } }
         │         │   ├── ZStack {
         │         │   │     PlaceholderCircle (Wave 5c placeholder)
         │         │   │     StarLevelIndicator (1/2/3 stars)
         │         │   │   }
         │         │   └── Text(champion.name)
         │         └── @Binding isExpanded {
         │               ExpandedView
         │                 ├── TraitsList
         │                 ├── CarouselPicks
         │                 └── LV9AlternativeList
         │                 // NOTE: hex board positioning DEFERRED v0.2
         │             }
         │   }
         │ } }
```

### Why eager-init NSPanel is safe

Analogy: menu bar app đã resident sẵn trong memory (LSUIElement=true, daemon-like). Thêm 15-20MB cho NSPanel shell + CompCard tree giống như mở thêm 1 tab Chrome — trên Mac 16GB RAM modern, bỏ qua. Cold launch 242ms → ~320ms vẫn dưới 500ms snappy threshold mà user perceive là "instant".

### Critical invariants (must hold after implementation)

1. NSPanel KHÔNG steal keyboard focus: `canBecomeKey` override returns `false` — nếu user đang type trong TFT, overlay show không làm user mất input.
2. Popover existing behavior KHÔNG regress: current 21 unit tests pass, XCUITest Task 1.10 cold launch metric < 600ms.
3. Hotkey routes idempotent: 10 lần Cmd+Shift+T consecutive → popover + overlay state consistent (không orphan window).

## Wave 5a — Rename (F3), ~30 min

### Files to modify

- `App/project.yml`:
  - `options.bundleIdPrefix`: `asia.lab3.tftmac` → `io.psychomafia`
  - `targets.TFTMac.info.properties.CFBundleDisplayName`: "TFT Mac" → "TFT Hell Elo"
  - Target name stays `TFTMac` (per handoff: avoid regression)
- `App/TFTMac/Resources/Info.plist` — sync với project.yml
- `App/TFTMac/Views/HeaderBar.swift` — UI text "TFT Mac" → "TFT Hell Elo"
- `README.md` — update title, screenshots caption
- `CLAUDE.md` — add note: "user-facing name 'TFT Hell Elo', code target `TFTMac` retained"
- `docs/naming-conventions.md` (NEW) — document rename decision + why target name stays

### Steps

1. Edit project.yml (2 lines)
2. Regen xcode: `xcodegen generate` in App/
3. Edit HeaderBar.swift (1 string literal)
4. Edit README.md (title + any screenshots with caption)
5. Add 1-paragraph note to CLAUDE.md under new "## Naming" section
6. Create docs/naming-conventions.md (why display name ≠ target name, migration note for existing 10 testers)
7. Build + launch + verify HeaderBar shows "TFT Hell Elo"
8. Run unit tests — expect 21/21 pass (no test depends on display name)
9. Commit: `feat(app): Wave 5a rename TFTMac→TFT Hell Elo + owner psychomafia`

### Tests

- `BundleIdentifierRegressionTest.swift` (NEW) — assert Bundle.main.bundleIdentifier == "io.psychomafia.tfthellelo"
- Update `AppLaunchMetricsTests.swift` XCUITest — hardcoded "TFTMac" string → "TFT Hell Elo" in any `XCUIApplication(bundleIdentifier:)` call (if exists)

## Wave 5b — NSPanel Overlay (F1), ~4h

### Files to create

- `App/TFTMac/Views/OverlayPanel.swift` — NSPanel subclass (~40 lines)
  - Override `canBecomeKey` returns `false`
  - Override `canBecomeMain` returns `false`
  - Set in init: `level = Int(CGWindowLevelForKey(.overlayWindowLevelKey))`
  - Set in init: `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]`
  - Set in init: `hidesOnDeactivate = false`
  - Set in init: `isFloatingPanel = true`, `styleMask = [.nonactivatingPanel, .resizable, .titled]`

- `App/TFTMac/Views/OverlayWindowController.swift` — NSWindowController wrapping OverlayPanel (~60 lines)
  - `@Published var isVisible: Bool`
  - `show()` / `hide()` / `toggle()` methods
  - Hosts SwiftUI CompListView(width: 520) via NSHostingView

### Files to modify

- `App/TFTMac/TFTMacApp.swift`:
  - Add `@StateObject var overlayController = OverlayWindowController()` in App body
  - Eager instantiate at app launch (D2 decision)
- `App/TFTMac/Services/HotkeyRegistration.swift`:
  - Inject overlayController binding
  - onPress handler now calls BOTH `togglePopover()` AND `overlayController.toggle()`

### Tests

- `OverlayPanelConfigTests.swift` (NEW) — verify config matches invariants (level, collectionBehavior, canBecomeKey=false)
- `OverlayWindowControllerTests.swift` (NEW) — show/hide/toggle idempotent after 10 iterations
- `HotkeyDualRouteTests.swift` (NEW) — mock hotkey fire → assert both popover.isVisible + overlay.isVisible toggle

### Commit: `feat(app): Wave 5b NSPanel fullscreen overlay + hotkey dual-route`

## Wave 5c — UI Redesign (F2), ~6h

### Files to create

- `App/TFTMac/Views/CompListView.swift` — shared container (width: CGFloat param) (~80 lines)
- `App/TFTMac/Views/ChampionPortrait.swift` — placeholder circle + star + name (~40 lines)
- `App/TFTMac/Views/StarLevelIndicator.swift` — 1/2/3 star overlay on portrait (~25 lines)
- `App/TFTMac/Views/PlaystyleLabel.swift` — "Fast 8" / "Slow Roll (5)" badge (~30 lines)
- `App/TFTMac/Views/FilterBar.swift` — 3-tab segmented control (~50 lines)
- `App/TFTMac/Views/ExpandedCardView.swift` — click-to-expand traits + carousel + LV.9 list (~80 lines)

### Files to modify (major refactor)

- `App/TFTMac/Views/CompCard.swift` — becomes CompCardV2; 4 placeholder portraits → call `ForEach(comp.champions) { ChampionPortrait }`; add `@State isExpanded` for inline expand

### Placeholder strategy (per D5)

- `ChampionPortrait` renders `Circle().fill(Color.gray.opacity(0.3))` + SF Symbol `person.circle.fill` fallback + `Text(champion.name)` underneath
- Phase 2 pipeline (next) swaps to `AsyncImage(url: champion.iconURL)` — 1-line change in ChampionPortrait.swift

### Tests

- `CompCardV2Tests.swift` (NEW) — 7-8 portraits rendered, star level bound to data, playstyle label visible
- `FilterBarTests.swift` (NEW) — 3 tabs switchable, selected state correct
- `ExpandedCardViewTests.swift` (NEW) — isExpanded binding toggles traits list visibility
- Update `CompCardTests.swift` — existing assertions on 4-portrait layout → 7-8 portrait layout
- XCUITest Task 1.10 regression — re-run after rebuild, expect <600ms cold launch

### Commit: `feat(app): Wave 5c CompCard v2 layout per TFTactics reference`

## Wave 5e — Re-dogfood (manual, anh's test)

### Test scenarios (anh runs trong real TFT)

- [ ] Cmd+Shift+T khi TFT windowed → popover + overlay visible
- [ ] Cmd+Shift+T khi TFT **borderless** → overlay visible (critical — current blocker)
- [ ] Cmd+Shift+T khi TFT native fullscreen → overlay visible OR fallback banner
- [ ] Mid-game keyboard input → TFT receives input (panel NOT stealing focus)
- [ ] CompCard v2 shows 7-8 portraits + star + name + playstyle
- [ ] Click comp → expanded view inline renders
- [ ] Filter bar 3 tabs switchable
- [ ] HeaderBar shows "TFT Hell Elo"

### If Wave 5e reveals borderless overlay STILL fails

Fallback tree (from research report Section 4):
1. Fallback 1: B5 pragmatic — banner instruct user to use borderless only (if fullscreen fails)
2. Fallback 2: B4 Accessibility API (2-3 days) — repositioning NSPanel relative to TFT window via AXUIElement
3. Fallback 3: B1 ScreenCaptureKit (5 days, Phase 2) — TCC permission composite, 50-200ms latency

## NOT in scope (deferred explicitly)

| Item | Rationale |
|------|-----------|
| Positioning hex board in expanded view | Vector hex math = 1 full weekend, v0.2 |
| Real champion icons (R2 CDN) | Phase 2 data pipeline, Wave 5c uses placeholder |
| Exclusive fullscreen support (CGDisplayCapture) | Research shows impossible without ScreenCaptureKit; fallback to borderless docs |
| User migration script from `asia.lab3.tftmac` → new bundle ID | 10 testers, force reinstall acceptable |
| Automated E2E mock test for overlay-on-borderless | D6 defer, manual dogfood Wave 5e |
| Notarization + signed .dmg | v0.2 scope, current unsigned OK for founder dogfood |
| TFTActivityDetector (smart hotkey routing) | D1 decided always-show-both, no detection needed |
| ScreenCaptureKit fallback path | Only build if Wave 5e reveals borderless fails |
| Accessibility API fallback path | Only build if Wave 5e reveals borderless fails |

## What already exists (reuse, không rebuild)

| Existing code | Wave 5 action | Saves |
|---------------|---------------|-------|
| MenuBarExtra popover + HeaderBar | Extend (not replace), wire CompListView width=440 | ~4h |
| CompCard.swift v1 | Refactor to CompCardV2 (extend, preserve XCUITest structure) | ~2h |
| TFTCatalogs + DataManager | Reuse for comp/champion schema | ~3h |
| HotkeyRegistration (HotKey 0.2.1) | Extend onPress handler (add overlay.toggle) | ~1h |
| sample-tier-list.json | Keep as placeholder data source for Wave 5c | ~1h |
| 21 passing unit tests | Adapt CompCardTests assertions only; rest pass | ~2h test writing |
| XCUITest Task 1.10 cold launch | Re-run after rename; re-baseline if launch > 600ms | minimal |
| Assets.xcassets | Reuse; add SF Symbol placeholder logic for Wave 5c | 0 |

**Total reuse saves: ~13h across rewrite alternative.**

## Failure modes (realistic production scenarios)

| Path | Failure scenario | Covered? |
|------|------------------|----------|
| OverlayPanel config | `.fullScreenAuxiliary` flag silently ignored by macOS Sequoia patch | ✗ CI test, ✓ manual dogfood |
| Focus steal | User types "ff" mid-game, panel accidentally becomes key → TFT loses input | ✓ unit test canBecomeKey=false + manual verify |
| Eager init OOM | On low-memory Mac (8GB), +15-20MB push total past 50MB budget | ✗ no test; profile manually in Wave 5b |
| Hotkey collision | Cmd+Shift+T collides with another app's global hotkey | ✓ existing Wave 4 test |
| Rename bundle ID | LaunchServices registers 2 apps (old + new), user confused | ✓ docs/naming-conventions.md note |
| CompCard v2 layout break | 7-8 portraits overflow 520px width on small screens | ✗ no test; manual verify Wave 5c |

**Critical gap flagged**: Eager init OOM on 8GB Mac — not tested. Mitigation: profile with Instruments during Wave 5b, gate on 45MB total RSS budget.

## Parallelization strategy

**Sequential** — no parallelization. Wave order is dependency-chained:
- 5a rename must land first (affects every .swift file's bundle ID references downstream)
- 5b overlay depends on 5a (new files import module by bundle ID)
- 5c UI redesign touches views shared with popover + overlay — must come after 5b to avoid rework
- 5e dogfood requires 5a+5b+5c all landed

Parallelization possible within Wave 5c only (independent sub-views can be written by parallel dev sessions), but single-dev context = sequential.

## TODO candidates (for TODOS.md)

See AskUserQuestion D7 below.

## Completion summary

- Step 0 Scope: accepted as-is (no reduction triggered, all 3 F-decisions in scope)
- Architecture Review: 4 issues, 3 via AskUserQuestion, 1 trivial (focus stealing)
- Code Quality Review: 2 issues, 1 via AskUserQuestion (DRY), 1 moot (per D1)
- Test Review: coverage diagram produced, 19 new paths, 0/19 tested at plan time. 2 CRITICAL regressions (CompCard tests, XCUITest rename) flagged
- Performance Review: 0 issues (memory + latency covered by D2)
- NOT in scope: written (9 items deferred with rationale)
- What already exists: written (8 reuses, ~13h saved)
- TODOS.md updates: pending D7 AskUserQuestion
- Failure modes: 1 critical gap flagged (eager init OOM on 8GB Mac — manual Instruments profile mitigation)
- Outside voice: skipped per PROACTIVE=false user config
- Parallelization: sequential only, no parallel lanes
- Lake Score: 6/6 recommendations chose complete option (no shortcuts proposed)

## Unresolved decisions

None at plan time. All 6 decision gates answered. D7 TODO curation pending.

---

## GSTACK REVIEW REPORT

| Review | Trigger | Why | Runs | Status | Findings |
|--------|---------|-----|------|--------|----------|
| CEO Review | `/plan-ceo-review` | Scope & strategy | 0 | — | — |
| Codex Review | `/codex review` | Independent 2nd opinion | 0 | — | — |
| Eng Review | `/plan-eng-review` | Architecture & tests (required) | 1 | CLEAR (PLAN) | 6 issues resolved, 1 critical gap (eager init OOM profile), 19 test paths queued |
| Design Review | `/plan-design-review` | UI/UX gaps | 0 | — | — |
| DX Review | `/plan-devex-review` | Developer experience gaps | 0 | — | — |

**UNRESOLVED:** 0 (all 6 decision gates answered)
**VERDICT:** ENG CLEARED — ready to implement (pending D7 TODOs curation)
