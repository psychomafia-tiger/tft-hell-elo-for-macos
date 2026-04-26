import XCTest
@testable import TFTMac

final class ChampionCatalogDataDrivenTests: XCTestCase {

    func test_loadsAllChampionsFromBundledJSON() {
        XCTAssertGreaterThan(ChampionCatalog.entries.count, 40,
            "expected ~50+ Set 17 champion entries from set17-champions.json")
    }

    func test_lookupsCommonChampions() {
        XCTAssertEqual(ChampionCatalog.displayName(forId: "TFT17_Aatrox"), "Aatrox")
        XCTAssertEqual(ChampionCatalog.displayName(forId: "TFT17_Viktor"), "Viktor")
    }

    func test_fallsBackToRawIdWhenUnknown() {
        XCTAssertEqual(ChampionCatalog.displayName(forId: "TFT17_NewChamp"), "TFT17_NewChamp")
    }
}
