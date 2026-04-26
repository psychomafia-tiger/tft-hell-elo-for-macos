import XCTest
@testable import TFTMac

final class HotkeyRegistrationTests: XCTestCase {

    /// Stub token class — any AnyObject will do; we just need something ARC-retainable.
    private final class StubToken {}

    // MARK: - Happy path

    func testRegisterCmdShiftTSucceeds() {
        let registrar = HotkeyRegistrar(
            trustedCheck: { true },
            registerImpl: { _ in StubToken() }
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
            registerImpl: { _ in StubToken() }
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
            registerImpl: { _ in StubToken() }
        )

        var conflictCallbackFired = false
        registrar.onConflict = { conflictCallbackFired = true }

        _ = registrar.register { } // first
        _ = registrar.register { } // second triggers conflict

        XCTAssertTrue(conflictCallbackFired, "onConflict should fire on second register attempt")
    }

    // MARK: - Accessibility-not-required (Carbon hotkey)
    //
    // Removed earlier "permission denied" tests — Carbon RegisterEventHotKey
    // does NOT require Accessibility permission. Earlier guard was overly
    // defensive; see HotkeyRegistrar.register() doc-comment for full reasoning.
    // Tests below verify register() proceeds regardless of trustedCheck value.

    func testRegisterSucceedsEvenWhenTrustedCheckReturnsFalse() {
        // Carbon doesn't need AX trust — registration proceeds and Carbon API
        // does the actual work (or fails at Carbon level, surfaced separately).
        let registrar = HotkeyRegistrar(
            trustedCheck: { false },  // AX trust irrelevant for Carbon
            registerImpl: { _ in StubToken() }
        )

        let result = registrar.register { }

        guard case .success = result else {
            return XCTFail("Expected .success regardless of trustedCheck, got \(result)")
        }
    }
}
