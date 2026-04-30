import XCTest
@testable import TFTMac

final class TraitCatalogTests: XCTestCase {

    func test_loadedAtLeast30Traits() {
        XCTAssertGreaterThanOrEqual(TraitCatalog.entries.count, 30,
            "Bundled set17-traits.json should have all Set 17 traits (≥30)")
    }

    func test_displayNameKnownTrait() {
        // TFT17_APTrait is internally "Replicator" (NOT "APTrait")
        XCTAssertEqual(TraitCatalog.displayName(forApiName: "TFT17_APTrait"), "Replicator")
    }

    func test_displayNameFallbackForUnknown() {
        XCTAssertEqual(TraitCatalog.displayName(forApiName: "TFT17_Mystery"), "Mystery")
    }

    func test_iconTokenKnownTrait() {
        XCTAssertEqual(TraitCatalog.iconToken(forApiName: "TFT17_VexUniqueTrait"), "doomer")
    }

    func test_iconTokenUnknownReturnsNil() {
        XCTAssertNil(TraitCatalog.iconToken(forApiName: "TFT99_Bogus"))
    }
}
