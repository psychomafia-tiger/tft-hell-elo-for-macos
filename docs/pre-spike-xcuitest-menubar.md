# Pre-spike: XCUITest + LSUIElement compatibility

**Date**: 2026-04-24
**Spike duration**: ~45 min (30 min plan + 15 min extended probes)
**Author**: AI agent (Opus 4.7)
**Spike artifact**: `/tmp/xcuitest-spike/` (throwaway, delete after merge)
**Phase 0 task**: 0.8 (CEO review F6.1)

## Why this spike

Phase 1 Task 1.10 planned to measure popover open latency ≤300ms via XCUITest. But TFT Mac app sets `LSUIElement=true` (menu-bar-only, no Dock icon) — XCUITest's default `app.launch()` assumes a regular Dock app. If XCUITest cannot drive menu-bar-only apps, Phase 1 would need to rewrite Task 1.10 to manual stopwatch — less rigorous, not blocking v0.1 ship but degraded test discipline.

**Cheap insurance (bảo hiểm rẻ)**: 30-min spike BEFORE Phase 1 code start vs potential 1-day Phase 1 rework.

## Test matrix

Throwaway app: SwiftUI `@main` + `NSStatusItem` + `NSPopover`, `LSUIElement=true` in Info.plist, ad-hoc signed (`CODE_SIGN_IDENTITY="-"`).

Environment: Xcode 26.4.1 (build 17E202), macOS 26 (Darwin 25.3.0), Swift 5, deployment target macOS 14.0, Apple Silicon (arm64).

| # | Test | Result | Detail |
|---|------|--------|--------|
| 1 | `testAppLaunchesEvenWhenLSUIElementTrue` | ✅ PASS (0.84s) | `XCUIApplication().launch()` works — state transitions to `runningForeground` within 1s |
| 2 | `testLaunchMetricCapturesPerf` | ✅ PASS (12.67s total, 5 launches) | `XCTApplicationLaunchMetric()` reports **avg 0.194s**, stdev 6.8%, range 0.170–0.205s |
| 3 | `testCanReachStatusItemViaMenuBars` (`systemUIServer`) | ❌ FAIL (6.78s timeout) | `XCUIApplication(bundleIdentifier: "com.apple.systemuiserver").menuBars.buttons["SpikeStatusItem"]` — element not found |
| 4 | `testCanReachStatusItemViaControlCenter` | ❌ FAIL (7.29s timeout) | `XCUIApplication(bundleIdentifier: "com.apple.controlcenter").menuBars.buttons[...]` — element not found |
| 5 | `testCanReachStatusItemViaOwnApp` | ❌ FAIL (6.96s timeout) | `app.menuBars.buttons["SpikeStatusItem"]` on target app — element not found (LSUIElement apps have no app-owned menu bar) |
| 6 | `testCanReachStatusItemViaSystemwideAccessibility` | ❌ FAIL (4.76s) | `systemUIServer.descendants(matching: .button).count` returned **0** — systemUIServer exposes zero XCUIElement-visible buttons |
| 7 | `testPopoverOpensAndShowsIdentifiedContent` | ❌ FAIL (6.88s timeout) | Depends on test #3 — can't click status item, can't verify popover |

Raw run log: `/tmp/xcuitest-spike-dd/Logs/Test/Test-SpikeMenuBar-*.xcresult`

## Key findings (decision drivers)

### Finding 1 — `XCUIApplication().launch()` works for LSUIElement=true ✅

App launches successfully despite no Dock icon. State is `runningForeground` (value 3). No special configuration needed beyond ad-hoc signing.

**Note on ad-hoc signing**: Initial attempt with `CODE_SIGNING_ALLOWED=NO` failed với Gatekeeper "damaged and can't be opened" dialog on the XCUITest runner bundle. Fix: `CODE_SIGN_IDENTITY="-"` + `CODE_SIGN_STYLE=Manual` (ad-hoc local signing). TFTMac main project will need the same config for test targets.

### Finding 2 — `XCTApplicationLaunchMetric()` works with excellent precision ✅

5 consecutive cold launches averaged **194ms (σ=6.8%)** for a near-empty throwaway app. This is **well under the 500ms v0.1 launch target** (NFR-3) — TFTMac has budget ~300ms for data-load overhead before breaching the ceiling.

