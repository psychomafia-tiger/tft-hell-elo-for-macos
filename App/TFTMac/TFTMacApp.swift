import SwiftUI
import AppKit
import os

/// TFT Mac Companion — menu bar app entry point.
///
/// Task 1.8 wires three subsystems together:
/// 1. `DataManager.loadBundledJSON()` — synchronous decode of bundled sample
///    (no Task.detached per eng review C1: the data is static, in-binary,
///    ~8 KB — async machinery is over-engineering for ms-level work).
/// 2. `MenuBarExtra(.window)` scene — popover-style rather than dropdown
///    menu, matching the 440×600 wireframe card stack.
/// 3. `HotkeyRegistrar` — held as an @main-scoped stored property so its
///    Carbon binding lives for the app's entire lifetime. Reconstructing
///    per view would lose the `registrationToken` state.
///
/// **os_signpost Track B**: `.begin` emitted in the hotkey handler here and
/// `.end` emitted in TierListPopover.onAppear. Task 1.10 reads the interval
/// via Instruments Points of Interest to validate the hotkey-to-visible
/// latency budget (<200ms target, matches SwiftUI "snappy" perception band).
@main
struct TFTMacApp: App {
    // Synchronous bundle load. DataManager fatalError's on missing resource,
    // which is a build-time bug (impossible in shipped build; CI would fail
    // first). No async wrapper needed — the decode is <10ms on M1.
    private let tierList: TierList

    // HotkeyRegistrar held as stored property so its lifetime matches the
    // app process. See HotkeyRegistrar class-level doc: "hold ONE instance
    // for app lifetime" — fresh instances would drop the Carbon binding.
    private let hotkeyRegistrar: HotkeyRegistrar

    // Wave 5b eager-init + Wave 5c tier-list injection: the overlay panel is
    // built at app launch (D2) with the same `CompListView` the popover uses
    // (D4), so first Cmd+Shift+T shows in <50ms rendering identical cards.
    private let overlayController: OverlayWindowController

    init() {
        let loadedTierList = DataManager.loadBundledJSON()
        self.tierList = loadedTierList
        self.hotkeyRegistrar = HotkeyRegistrar()
        self.overlayController = OverlayWindowController(tierList: loadedTierList)

        // Skip hotkey registration when running as XCTest host. Every rebuild
        // produces a new bundle signature, so TCC treats the test-host binary
        // as a fresh app and `AXIsProcessTrusted()` returns false — which
        // would trigger `openAccessibilitySettings()` and spam System Settings
        // on every test run. Tests exercise HotkeyRegistrar via injected stubs
        // (HotkeyRegistrationTests), not via this production path.
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil { return }

        // Wire failure callbacks *before* register() so they fire on the first
        // register attempt if permission is missing / conflict exists.
        hotkeyRegistrar.onPermissionDenied = { [hotkeyRegistrar] in
            // Direct remedy: open Accessibility pane. Phase 3 may wrap this in
            // a SwiftUI Alert scene for friendlier copy; for now, the system
            // settings open itself communicates the required action.
            NSLog("TFT Hell Elo: Accessibility permission denied — opening System Settings")
            hotkeyRegistrar.openAccessibilitySettings()
        }
        hotkeyRegistrar.onConflict = {
            // Another app holds Cmd+Shift+T (Alfred/Raycast/Rectangle are the
            // usual suspects). Log so founder sees in Console during dogfood.
            NSLog("TFT Hell Elo: Cmd+Shift+T already bound by another app (Alfred/Raycast/Rectangle?)")
        }

        // Register the global hotkey with **dual-route** per Wave 5b D1 decision:
        // every Cmd+Shift+T fires BOTH routes unconditionally (no TFT-process
        // detection heuristic). User gets popover via menu bar activation AND
        // fullscreen overlay via NSPanel toggle — whichever is reachable in the
        // current display context renders.
        //
        // Popover route: NSApp.activate brings TFTMac to front; user still needs
        // to click the menu bar icon (MenuBarExtra programmatic toggle is not
        // public API on macOS 14). This is unchanged from Wave 1-4 behavior.
        //
        // Overlay route: OverlayWindowController.toggle flips NSPanel visibility
        // via orderFront/orderOut — panel sits at overlayWindowLevel and renders
        // above TFT's borderless/fullscreen window (the dogfood F1 blocker).
        //
        // Idempotency: 10 consecutive Cmd+Shift+T presses keep overlay state
        // consistent (assert test: HotkeyDualRouteTests.testToggleTwentyFiresStable).
        // Wave 5d fix (F1 root cause): KHÔNG gọi NSApp.activate trong hotkey path.
        // NSApp.activate(ignoringOtherApps:) steal focus từ TFT → game bị
        // minimize/hide xuống (Borderless) hoặc panel show ở wrong Space
        // (Fullscreen Native Spaces). Panel với .nonactivatingPanel styleMask +
        // orderFrontRegardless() đã đủ để show panel ABOVE game mà KHÔNG cần
        // app activation — đây là pattern overlay đúng (giống TFTactics Win:
        // overlay đè lên game, game vẫn frontmost, keyboard vẫn vào game).
        //
        // Trade-off: MenuBarExtra popover route mất "auto-foreground" — user
        // muốn mở popover phải click menu bar icon thủ công. Acceptable vì
        // (a) overlay route render same content (CompListView shared), và
        // (b) popover route chỉ là backup khi overlay disabled trong Settings
        // (Phase 3 feature). Hotkey use case = trigger overlay over game.
        _ = hotkeyRegistrar.register { [overlayController] in
            os_signpost(.begin, log: PopoverSignpost.log, name: PopoverSignpost.name,
                        signpostID: PopoverSignpost.id, "Hotkey fired")
            overlayController.toggle()  // overlay-only — no app activation
        }
    }

    var body: some Scene {
        MenuBarExtra("TFT Hell Elo", systemImage: "chart.bar.xaxis") {
            TierListPopover(tierList: tierList)
        }
        .menuBarExtraStyle(.window)  // popover-style (window), not dropdown menu
    }
}
