# Handoff — Phase 1 Wave 5 EXECUTE (plan approved, ready to code)

**From session**: 2026-04-25 plan-eng-review session (ID `74ef7fcf`)
**To**: new session, same repo
**Last commit before handoff**: `a9e206d` (Wave 4 dogfood handoff)
**Status**: ENG CLEARED — 6 decision gates answered, plan locked, ready execute

---

## Read these first (in order)

1. `plans/reports/2026-04-24-implementation-plan-v0.1/phase-01-wave-5-pivot.md` — **the plan to execute**
2. `plans/reports/2026-04-24-implementation-plan-v0.1/research-nspanel-fullscreen-overlay.md` — API context for Wave 5b NSPanel invariants
3. `~/.gstack/projects/psychomafia-tiger-tft-hell-elo-for-macos/mac-feat-v0.1-implementation-eng-review-test-plan-20260425.md` — test plan anh dùng Wave 5e
4. `CLAUDE.md` — project rules (Vietnamese-first, plain-language với ví dụ số)
5. Memory auto-loads: `project_v0_1_pivot_20260425.md`, `feedback_plan_review_before_execute.md`, `feedback_research_use_websearch_not_gemini.md`

## Decisions locked (D1-D6, KHÔNG re-debate)

| ID | Decision |
|----|----------|
| D1 | Cmd+Shift+T → always show BOTH popover + NSPanel overlay (no TFT detection logic) |
| D2 | Eager instantiate NSPanel at app launch (+15-20MB, <50ms show latency) |
| D3 | Bundle ID `io.psychomafia.tfthellelo` |
| D4 | Single shared `CompListView(width:)` — popover 440px, overlay 520px |
| D5 | Wave 5c icons = placeholder circle + SF Symbol + name text. Real R2 URLs Phase 2 |
| D6 | Defer E2E CI test. Wave 5e = anh manual dogfood trong real TFT |

## Execute order (sequential, no parallel)

### Wave 5a — Rename (~30 min)
Files: `App/project.yml`, `App/TFTMac/Resources/Info.plist`, `App/TFTMac/Views/HeaderBar.swift`, `README.md`, `CLAUDE.md` (+ new `docs/naming-conventions.md`). Regen xcode với `xcodegen generate`. Verify HeaderBar shows "TFT Hell Elo". 21 unit tests phải pass. Commit `feat(app): Wave 5a rename TFTMac→TFT Hell Elo + owner psychomafia`.

**Test added**: `BundleIdentifierRegressionTest.swift`.

### Wave 5b — NSPanel Overlay (~4h)
New files:
- `App/TFTMac/Views/OverlayPanel.swift` (NSPanel subclass)
- `App/TFTMac/Views/OverlayWindowController.swift`

Modify: `TFTMacApp.swift` (eager @StateObject), `HotkeyRegistration.swift` (dual-route onPress).

**Critical invariants (tests MUST assert):**
- `panel.level == Int(CGWindowLevelForKey(.overlayWindowLevelKey))`
- `panel.collectionBehavior == [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]`
- `panel.canBecomeKey == false` (override)
- `panel.hidesOnDeactivate == false`
- `panel.isFloatingPanel == true`
- `styleMask` includes `.nonactivatingPanel`

Tests NEW: `OverlayPanelConfigTests.swift`, `OverlayWindowControllerTests.swift`, `HotkeyDualRouteTests.swift`. Commit `feat(app): Wave 5b NSPanel fullscreen overlay + hotkey dual-route`.

### Wave 5c — UI Redesign (~6h)
New views (kebab-case file names OK, SwiftUI inside):
- `CompListView.swift` (shared container, `width: CGFloat` param)
- `ChampionPortrait.swift` (placeholder circle + SF Symbol + name)
- `StarLevelIndicator.swift` (1/2/3 star overlay)
- `PlaystyleLabel.swift` (Fast 8 / Slow Roll badge)
- `FilterBar.swift` (3-tab segmented)
- `ExpandedCardView.swift` (inline click-to-expand — traits + carousel + LV.9, **KHÔNG hex board**)

Refactor: `CompCard.swift` → `CompCardV2` (7-8 `ChampionPortrait` via `ForEach`, `@State isExpanded`).

Placeholder strategy: `Circle().fill(Color.gray.opacity(0.3))` + SF Symbol `person.circle.fill` + `Text(champion.name)`. Phase 2 thay `AsyncImage(url:)` 1 dòng.

Tests NEW: `CompCardV2Tests.swift`, `FilterBarTests.swift`, `ExpandedCardViewTests.swift`. Update `CompCardTests.swift` (4→7-8 portraits). Commit `feat(app): Wave 5c CompCard v2 layout per TFTactics reference`.

### Wave 5e — Dogfood (anh tự làm)
Test checklist trong plan file section "Wave 5e". Key checks:
- Cmd+Shift+T trong **TFT borderless** → overlay visible (current blocker — phải pass)
- Mid-game keyboard input → TFT nhận input (panel KHÔNG steal focus)

Fallback tree nếu borderless vẫn fail: plan file section "If Wave 5e reveals borderless overlay STILL fails" (B5 pragmatic → B4 Accessibility → B1 ScreenCaptureKit).

## Critical gaps & risks

- **[CRITICAL]** Eager init OOM trên 8GB Mac: profile với Instruments trong Wave 5b, gate 45MB total RSS budget
- **[REGRESSION]** Rename breaks XCUITest Task 1.10 hardcoded "TFTMac" string → update khi Wave 5a
- **[REGRESSION]** CompCardTests asserts 4 portraits → update khi Wave 5c
- **[UNKNOWN]** Unreal Engine có thể suppress NSPanel overlay via private Metal context — chỉ test trong Wave 5e biết được. Fallback tree ready.

## Workflow notes

- **KHÔNG dùng `/office-hours`, `/plan-ceo-review`, `/plan-eng-review`** — plan approved rồi, jump vào execute
- **KHÔNG run gemini bash CLI** cho research (per `feedback_research_use_websearch_not_gemini.md`)
- **Dùng `superpowers:test-driven-development`** nếu muốn rigor cho Wave 5b (invariants critical) — optional
- Commit mỗi Wave xong, push lên `feat/v0.1-implementation`
- Sau Wave 5c land xong, báo anh để dogfood

## Quick commands

```bash
# Rebuild + launch
cd "/Users/mac/Desktop/TFTTACTICS FOR MACS/App" && xcodegen generate && xcodebuild -project TFTMac.xcodeproj -scheme TFTMac -configuration Debug build && open /Users/mac/Library/Developer/Xcode/DerivedData/TFTMac-*/Build/Products/Debug/TFTMac.app

# Kill before rebuild
pkill -x TFTMac

# Unit tests
cd "/Users/mac/Desktop/TFTTACTICS FOR MACS/App" && xcodebuild -project TFTMac.xcodeproj -scheme TFTMac -configuration Debug test -only-testing:TFTMacTests
```

## Report format cuối session mới

```
Status: DONE | BLOCKED | NEEDS_DECISION
Waves landed: 5a [✓/✗] | 5b [✓/✗] | 5c [✓/✗]
Tests: unit X/X pass | XCUITest Task 1.10 cold launch <600ms [✓/✗]
Memory profile Wave 5b: total RSS after eager init = XX MB (budget 45MB)
Dogfood gate: anh ready test Wave 5e [Y/N]
Next: Phase 2 Wave 1 pipeline | re-dogfood findings
```
