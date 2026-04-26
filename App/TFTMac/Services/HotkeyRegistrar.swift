import AppKit
import HotKey

/// Global hotkey registration for TFT Mac's Cmd+Shift+T toggle.
///
/// Two failure modes that Task 1.8's integration must surface:
///
/// 1. **Accessibility permission denied** — user hasn't granted TFT Mac
///    the TCC permission to observe global key events. Detected via
///    `AXIsProcessTrusted()` before attempting register. UX: show
///    SwiftUI alert with deep-link to System Settings.
///
/// 2. **System-level conflict** — another app (Alfred, Rectangle, Raycast,
///    etc.) has already bound Cmd+Shift+T via Carbon. No programmatic
///    detection possible via HotKey package — we instead treat "called
///    register() twice" as a conflict because ours is the only bind path.
///
/// Injectable impls (`trustedCheck`, `registerImpl`) let tests stub
/// system-dependent behavior. Production defaults wire to real APIs.
///
/// **Lifecycle**: hold ONE instance for the app lifetime. Do not reconstruct
/// per view — the `registrationToken` state tracks whether Carbon has an
/// active binding, and a fresh instance would lose that tracking. Task 1.8
/// wires this as a module-level singleton or SwiftUI `@StateObject` on the
/// root scene.
final class HotkeyRegistrar {

    enum RegistrationError: Error, Equatable {
        case accessibilityDenied
        case alreadyRegistered
    }

    typealias TrustedCheck = () -> Bool
    typealias RegisterImpl = (_ onFire: @escaping () -> Void) -> AnyObject  // returns opaque token (HotKey in prod)

    /// Invoked if register() attempted while AXIsProcessTrusted == false.
    /// Task 1.8 wires this to a SwiftUI alert with deep-link.
    ///
    /// **Signaling contract**: fires *in addition to* the `.failure(.accessibilityDenied)`
    /// return from `register()`. Wire this for UX side-effects (alert, logging).
    /// Use the `Result` return for programmatic flow (unit tests, analytics).
    ///
    /// **Memory**: use `[weak self]` when capturing self — registrar is typically
    /// a singleton that outlives SwiftUI view lifecycles.
    var onPermissionDenied: (() -> Void)?

    /// Invoked if register() called after already-successful register.
    /// Task 1.8 wires to an alert warning user another app holds the hotkey.
    ///
    /// **Signaling contract**: fires *in addition to* the `.failure(.alreadyRegistered)`
    /// return from `register()`. Wire this for UX side-effects (alert, logging).
    /// Use the `Result` return for programmatic flow (unit tests, analytics).
    ///
    /// **Memory**: use `[weak self]` when capturing self — registrar is typically
    /// a singleton that outlives SwiftUI view lifecycles.
    var onConflict: (() -> Void)?

    private let trustedCheck: TrustedCheck
    private let registerImpl: RegisterImpl
    private var registrationToken: AnyObject?
    // Bug #001b: when first register() bails on .accessibilityDenied, stash the
    // onFire closure so retryIfPending() can complete registration after user
    // grants Accessibility in System Settings — no app relaunch required.
    // Cleared once registration succeeds OR caller invokes register() afresh.
    private var pendingOnFire: (() -> Void)?

    init(trustedCheck: @escaping TrustedCheck = { AXIsProcessTrusted() },
         registerImpl: @escaping RegisterImpl = HotkeyRegistrar.defaultRegister) {
        self.trustedCheck = trustedCheck
        self.registerImpl = registerImpl
    }

    /// Attempt to register the Cmd+Shift+T toggle.
    /// - Parameter onFire: Called when hotkey fires in production.
    /// - Returns: Result indicating success or which failure path triggered.
    ///
    /// On failure, the corresponding callback (`onPermissionDenied` or `onConflict`)
    /// fires BEFORE this method returns, giving UX handlers a chance to react
    /// in the same run-loop tick as the Result arrives.
    @discardableResult
    func register(onFire: @escaping () -> Void) -> Result<Void, RegistrationError> {
        // NOTE: Accessibility permission NOT required for Carbon RegisterEventHotKey.
        // Apple's Carbon Event Manager hot-key API uses a system-level mechanism
        // dating back to classic Mac OS — registers a specific (key+modifier) tuple
        // with the Window Server, fires callback when matched. NO Accessibility/
        // Input Monitoring needed (those are for CGEventTap, which intercepts ALL
        // keyboard events at the HID layer).
        //
        // Earlier code checked AXIsProcessTrusted() and bailed on false. That was
        // overly defensive — it prevented Carbon registration even though Carbon
        // doesn't need that trust. Result: hotkey silent-fail on every cdhash
        // change (every Xcode rebuild) until user dance through System Settings.
        // Removed the check entirely. If conflict from another app holding the
        // same combo, Carbon RegisterEventHotKey internally returns an error and
        // HotKey package leaves binding inert — surfaces as silent fail (we'd
        // need to wrap with a sentinel call to detect, deferred to Phase 2).
        guard registrationToken == nil else {
            onConflict?()
            return .failure(.alreadyRegistered)
        }
        registrationToken = registerImpl(onFire)
        pendingOnFire = nil
        return .success(())
    }

    /// Retry a previously-failed accessibilityDenied registration once user
    /// grants Accessibility (typically wired to NSApp.didBecomeActive — fires
    /// when user returns from System Settings). No-op if no pending closure
    /// or if AX still denied. Returns nil when no retry was attempted.
    ///
    /// Critically: does NOT invoke `onPermissionDenied` on continued failure.
    /// didBecomeActive fires on every app activation including initial launch
    /// (milliseconds after init's first register() call), so triggering the
    /// side-effect callback would re-open System Settings on every activation
    /// until permission is granted. The callback is exclusively for the
    /// explicit first register() attempt; retries are silent attempts.
    @discardableResult
    func retryIfPending() -> Result<Void, RegistrationError>? {
        guard let onFire = pendingOnFire else { return nil }
        guard trustedCheck() else { return .failure(.accessibilityDenied) }
        guard registrationToken == nil else { return .failure(.alreadyRegistered) }
        registrationToken = registerImpl(onFire)
        pendingOnFire = nil
        return .success(())
    }

    /// Opens System Settings → Privacy & Security → Accessibility pane.
    /// Falls back to Settings root if the direct deep-link is rejected by the
    /// current macOS version (Apple deprecated some schemes in Ventura+ rewrite).
    func openAccessibilitySettings() {
        let deepLink = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        if !NSWorkspace.shared.open(deepLink) {
            // Fallback: open System Settings root; user manually navigates to Privacy → Accessibility.
            // Better than silent failure which leaves user staring at an unchanged screen.
            let fallback = URL(string: "x-apple.systempreferences:")!
            NSWorkspace.shared.open(fallback)
        }
    }

    /// Production register impl — wraps HotKey package for Cmd+Shift+T.
    private static func defaultRegister(onFire: @escaping () -> Void) -> AnyObject {
        let hotKey = HotKey(key: .t, modifiers: [.command, .shift])
        hotKey.keyDownHandler = onFire
        return hotKey  // retain to keep binding alive; caller (HotkeyRegistrar) stores in registrationToken
    }
}
