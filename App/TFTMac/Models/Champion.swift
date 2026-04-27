import Foundation

/// A champion entry within a `Comp`.
///
/// `items` may be empty — UI (Task 1.9) renders empty arrays as a "Flex" label.
///
/// `starLevel` is emitted by the pipeline (schema 1.2.0+) as the modal observed
/// star tier across sampled matches. Legacy fixtures (v1.0.0 / v1.1.0) omit this
/// key — the custom `init(from:)` decodes it with a default of 1 so old bundles
/// load without throwing.
///
/// Memberwise call sites (Champion(id:cost:isCarry:items:)) continue to compile
/// unchanged because `starLevel` carries a default value of 1 in the synthesized
/// init — Swift generates the parameter after the last non-defaulted one.
struct Champion: Codable {
    let id: String        // e.g. "TFT17_Viktor"
    let cost: Int         // 1-5
    let isCarry: Bool     // JSON: is_carry
    let starLevel: Int    // JSON: star_level — 1/2/3; default 1 for legacy fixtures
    let items: [ItemBuild]

    // MARK: - CodingKeys
    //
    // No explicit raw values — the parent JSONDecoder applies
    // `.convertFromSnakeCase` strategy, so JSON `is_carry` and `star_level`
    // already arrive as camelCase keys in the container. Adding raw snake-case
    // values here would short-circuit the strategy and break decoding.

    enum CodingKeys: String, CodingKey {
        case id
        case cost
        case isCarry
        case starLevel
        case items
    }

    // MARK: - Decodable (forward-compat)

    /// Custom decoder so legacy fixtures missing `star_level` key default to 1
    /// rather than throwing a keyNotFound error.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id        = try c.decode(String.self,     forKey: .id)
        cost      = try c.decode(Int.self,        forKey: .cost)
        isCarry   = try c.decode(Bool.self,       forKey: .isCarry)
        starLevel = (try? c.decode(Int.self,      forKey: .starLevel)) ?? 1
        items     = (try? c.decode([ItemBuild].self, forKey: .items)) ?? []
    }

    // MARK: - Memberwise init (preserves existing call sites)

    /// Explicit memberwise init keeps `Champion(id:cost:isCarry:items:)` call
    /// sites compiling. Default `starLevel: Int = 1` means callers that don't
    /// pass a star level get a safe default without source changes.
    init(id: String, cost: Int, isCarry: Bool, starLevel: Int = 1, items: [ItemBuild]) {
        self.id        = id
        self.cost      = cost
        self.isCarry   = isCarry
        self.starLevel = starLevel
        self.items     = items
    }
}

/// A single recommended item slot within a `Champion`.
///
/// `agreement` is the fraction of sampled matches where this item appeared on
/// this champion. Pipeline filters values below 0.40 before publishing.
struct ItemBuild: Codable {
    let id: String         // e.g. "TFT_Item_JeweledGauntlet"
    let agreement: Double  // 0.40 – 1.0
}
