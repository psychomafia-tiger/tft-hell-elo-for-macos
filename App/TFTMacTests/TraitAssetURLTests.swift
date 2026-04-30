import XCTest
@testable import TFTMac

final class TraitAssetURLTests: XCTestCase {

    func test_buildsUrlFromKnownTrait() {
        // TFT17_PsyOps is in the bundled catalog → token "psyops"
        let url = TraitAssetURL.icon(forApiName: "TFT17_PsyOps")
        XCTAssertEqual(
            url?.absoluteString,
            "https://raw.communitydragon.org/latest/game/assets/ux/traiticons/trait_icon_17_psyops.tft_set17.png"
        )
    }

    func test_returnsNilForUnknownTrait() {
        XCTAssertNil(TraitAssetURL.icon(forApiName: "TFT99_Bogus"))
    }

    func test_returnsNilForBlank() {
        XCTAssertNil(TraitAssetURL.icon(forApiName: ""))
    }
}
