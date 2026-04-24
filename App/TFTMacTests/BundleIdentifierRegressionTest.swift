import XCTest
@testable import TFTMac

/// Wave 5a regression guard — bundle ID rename (`asia.lab3.tftmac` → `io.psychomafia.tfthellelo`).
///
/// Why a dedicated test: bundle ID is set in 3 places (project.yml `bundleIdPrefix`,
/// project.yml target `PRODUCT_BUNDLE_IDENTIFIER`, Info.plist via `$(PRODUCT_BUNDLE_IDENTIFIER)`).
/// If a future edit to project.yml drifts from Info.plist — e.g. someone forgets
/// `xcodegen generate` after tweaking prefix — the app ships with the wrong ID,
/// LaunchServices registers it as a distinct app, and dogfood testers see a
/// mystery second icon. This test fails at build time before that lands.
///
/// Test host: TFTMac app target (via BUNDLE_LOADER). `Bundle.main` in XCTest
/// host context = the hosted TFTMac.app bundle, so `.bundleIdentifier` reflects
/// the production binary's ID, not the test bundle's `io.psychomafia.tfthellelo.tests`.
final class BundleIdentifierRegressionTest: XCTestCase {

    /// Expected ID locked by Wave 5a plan (D3 decision gate).
    /// Change this ONLY if the bundle ID is intentionally re-renamed —
    /// update docs/naming-conventions.md in the same commit.
    private let expectedBundleID = "io.psychomafia.tfthellelo"

    func testAppBundleIdentifierMatchesWave5aRename() throws {
        // Bundle.main in a unit-test-host context resolves to the app that hosts
        // the test bundle — i.e. TFTMac.app, whose CFBundleIdentifier comes from
        // project.yml's PRODUCT_BUNDLE_IDENTIFIER substituted into Info.plist.
        //
        // In rare CI setups BUNDLE_LOADER is not wired and Bundle.main may point
        // to xctest helper itself; guard with unwrap + descriptive failure.
        let actual = Bundle.main.bundleIdentifier
        XCTAssertEqual(actual, expectedBundleID,
                       "Bundle ID drift detected. Expected \(expectedBundleID), got \(actual ?? "nil"). " +
                       "Likely cause: project.yml changed without running `xcodegen generate`, " +
                       "or Info.plist edited manually out of sync. See docs/naming-conventions.md.")
    }
}
