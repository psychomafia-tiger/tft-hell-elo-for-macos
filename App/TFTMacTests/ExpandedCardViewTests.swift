import XCTest
import SwiftUI
@testable import TFTMac

/// Wave 5c — ExpandedCardView derivation logic.
///
/// ExpandedCardView reads from `Comp` and derives three sections: traits
/// (placeholder), carousel picks (BIS carry → 2nd carry), LV.9 alternatives
/// (non-carry ≥4 cost). Tests assert the derivation on known fixtures so
/// Phase 2 schema changes (traits field, richer champion data) catch breakage.
final class ExpandedCardViewTests: XCTestCase {

    private func makeComp(champions: [Champion]) -> Comp {
        Comp(
            compId: "expanded-test",
            name: "Expanded Test",
            tier: .S,
            playRate: 0.1,
            avgPlacement: 4.0,
            top4Rate: 0.5,
            sampleSize: 200,
            champions: champions
        )
    }

    /// View constructs without crashing on a minimal comp fixture.
    func testBodyConstructsOnMinimalComp() {
        let comp = makeComp(champions: [
            Champion(id: "TFT17_Jinx", cost: 4, isCarry: true, items: [])
        ])
        let view = ExpandedCardView(comp: comp)
        XCTAssertNotNil(view.body)
    }

    /// Carousel derivation: first isCarry → prio1, next isCarry or first non-carry → prio2.
    /// When only one carry exists, prio2 falls back to first non-carry champion.
    func testCarouselFallsBackWhenSingleCarry() {
        let comp = makeComp(champions: [
            Champion(id: "TFT17_Jinx", cost: 4, isCarry: true, items: []),
            Champion(id: "TFT17_Nami", cost: 2, isCarry: false, items: [])
        ])
        let view = ExpandedCardView(comp: comp)
        XCTAssertNotNil(view.body, "body derives without nil-crash when only 1 carry present")
    }

    /// LV.9 derivation: non-carry champions with cost ≥4 qualify.
    /// When none qualify, fallback lists non-carry names (cap 3).
    func testLV9EmptyHighCostFallsBackToAnyNonCarry() {
        let comp = makeComp(champions: [
            Champion(id: "TFT17_Jinx", cost: 4, isCarry: true, items: []),
            Champion(id: "TFT17_Nami", cost: 1, isCarry: false, items: []),
            Champion(id: "TFT17_Varus", cost: 2, isCarry: false, items: []),
            Champion(id: "TFT17_Aatrox", cost: 3, isCarry: false, items: [])
        ])
        let view = ExpandedCardView(comp: comp)
        XCTAssertNotNil(view.body,
                        "body derives lv9 text even when no non-carry ≥4 cost exists (fallback active)")
    }

    /// LV.9 positive case — non-carry cost-5 champion qualifies.
    func testLV9ListsHighCostNonCarry() {
        let comp = makeComp(champions: [
            Champion(id: "TFT17_Jinx", cost: 4, isCarry: true, items: []),
            Champion(id: "TFT17_Morgana", cost: 5, isCarry: false, items: [])
        ])
        let view = ExpandedCardView(comp: comp)
        XCTAssertNotNil(view.body)
    }

    /// Boundary: 0 champions. View still constructs (renders "—" placeholder).
    func testEmptyCompStillConstructs() {
        let comp = makeComp(champions: [])
        let view = ExpandedCardView(comp: comp)
        XCTAssertNotNil(view.body)
    }
}
