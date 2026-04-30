import XCTest
import SwiftUI
@testable import TFTMac

final class TraitChipTests: XCTestCase {

    func test_initWithGoldStyle() {
        let activation = TraitActivation(name: "TFT17_PsyOps", count: 4, style: .gold)
        let chip = TraitChip(activation: activation)
        XCTAssertEqual(chip.activation.name, "TFT17_PsyOps")
        XCTAssertEqual(chip.activation.style, .gold)
    }

    func test_displayLabelUsesCatalog() {
        // TFT17_PsyOps → display "Psionic" via TraitCatalog
        let activation = TraitActivation(name: "TFT17_PsyOps", count: 4, style: .gold)
        let chip = TraitChip(activation: activation)
        XCTAssertEqual(chip.displayLabel, "Psionic 4")
    }

    func test_displayLabelFallbackForUnknown() {
        // Unknown trait → catalog returns prefix-stripped fallback "Mystery"
        let activation = TraitActivation(name: "TFT17_Mystery", count: 2, style: .silver)
        let chip = TraitChip(activation: activation)
        XCTAssertEqual(chip.displayLabel, "Mystery 2")
    }
}