**Implication for Phase 1 Task 1.10**: perf gate is viable.

```swift
measure(metrics: [XCTApplicationLaunchMetric()]) {
    XCUIApplication().launch()
}
```

### Finding 3 — NSStatusItem UNREACHABLE via any XCUITest accessibility path ❌

Probed 4 host targets, all returned empty:

| Host | Query | Result |
|------|-------|--------|
| `com.apple.systemuiserver` | `.menuBars.buttons["SpikeStatusItem"]` | not found |
| `com.apple.systemuiserver` | `.descendants(matching: .button).count` | **0** (zero buttons visible) |
| `com.apple.controlcenter` | `.menuBars.buttons[...]` | not found |
| Target app itself | `.menuBars.buttons[...]` | not found (no app menu bar for LSUIElement=true) |

Status item was correctly created (visible in actual menu bar during test run with title "Spike"). Accessibility identifier `SpikeStatusItem` was set via `button.setAccessibilityIdentifier(...)`. But XCUITest's accessibility layer cannot reach it.

**Root cause hypothesis**: macOS 14+ moved status item rendering to a privileged process (`Control Center` / `WindowServer`-hosted surface) that the sandboxed XCUITest host bundle cannot introspect. This is likely a macOS TCC (Transparency, Consent, Control) boundary, not fixable via accessibility identifiers.

## Decision for Phase 1 Task 1.10

**Split measurement strategy — two-track approach:**

### Track A — XCUITest perf gate (KEEP in Phase 1)

- `measure { XCUIApplication().launch() }` for **cold launch latency** → CI-enforceable, budget ≤500ms
- App launches fine even without user click → this captures "app startup to menu bar icon visible" portion

### Track B — Popover open latency (CHANGE strategy)

Original plan: XCUITest simulates Cmd+Shift+T hotkey, measures time to popover visible. **Not feasible** per Finding 3.

**Replacement for Phase 1 Task 1.10**:
1. **Instrumented in-app timing**: app itself logs `signpost` (signpost = mốc đánh dấu thời gian) from hotkey received → popover `.isShown == true` via `os_signpost`. Parse from `log collect` CLI output.
2. **Manual stopwatch** (bấm đồng hồ tay) for human QA: founder runs 10 trials, records wallclock time. Less rigorous but sufficient for v0.1 (10 testers, not 10K users).
3. **Unit-level test**: `NSPopover.show()` latency measured via `DispatchTime.now()` bracket in unit test that doesn't need UI automation.

Phase 1 Task 1.10 will be rewritten to use **option 1 (signpost)** as primary + **option 2 (manual)** as fallback checkpoint.

## Cost impact on Phase 1

- **No delay**: we now know the fallback before coding, not during.
- **Slight scope add**: `os_signpost` instrumentation in `AppDelegate.togglePopover()` — ~10 lines of code, +15 min Phase 1 Task 1.9.
- **Coverage reduction**: UI behavior tests (popover content renders correctly) must be manual for v0.1. Defer automated UI tests to v0.2 using accessibility inspection APIs (`AXUIElement` via XPC) or third-party tools (`sindresorhus/KeyboardShortcuts` test helpers).

## Follow-ups to capture in Phase 1 Task 1.9 / 1.10

- [ ] Add `os_signpost` "popover.open" signpost wrap in `AppDelegate.togglePopover()` (Phase 1 Task 1.9)
- [ ] Phase 1 Task 1.10 rewrite: XCUITest launch metric + signpost-based popover metric + manual stopwatch fallback
- [ ] Test targets require `CODE_SIGN_IDENTITY="-"` + `CODE_SIGN_STYLE=Manual` (ad-hoc) — add to TFTMac `project.yml` (Phase 1 Task 1.1)
- [ ] Document in Phase 1 readme: UI behavior tests are manual for v0.1, automated UI deferred to v0.2

## Spike cleanup

```bash
rm -rf /tmp/xcuitest-spike /tmp/xcuitest-spike-dd
```

No commit from the throwaway project is merged to TFTMac repo. Only this findings doc.

## Status

**DONE** — spike answered all 3 Phase 0 Task 0.8 questions definitively:
- `app.launch()` works: **YES**
- `app.menuBars[].buttons[]` reaches status item: **NO** (+ 3 other hosts also no)
- `XCTApplicationLaunchMetric()` viable: **YES, avg 194ms**
