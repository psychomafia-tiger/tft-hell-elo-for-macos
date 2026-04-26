import XCTest
@testable import TFTMac

final class ChampionAssetURLTests: XCTestCase {

    func test_buildsLowercaseSet17URL() {
        let url = ChampionAssetURL.squarePortrait(forChampionId: "TFT17_Aatrox")
        XCTAssertEqual(
            url?.absoluteString,
            "https://raw.communitydragon.org/latest/game/assets/characters/tft17_aatrox/hud/tft17_aatrox_square.tft_set17.png"
        )
    }

    func test_handlesCamelCaseChampionIds() {
        let url = ChampionAssetURL.squarePortrait(forChampionId: "TFT17_KaiSa")
        XCTAssertEqual(
            url?.absoluteString,
            "https://raw.communitydragon.org/latest/game/assets/characters/tft17_kaisa/hud/tft17_kaisa_square.tft_set17.png"
        )
    }

    func test_returnsNilForBlankId() {
        XCTAssertNil(ChampionAssetURL.squarePortrait(forChampionId: ""))
    }
}
