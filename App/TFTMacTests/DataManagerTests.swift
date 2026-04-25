import XCTest
import Combine
@testable import TFTMac

final class DataManagerTests: XCTestCase {

    // MARK: - Static loadBundledJSON (backward compat — bundled JSON stays at 1.0.0)

    /// Happy path: the app's bundled fixture decodes into a usable TierList
    /// when loaded via DataManager. Verifies resource wired in project.yml
    /// AND that decoder config matches TierListDecodingTests expectations.
    @MainActor
    func testLoadBundledJSONReturnsTierList() {
        let tierList = DataManager.loadBundledJSON()
        XCTAssertEqual(tierList.comps.count, 10, "Bundled fixture should have 10 comps")
        XCTAssertEqual(tierList.schemaVersion, SchemaVersion(major: 1, minor: 0, patch: 0))
        XCTAssertEqual(tierList.eloBracket, "CHALLENGER")
        let firstComp = tierList.comps.first
        XCTAssertNotNil(firstComp)
        XCTAssertEqual(firstComp?.tier, .S)
        XCTAssertFalse(firstComp?.name.isEmpty ?? true)
    }

    /// Bundled JSON v1.0.0 has no `anomalies` key → forward-compat decoder
    /// must produce empty anomaly arrays, not a DecodingError.
    @MainActor
    func testBundledJSONCompsHaveEmptyAnomalies() {
        let tierList = DataManager.loadBundledJSON()
        for comp in tierList.comps {
            XCTAssertTrue(comp.anomalies.isEmpty,
                          "Bundled v1.0.0 JSON has no anomalies key — expect empty array for '\(comp.name)'")
        }
    }

    /// Bundled JSON v1.0.0 has no `region` key → forward-compat decoder
    /// must produce default "VN2", not a DecodingError.
    @MainActor
    func testBundledJSONRegionDefaultsToVN2() {
        let tierList = DataManager.loadBundledJSON()
        XCTAssertEqual(tierList.region, "VN2",
                       "Bundled v1.0.0 JSON missing 'region' key should default to 'VN2'")
    }

    /// Verify missing-resource guard: feeding a bundle without the fixture
    /// returns nil from Bundle.url() — this is the condition that triggers fatalError.
    func testMissingResourceTriggersGuardFailure() {
        let testBundle = Bundle(for: type(of: self))
        XCTAssertNil(testBundle.url(forResource: "sample-tier-list", withExtension: "json"),
                     "Test bundle should NOT contain the fixture — otherwise can't verify guard")
    }

    // MARK: - ObservableObject initial state

    /// On init, DataManager immediately publishes the bundled TierList
    /// (synchronous load guarantees non-nil before any async fetch completes).
    @MainActor
    func testInitialTierListIsFromBundledJSON() {
        let dm = DataManager()
        XCTAssertEqual(dm.tierList.comps.count, 10)
        XCTAssertEqual(dm.tierList.schemaVersion, SchemaVersion(major: 1, minor: 0, patch: 0))
    }

    /// On init, bannerState starts as .fresh (before any fetch attempt resolves).
    @MainActor
    func testInitialBannerStateIsFresh() {
        let dm = DataManager()
        XCTAssertEqual(dm.bannerState, .fresh)
    }

    // MARK: - BannerState equality

    func testBannerStateEquality() {
        XCTAssertEqual(BannerState.fresh, BannerState.fresh)
        XCTAssertEqual(BannerState.offlineBundled, BannerState.offlineBundled)
        XCTAssertEqual(BannerState.updateRequired, BannerState.updateRequired)
        XCTAssertEqual(BannerState.lastUpdated(hoursAgo: 3), BannerState.lastUpdated(hoursAgo: 3))
        XCTAssertNotEqual(BannerState.lastUpdated(hoursAgo: 3), BannerState.lastUpdated(hoursAgo: 5))
        XCTAssertEqual(BannerState.staleData(daysAgo: 2), BannerState.staleData(daysAgo: 2))
        XCTAssertNotEqual(BannerState.staleData(daysAgo: 2), BannerState.staleData(daysAgo: 4))
        XCTAssertNotEqual(BannerState.fresh, BannerState.offlineBundled)
    }
}
