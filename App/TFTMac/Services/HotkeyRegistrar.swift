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
final class HotkeyRegistrar {

    enum RegistrationError: Error, Equatable {
        case accessibilityDenied
        case alreadyRegistered
    }

    typealias TrustedCheck = () -> Bool
    typealias RegisterImpl = (_ onFire: @escaping () -> Void) -> Any  // returns opaque token (HotKey in prod)

    /// Invoked if register() attempted while AXIsProcessTrusted == false.
    /// Task 1.8 wires this to a SwiftUI alert with deep-link.
    var onPermissionDenied: (() -> Void)?

    /// Invoked if register() called after already-successful register.
    /// Task 1.8 wires to an alert warning user another app holds the hotkey.
    var onConflict: (() -> Void)?

    private let trustedCheck: TrustedCheck
    private let registerImpl: RegisterImpl
    private var registrationToken: Any?

    init(trustedCheck: @escaping TrustedCheck = { AXIsProcessTrusted() },
         registerImpl: @escaping RegisterImpl = HotkeyRegistrar.defaultRegister) {
        self.trustedCheck = trustedCheck
        self.registerImpl = registerImpl
    }

    /// Attempt to register the Cmd+Shift+T toggle.
    /// - Parameter onFire: Called when hotkey fires in production.
    /// - Returns: Result indicating success or which failure path triggered.
    @discardableResult
    func register(onFire: @escaping () -> Void) -> Result<Void, RegistrationError> {
        guard trustedCheck() else {
            onPermissionDenied?()
            return .failure(.accessibilityDenied)
        }
        guard registrationToken == nil else {
            onConflict?()
            return .failure(.alreadyRegistered)
        }
        registrationToken = registerImpl(onFire)
        return .success(())
    }

    /// Opens the System Settings → Privacy & Security → Accessibility pane.
    /// Intended to be called from the permission-denied alert's primary button.
    func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }

    /// Production register impl — wraps HotKey package for Cmd+Shift+T.
    private static func defaultRegister(onFire: @escaping () -> Void) -> Any {
        let hotKey = HotKey(key: .t, modifiers: [.command, .shift])
        hotKey.keyDownHandler = onFire
        return hotKey  // retain to keep binding alive; caller (HotkeyRegistrar) stores in registrationToken
    }
}
