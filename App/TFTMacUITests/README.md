# TFTMacUITests — Phase 1 perf gates

Two-track strategy per pre-spike finding (`docs/pre-spike-xcuitest-menubar.md`): XCUITest handles cold launch (CI-enforceable), signposts handle popover open latency (TCC-restricted path).

## Track A — Cold launch latency (this folder)

`AppLaunchMetricTests.testColdLaunchUnder500ms` uses `XCTApplicationLaunchMetric()` inside a `measure` block. XCTest cold-launches the app 5 times and records the average as a baseline on first run; subsequent runs compare against that baseline (±stdev).

**Why CI-enforceable**: Phase 0 pre-spike (`docs/pre-spike-xcuitest-menubar.md`) confirmed `XCUIApplication().launch()` works for `LSUIElement=true` apps — no Dock icon is no obstacle. The spike measured a near-empty throwaway app at 194ms avg (σ=6.8%, range 170–205ms). TFTMac adds `DataManager.loadBundledJSON()` + SwiftUI view tree construction; we budget ~300ms headroom under the NFR-3 500ms ceiling.

**Gate mechanism**: Apple docs confirm `measure(metrics:)` fails the test when the average exceeds the recorded baseline by more than the allowed stdev. We rely on that built-in diff rather than an explicit `XCTAssertLessThan` — this avoids double-gating and lets Xcode's Report navigator manage baseline transitions cleanly.

**Run locally**:

```bash
cd App
xcodebuild -project TFTMac.xcodeproj \
  -scheme TFTMac \
  -configuration Debug \
  test \
  -only-testing:TFTMacUITests/AppLaunchMetricTests/testColdLaunchUnder500ms
```

## Track B — Popover open latency (signpost + Instruments)

XCUITest **cannot** measure Cmd+Shift+T-to-popover-visible latency. The pre-spike probed 4 host targets (`com.apple.systemuiserver`, `com.apple.controlcenter`, own app, systemwide accessibility) and all returned 0 buttons — macOS 14+ TCC blocks XCUITest from discovering `NSStatusItem` elements. Full matrix in `docs/pre-spike-xcuitest-menubar.md` §"Test matrix".

Instead, TFTMac emits `os_signpost` BEGIN/END pairs around the hotkey → popover-visible path. Subsystem `asia.lab3.tftmac`, category `popover`, signpost name `popover.open`. Emission is wired in `TFTMacApp.register(onFire:)` (BEGIN) and `TierListPopover.onAppear` (END) — Task 1.8 commits `d966771` + `4d70df8`.

### Signpost capture workflow

1. **Build + launch the app locally**:
   ```bash
   cd App
   xcodebuild -project TFTMac.xcodeproj -scheme TFTMac -configuration Debug build
   open ~/Library/Developer/Xcode/DerivedData/TFTMac-*/Build/Products/Debug/TFTMac.app
   ```
   (Grant Accessibility permission once per clean signature — required for the global hotkey. The XCTest-host guard in `TFTMacApp.init()` skips this prompt during test runs.)

2. **Trigger the hotkey a few times**: press Cmd+Shift+T → popover appears → press again to dismiss. Repeat 5–10 times for a meaningful sample.

3. **Collect the signpost archive** (adjust timeframe as needed):
   ```bash
   log collect --start "5 min ago" --output popover.logarchive
   ```

4. **Open in Instruments**:
   ```bash
   open popover.logarchive
   ```
   Add the **Points of Interest** track. Filter to subsystem `asia.lab3.tftmac`, category `popover`, signpost name `popover.open`. Each BEGIN/END pair's duration is the hotkey-to-popover-visible latency.

5. **Read the numbers**: aim for <300ms "snappy" perceptual target. >500ms = investigate (SwiftUI view tree cost, NSStatusItem event loop, HotKey callback latency).

## Manual stopwatch fallback (Task 1.11 dogfood)

For the founder dogfood week (Task 1.11), signpost capture is overkill. Use a physical stopwatch or phone timer:

1. Close TFTMac completely (menu bar icon gone).
2. Launch the app (click .app or `open` from Terminal). Note perceived launch delay.
3. Press Cmd+Shift+T. Start stopwatch on keypress, stop when popover visually appears.
4. Repeat 10 trials. Record each in `docs/weekend-1-dogfood-notes.md` under a "Perceived latency (stopwatch)" section.
5. Target language for the log entry: "snappy" (<300ms), "acceptable" (300–500ms), "sluggish" (>500ms). Subjective but fast to capture during real play sessions.

## Resetting the XCTest baseline

`XCTApplicationLaunchMetric` records a baseline on the first passing run and diffs subsequent runs against it. To reset after an intentional perf change (e.g. bundling a larger JSON, adding an async init step):

1. Run the test once in Xcode (not xcodebuild) so the result lands in the Report navigator.
2. Open **Report navigator** (Cmd+9) → latest test run → expand `AppLaunchMetricTests` → click `testColdLaunchUnder500ms`.
3. In the metric detail pane, click **Set Baseline**. The next run uses the new average as reference.

Alternatively, delete the xcresult under `DerivedData/TFTMac-*/Logs/Test/` and re-run — a fresh result with no prior baseline passes unconditionally (sets a new baseline). Use sparingly; prefer the Report navigator path.

## Why not one XCUITest for both?

Short answer: `NSStatusItem` is unreachable from XCUITest on macOS 14+. Pre-spike probed every published workaround (host system UI server, own app's menu bar, systemwide accessibility tree) — all returned zero buttons. TCC is the enforcement layer and an automated CI workflow has no supervising GUI session to approve it.

Long answer: see `docs/pre-spike-xcuitest-menubar.md` §"Key findings" — Finding 3 documents the exhaustive host matrix, Finding 4 explains why even `axterm`-style AX client hacks won't work for CI.

Track A covers the metric that matters for launch-responsiveness NFR; Track B's in-process signpost is the practical substitute for click-driven popover latency, and the founder dogfood stopwatch is the sanity check before ship.
