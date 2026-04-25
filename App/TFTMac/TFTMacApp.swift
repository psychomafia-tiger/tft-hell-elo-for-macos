import SwiftUI
import AppKit
import os

/// TFT Mac Companion — menu bar app entry point.
///
/// Phase 03 wiring:
/// 1. `DataManager` (@StateObject) — orchestrates remote fetch + 12h poll +
///    disk cache + bundled fallback. `.start()` called in DataManager.init().
/// 2. `MenuBarExtra(.window)` scene — popover-style, 440×600 card stack.
///    `TierListPopover` receives DataManager via `.environmentObject(dataManager)`.
/// 3. `HotkeyRegistrar` — held as stored property so Carbon binding lives for
///    app lifetime. Dual-route: overlay toggle + (future) popover.
/// 4. `OverlayWindowController` — eager-init with same DataManager for live updates.
///
/// **os_signpost Track B**: `.begin` emitted in the hotkey handler here and
/// `.end` emitted in TierListPopover.onAppear. Task 1.10 reads the interval
/// via Instruments Points of Interest to validate the hotkey-to-visible
/// latency budget (<200ms target, matches SwiftUI "snappy" perception band).
@main
struct TFTMacApp: App {
    // Phase 03: DataManager is @StateObject so SwiftUI manages its lifetime and
    // propagates @Published changes to all views via environmentObject injection.
    // .start() is called in DataManager.init() — immediate fetch on app launch
    // without relying on onAppear (MenuBarExtra window may not appear until hotkey).
    @StateObject private var dataManager = DataManager()

    // HotkeyRegistrar held as stored property so its lifetime matches the
    // app process. See HotkeyRegistrar class-level doc: "hold ONE instance
    // for app lifetime" — fresh instances would drop the Carbon binding.
    private let hotkeyRegistrar: HotkeyRegistrar

    // Wave 5b eager-init: overlay panel built at app launch (D2) so first
    // Cmd+Shift+T shows in <50ms. Phase 03: passes DataManager for live updates.
    // Note: @StateObject is not accessible in stored-property initializer, so
    // overlayController is stored as var and assigned after super-init equivalent.
    // Swift @main App doesn't have a designated init chain — we use a lazy pattern:
    // overlayController is built in init() using a temporary DataManager reference
    // captured via the hotkeyRegistrar closure. HOWEVER, @StateObject wrappedValue
    // is not accessible before body — use a plain stored DataManager instead.
    //
    // Resolution: OverlayWindowController.dataManager is set post-init via
    // a stored property approach. We create overlayController with nil dataManager
    // first, then wire it after @StateObject is available via body. But that
    // delays by one render cycle.
    //
    // KISS resolution: store overlayController with the DataManager directly.
    // @StateObject projectedValue/_wrappedValue is available after init completes.
    // We use a two-step: create DataManager eagerly as a plain let, pass to both
    // overlayController and the @StateObject wrapper via _dataManager = StateObject(wrappedValue:).
    private let overlayController: OverlayWindowController

    init() {
        let dm = DataManager()
        _dataManager = StateObject(wrappedValue: dm)
        self.hotkeyRegistrar = HotkeyRegistrar()
        self.overlayController = OverlayWindowController(dataManager: dm)

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
            TierListPopover()
                .environmentObject(dataManager)
        }
        .menuBarExtraStyle(.window)  // popover-style (window), not dropdown menu
    }
}
