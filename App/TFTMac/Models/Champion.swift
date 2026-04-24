import Foundation

/// A champion entry within a `Comp`.
///
/// `items` may be empty — UI (Task 1.9) renders empty arrays as a "Flex" label.
struct Champion: Codable {
    let id: String       // e.g. "TFT17_Viktor"
    let cost: Int        // 1-5
    let isCarry: Bool    // JSON: is_carry
    let items: [ItemBuild]
}

/// A single recommended item slot within a `Champion`.
///
/// `agreement` is the fraction of sampled matches where this item appeared on
/// this champion. Pipeline filters values below 0.40 before publishing.
struct ItemBuild: Codable {
    let id: String         // e.g. "TFT_Item_JeweledGauntlet"
    let agreement: Double  // 0.40 – 1.0
}
