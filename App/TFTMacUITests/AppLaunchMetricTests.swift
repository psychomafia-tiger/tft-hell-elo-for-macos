import XCTest

/// Track A — cold launch latency gate.
///
/// Why a full XCTestCase for one measure block: `XCTApplicationLaunchMetric()`
/// only works inside `measure(metrics:)` and that API requires a live
/// `XCTestCase` host. The 5-launch average (SDK default) gives a stable
/// baseline the dogfood tester cannot replicate with a stopwatch.
///
/// Note: XCTest baselines are stored per-machine in a local plist (not
/// checked in). A fresh CI runner or new dev laptop records its own
/// baseline on first run; baselines are not portable across hosts.
///
/// Track B (popover-open latency) is measured via `os_signpost` emitted by
/// `TFTMacApp.register(onFire:)` and `TierListPopover.onAppear`. See
/// README.md in this folder for the signpost + Instruments workflow —
/// XCUITest cannot drive NSStatusItem on macOS 14+ (TCC/AX gates block
/// accessibility discovery of menu-bar items), proven in the Phase 0 spike
/// at `docs/pre-spike-xcuitest-menubar.md`.
///
/// Perf budget: ≤500ms cold launch (NFR-3). Pre-spike baseline on a
/// near-empty throwaway app measured 194ms (σ=6.8%), leaving TFTMac
/// ~300ms headroom for DataManager.loadBundledJSON() + SwiftUI view tree
/// construction. If this test regresses above 500ms, first suspect:
/// sample-tier-list.json size growth, DataManager adding async work,
/// or an unintended `@main App` init side-effect.
final class AppLaunchMetricTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Cold-launch gate: 5-launch average must stay ≤500ms.
    ///
    /// XCTest records the baseline on first run; subsequent runs compare
    /// against it. To reset baseline after an intentional perf change,
    /// open Xcode's Report navigator → this test → "Set Baseline".
    func testColdLaunchUnder500ms() throws {
        let metric = XCTApplicationLaunchMetric()
        measure(metrics: [metric]) {
            XCUIApplication().launch()
        }
    }
}
