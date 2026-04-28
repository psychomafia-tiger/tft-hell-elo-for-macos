import XCTest
@testable import TFTMac

final class ItemCatalogTests: XCTestCase {

    func test_displayName_knownItem_returnsCatalogName() {
        XCTAssertEqual(
            ItemCatalog.displayName(forId: "TFT_Item_GargoyleStoneplate"),
            "Gargoyle Stoneplate"
        )
    }

    func test_displayName_unknownItem_returnsRawId() {
        let id = "TFT_Item_DoesNotExist_X"
        XCTAssertEqual(ItemCatalog.displayName(forId: id), id)
    }

    func test_iconToken_knownItem_returnsToken() {
        let token = ItemCatalog.iconToken(forId: "TFT_Item_GargoyleStoneplate")
        XCTAssertNotNil(token)
        XCTAssertTrue(token?.contains("gargoylestoneplate") ?? false)
    }

    func test_iconToken_unknownItem_returnsNil() {
        XCTAssertNil(ItemCatalog.iconToken(forId: "TFT_Item_DoesNotExist_X"))
    }

    func test_itemClass_tankItem_returnsTank() {
        XCTAssertEqual(
            ItemCatalog.itemClass(forId: "TFT_Item_GargoyleStoneplate"),
            .tank
        )
    }

    func test_itemClass_unknownItem_returnsUnknown() {
        XCTAssertEqual(
            ItemCatalog.itemClass(forId: "TFT_Item_DoesNotExist_X"),
            .unknown
        )
    }
}
