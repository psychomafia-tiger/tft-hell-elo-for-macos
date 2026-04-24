import XCTest
import AppKit
@testable import TFTMac

/// Wave 5b — OverlayWindowController state machine must remain consistent under
/// rapid hotkey spam. 10+ consecutive toggles can orphan an NSPanel if show/hide
/// state drifts from panel's actual on-screen state (e.g. a race between
/// orderFront and isVisible flag update).
///
/// Test strategy: construct real OverlayWindowController (production path) and
/// toggle N times. After even-count toggles, `isVisible` must reflect the cycle
/// parity. NSPanel is created but never actually placed on screen during unit
/// test (orderFrontRegardless in headless XCTest host is a no-op visually;
/// the `isVisible` flag still flips as expected since we track it ourselves).
final class OverlayWindowControllerTests: XCTestCase {

    func testInitialStateHidden() {
        let controller = OverlayWindowController()
        XCTAssertFalse(controller.isVisible, "Eager init must NOT auto-show panel")
    }

    func testShowSetsIsVisibleTrue() {
        let controller = OverlayWindowController()
        controller.show()
        XCTAssertTrue(controller.isVisible)
    }

    func testHideSetsIsVisibleFalse() {
        let controller = OverlayWindowController()
        controller.show()
        controller.hide()
        XCTAssertFalse(controller.isVisible)
    }

    func testToggleFlipsState() {
        let controller = OverlayWindowController()
        XCTAssertFalse(controller.isVisible)
        controller.toggle()
        XCTAssertTrue(controller.isVisible)
        controller.toggle()
        XCTAssertFalse(controller.isVisible)
    }

    /// 10 pair-toggles (20 calls) — simulates spam-tapping Cmd+Shift+T during
    /// a hectic roll-down. Plan requires stable state after 10 iterations.
    func testTwentyTogglesLeaveStateConsistent() {
        let controller = OverlayWindowController()
        for _ in 0..<20 {
            controller.toggle()
        }
        XCTAssertFalse(controller.isVisible,
                       "20 toggles (even) must end at hidden state; odd drift indicates orphan panel")
    }

    /// 21 toggles (odd) — must end visible. Catches an off-by-one where
    /// toggle() accidentally ignores the first call (e.g. due to lazy init).
    func testTwentyOneTogglesEndsVisible() {
        let controller = OverlayWindowController()
        for _ in 0..<21 {
            controller.toggle()
        }
        XCTAssertTrue(controller.isVisible,
                      "21 toggles (odd) must end at visible state")
    }

    /// Skip-panel-instantiation path for pure state logic tests. Not strictly
    /// needed given above tests pass with real panel, but documents the escape
    /// hatch for future state-only tests that don't want to stand up AppKit.
    func testSkipPanelInstantiationInitsCleanly() {
        let controller = OverlayWindowController(skipPanelInstantiation: true)
        XCTAssertFalse(controller.isVisible)
        // show/hide are no-ops on nil panel but must not crash
        controller.show()
        XCTAssertTrue(controller.isVisible, "isVisible flag flips even when panel is nil")
        controller.hide()
        XCTAssertFalse(controller.isVisible)
    }
}
