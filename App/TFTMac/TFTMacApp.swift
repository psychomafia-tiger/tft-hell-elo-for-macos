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
    private let tierList: TierList = DataManager.loadBundledJSON()

    // HotkeyRegistrar held as stored property so its lifetime matches the
    // app process. See HotkeyRegistrar class-level doc: "hold ONE instance
    // for app lifetime" — fresh instances would drop the Carbon binding.
    private let hotkeyRegistrar = HotkeyRegistrar()

    init() {
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

        // Register the global hotkey. MenuBarExtra does not expose a
        // programmatic "open popover" API on macOS 14, so the hotkey's UX
        // role for Phase 1 is "bring the app to front so the user's click
        // on the menu bar icon is one step away". Task 1.10 may explore
        // direct popover toggling via a bridged NSStatusItem if warranted.
        _ = hotkeyRegistrar.register {
            os_signpost(.begin, log: PopoverSignpost.log, name: PopoverSignpost.name,
                        signpostID: PopoverSignpost.id, "Hotkey fired")
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    var body: some Scene {
        MenuBarExtra("TFT Hell Elo", systemImage: "chart.bar.xaxis") {
            TierListPopover(tierList: tierList)
        }
        .menuBarExtraStyle(.window)  // popover-style (window), not dropdown menu
    }
}
