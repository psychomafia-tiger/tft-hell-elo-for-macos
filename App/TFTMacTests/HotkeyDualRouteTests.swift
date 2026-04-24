import XCTest
@testable import TFTMac

/// Wave 5b — hotkey dual-route assertion.
///
/// D1 decision: every Cmd+Shift+T fires BOTH popover activation path AND
/// overlay toggle path. No TFT-process detection heuristic (rejected as
/// YAGNI given we can't reliably detect TFT foreground state without
/// polling).
///
/// Test approach: TFTMacApp's hotkey closure composes popover-route + overlay-
/// route. We reconstruct the composition in isolation here — `HotkeyRegistrar`
/// itself is tested in `HotkeyRegistrationTests`, this file focuses on the
/// dual-route contract.
final class HotkeyDualRouteTests: XCTestCase {

    /// Dual-route composition: fire should invoke popoverRoute FIRST
    /// (matches production order: NSApp.activate before overlay.toggle).
    func testFireInvokesBothRoutesInOrder() {
        var callOrder: [String] = []
        let popoverRoute = { callOrder.append("popover") }
        let overlayRoute = { callOrder.append("overlay") }

        let fire = {
            popoverRoute()
            overlayRoute()
        }
        fire()

        XCTAssertEqual(callOrder, ["popover", "overlay"],
                       "Dual-route must fire popover first, then overlay (matches TFTMacApp composition)")
    }

    /// 10 rapid hotkey fires — popover counter increments 10, overlay controller
    /// ends hidden (10 toggles from initial false = even → false).
    func testTenFiresKeepsOverlayStateCorrect() {
        let controller = OverlayWindowController()
        var popoverFires = 0

        let fire = {
            popoverFires += 1
            controller.toggle()
        }

        for _ in 0..<10 { fire() }

        XCTAssertEqual(popoverFires, 10, "popover route fired exactly 10 times")
        XCTAssertFalse(controller.isVisible,
                       "10 toggles from initial-hidden state must end hidden (no orphan)")
    }

    /// 11 rapid fires — overlay ends visible (odd count).
    /// Catches a regression where toggle() accidentally becomes a no-op under
    /// rapid repeated invocation.
    func testElevenFiresEndsOverlayVisible() {
        let controller = OverlayWindowController()
        var popoverFires = 0

        let fire = {
            popoverFires += 1
            controller.toggle()
        }

        for _ in 0..<11 { fire() }

        XCTAssertEqual(popoverFires, 11)
        XCTAssertTrue(controller.isVisible,
                      "11 toggles from hidden must end visible")
    }
}
