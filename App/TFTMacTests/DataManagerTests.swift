import XCTest
import Combine
@testable import TFTMac

final class DataManagerTests: XCTestCase {

    // MARK: - Static loadBundledJSON (Phase 2 T10 — fixture refreshed to 1.2.0)

    /// Happy path: the app's bundled fixture decodes into a usable TierList
    /// when loaded via DataManager. Verifies resource wired in project.yml
    /// AND that decoder config matches TierListDecodingTests expectations.
    @MainActor
    func testLoadBundledJSONReturnsTierList() {
        let tierList = DataManager.loadBundledJSON()
        XCTAssertGreaterThan(tierList.comps.count, 0, "Bundled fixture should have ≥1 comp")
        XCTAssertEqual(tierList.schemaVersion, SchemaVersion(major: 1, minor: 4, patch: 0))
        XCTAssertEqual(tierList.eloBracket, "CHALLENGER")
        let firstComp = tierList.comps.first
        XCTAssertNotNil(firstComp)
        XCTAssertFalse(firstComp?.name.isEmpty ?? true)
    }

    /// Schema 1.2.0 fixture must populate `traits[]` for at least one comp
    /// (data contract for `TraitChip` rendering in `CompCard`).
    @MainActor
    func testBundledJSONCompsHaveTraits() {
        let tierList = DataManager.loadBundledJSON()
        let withTraits = tierList.comps.filter { !$0.traits.isEmpty }
        XCTAssertGreaterThan(withTraits.count, 0,
                             "Schema 1.2.0 fixture must populate traits[] on at least one comp")
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
        XCTAssertGreaterThan(dm.tierList.comps.count, 0)
        XCTAssertEqual(dm.tierList.schemaVersion, SchemaVersion(major: 1, minor: 4, patch: 0))
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
