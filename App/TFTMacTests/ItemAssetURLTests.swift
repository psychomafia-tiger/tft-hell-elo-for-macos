import XCTest
@testable import TFTMac

final class ItemAssetURLTests: XCTestCase {

    func test_buildsCDragonURL_forKnownToken() {
        let token = "tft_item_gargoylestoneplate.tft_set13"
        let url = ItemAssetURL.icon(forIconToken: token)
        XCTAssertEqual(
            url?.absoluteString,
            "https://raw.communitydragon.org/latest/game/assets/maps/tft/icons/items/hexcore/tft_item_gargoylestoneplate.tft_set13.png"
        )
    }

    func test_returnsNil_forEmptyToken() {
        XCTAssertNil(ItemAssetURL.icon(forIconToken: ""))
    }

    func test_returnsNil_forWhitespaceToken() {
        XCTAssertNil(ItemAssetURL.icon(forIconToken: "   "))
    }
}
