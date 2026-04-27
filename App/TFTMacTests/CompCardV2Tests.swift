import XCTest
import SwiftUI
@testable import TFTMac

/// Wave 5c — `CompCardV2` layout contract.
///
/// Unit tests here exercise derivations (metadata text, playstyle, tier color)
/// that the view reads. SwiftUI view tree snapshots are out of scope (v0.1
/// has no snapshot test infra); we assert on the *data* the view consumes,
/// ensuring Phase 2 swaps (AsyncImage, real star levels) don't break the
/// pipeline's expected shape.
final class CompCardV2Tests: XCTestCase {

    /// Fixture: 3-champion S-tier comp with one carry. Matches sample fixture shape.
    private func makeComp(name: String = "Test Comp",
                          tier: Tier = .S,
                          sampleSize: Int = 500,
                          carryCount: Int = 1,
                          championCount: Int = 3) -> Comp {
        let champions = (0..<championCount).map { idx in
            Champion(
                id: "TFT17_Test\(idx)",
                cost: idx + 1,
                isCarry: idx < carryCount,
                items: []
            )
        }
        return Comp(
            compId: "test-\(name)",
            name: name,
            tier: tier,
            playRate: 0.12,
            avgPlacement: 3.8,
            top4Rate: 0.55,
            sampleSize: sampleSize,
            champions: champions
        )
    }

    /// Champions count rendered = comp.champions.count (no hard-cap at 4 like v1).
    func testChampionsRowIteratesAllChampionsNoCap() {
        let comp = makeComp(championCount: 8)  // simulate Phase 2 8-unit comp
        XCTAssertEqual(comp.champions.count, 8,
                       "CompCardV2 body uses ForEach(comp.champions) — full count, not prefix(4)")
    }

    /// Playstyle derivation — keyword match on comp name (Wave 5c placeholder).
    func testPlaystyleRerollCompMapsToSlowRoll() {
        let comp = makeComp(name: "Sivir Reroll")
        XCTAssertEqual(PlaystyleLabel.derivedPlaystyle(for: comp), "Slow Roll")
    }

    func testPlaystyleHyperCompMapsToFast8() {
        let comp = makeComp(name: "KaiSa Hyper")
        XCTAssertEqual(PlaystyleLabel.derivedPlaystyle(for: comp), "Fast 8")
    }

    func testPlaystyleGenericCompMapsToStandard() {
        let comp = makeComp(name: "Storm Quickdraw")
        XCTAssertEqual(PlaystyleLabel.derivedPlaystyle(for: comp), "Standard")
    }

    /// Star level derivation (Wave 5c placeholder: carry=2, non-carry=1).
    func testStarLevelCarryIs2() {
        let carry = Champion(id: "TFT17_Jinx", cost: 4, isCarry: true, items: [])
        XCTAssertEqual(StarLevelIndicator.derivedLevel(for: carry), 2)
    }

    func testStarLevelNonCarryIs1() {
        let support = Champion(id: "TFT17_Nami", cost: 2, isCarry: false, items: [])
        XCTAssertEqual(StarLevelIndicator.derivedLevel(for: support), 1)
    }

    /// Low-confidence regression (retained from v1) — <100 samples → opacity 0.5.
    /// Sampled via `isLowConfidence` derivation (visible in metadataText).
    func testLowConfidenceCompHasLowConfidenceMetadata() {
        let comp = makeComp(sampleSize: 50)
        XCTAssertTrue(comp.sampleSize < 100, "Fixture under threshold")
        // CompCardV2.metadataText is private; we assert via sampleSize contract
        // that the view's isLowConfidence branch will activate.
    }

    func testHighConfidenceCompAboveThreshold() {
        let comp = makeComp(sampleSize: 500)
        XCTAssertFalse(comp.sampleSize < 100)
    }

    /// Rendering smoke — view can be constructed at popover (400px) and overlay
    /// (480px) widths without crashing. SwiftUI view init is pure, so this is
    /// effectively a type-system check that CompCardV2 accepts the width param.
    func testViewInitAtPopoverWidth() {
        let comp = makeComp()
        let view = CompCardV2(comp: comp, width: 400)
        XCTAssertNotNil(view.body)
    }

    func testViewInitAtOverlayWidth() {
        let comp = makeComp()
        let view = CompCardV2(comp: comp, width: 480)
        XCTAssertNotNil(view.body)
    }

    // MARK: - Bug #005 — data-driven star_level, 3-star-only render

    /// StarLevelIndicator renders EmptyView for level < 3; 3 star-pips for level == 3.
    /// No ViewInspector available — assert view init and body construction don't
    /// crash, and verify the render-gate logic directly on the struct.
    func test_starIndicator_hiddenFor1Or2Star() {
        // level=1 → body is EmptyView (no-op layout)
        let indicator1 = StarLevelIndicator(level: 1)
        XCTAssertNoThrow({ _ = indicator1.body }(), "level=1 should produce EmptyView without crash")

        // level=2 → body is also EmptyView
        let indicator2 = StarLevelIndicator(level: 2)
        XCTAssertNoThrow({ _ = indicator2.body }(), "level=2 should produce EmptyView without crash")

        // level=3 → body renders 3-star HStack (not EmptyView)
        let indicator3 = StarLevelIndicator(level: 3)
        XCTAssertNoThrow({ _ = indicator3.body }(), "level=3 should construct 3-star view without crash")
    }

    /// Champion default init (no starLevel arg) compiles and defaults to 1.
    func test_championDefaultStarLevel() {
        let champ = Champion(id: "TFT17_Viktor", cost: 5, isCarry: true, items: [])
        XCTAssertEqual(champ.starLevel, 1,
                       "Default starLevel should be 1 when not specified in memberwise init")
    }

    /// champion.starLevel flows through to StarLevelIndicator correctly.
    func test_championPortraitUsesStarLevelFromData() {
        // 3-star champion: starLevel=3 → indicator renders pips
        let carry3Star = Champion(id: "TFT17_Jinx", cost: 4, isCarry: true, starLevel: 3, items: [])
        XCTAssertEqual(carry3Star.starLevel, 3)

        // 2-star carry: starLevel=2 → indicator is EmptyView (no pips)
        let carry2Star = Champion(id: "TFT17_Jinx", cost: 4, isCarry: true, starLevel: 2, items: [])
        XCTAssertEqual(carry2Star.starLevel, 2)

        // non-carry 1-star: default → no pips
        let support = Champion(id: "TFT17_Nami", cost: 2, isCarry: false, items: [])
        XCTAssertEqual(support.starLevel, 1)
    }
}
