import XCTest
@testable import TFTMac

final class HotkeyRegistrationTests: XCTestCase {

    // MARK: - Happy path

    func testRegisterCmdShiftTSucceeds() {
        let registrar = HotkeyRegistrar(
            trustedCheck: { true },
            registerImpl: { _ in "stub-token" }
        )

        let result = registrar.register { }

        guard case .success = result else {
            return XCTFail("Expected .success, got \(result)")
        }
    }

    // MARK: - Conflict detection

    func testRegisterTwiceReturnsConflict() {
        let registrar = HotkeyRegistrar(
            trustedCheck: { true },
            registerImpl: { _ in "stub-token" }
        )

        _ = registrar.register { } // first — succeeds
        let secondResult = registrar.register { } // second — conflict

        guard case .failure(.alreadyRegistered) = secondResult else {
            return XCTFail("Expected .alreadyRegistered error, got \(secondResult)")
        }
    }

    func testConflictInvokesWarningCallback() {
        let registrar = HotkeyRegistrar(
            trustedCheck: { true },
            registerImpl: { _ in "stub-token" }
        )

        var conflictCallbackFired = false
        registrar.onConflict = { conflictCallbackFired = true }

        _ = registrar.register { } // first
        _ = registrar.register { } // second triggers conflict

        XCTAssertTrue(conflictCallbackFired, "onConflict should fire on second register attempt")
    }

    // MARK: - Permission detection

    func testAccessibilityDeniedInvokesPermissionCallback() {
        let registrar = HotkeyRegistrar(
            trustedCheck: { false },  // TCC not granted
            registerImpl: { _ in "stub-token" }
        )

        var permissionCallbackFired = false
        registrar.onPermissionDenied = { permissionCallbackFired = true }

        let result = registrar.register { }

        XCTAssertTrue(permissionCallbackFired, "onPermissionDenied should fire when trustedCheck returns false")
        guard case .failure(.accessibilityDenied) = result else {
            return XCTFail("Expected .accessibilityDenied error, got \(result)")
        }
    }

    // MARK: - Integration smoke

    func testPermissionDeniedBypassesRegistration() {
        // Verify that when permission denied, registerImpl is NOT called
        // (no-op on registration — prevents empty-token state).
        var registerImplCalled = false
        let registrar = HotkeyRegistrar(
            trustedCheck: { false },
            registerImpl: { _ in
                registerImplCalled = true
                return "stub-token"
            }
        )

        _ = registrar.register { }

        XCTAssertFalse(registerImplCalled, "registerImpl must not be invoked when permission denied")
    }
}
