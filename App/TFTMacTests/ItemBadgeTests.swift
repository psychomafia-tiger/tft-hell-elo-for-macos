import XCTest
import SwiftUI
@testable import TFTMac

final class ItemBadgeTests: XCTestCase {

    // MARK: - Tint color resolution (pure)

    func test_tintColor_tankClass() {
        XCTAssertEqual(ItemBadge.tintColor(for: .tank), Color.blue)
    }

    func test_tintColor_adClass() {
        XCTAssertEqual(ItemBadge.tintColor(for: .ad), Color.red)
    }

    func test_tintColor_apClass() {
        XCTAssertEqual(ItemBadge.tintColor(for: .ap), Color.purple)
    }

    func test_tintColor_utilityClass() {
        XCTAssertEqual(ItemBadge.tintColor(for: .utility), Color.green)
    }

    func test_tintColor_unknownClass() {
        XCTAssertEqual(ItemBadge.tintColor(for: .unknown), Color.gray)
    }

    // MARK: - View construction (compile-only smoke)

    func test_constructsForKnownItemId() {
        let badge = ItemBadge(itemId: "TFT_Item_GargoyleStoneplate")
        XCTAssertNotNil(badge.body)
    }

    func test_constructsForUnknownItemId() {
        let badge = ItemBadge(itemId: "TFT_Item_DoesNotExist_X")
        XCTAssertNotNil(badge.body)
    }

    func test_constructsForEmptyItemId() {
        let badge = ItemBadge(itemId: "")
        XCTAssertNotNil(badge.body)
    }
}
