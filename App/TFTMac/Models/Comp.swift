import Foundation

/// A single comp entry inside tier-list.json.
///
/// All keys use `.convertFromSnakeCase` — no explicit CodingKeys needed.
/// `top_4_rate` → `top4Rate` per JSONDecoder docs (leading digit preserved).
struct Comp: Codable {
    let compId: String
    let name: String
    let tier: Tier
    let playRate: Double
    let avgPlacement: Double
    let top4Rate: Double
    let sampleSize: Int
    let champions: [Champion]
}

/// Tier classification emitted by the data pipeline.
///
/// Comparable so comps can be sorted S → A → B → C in UI layers.
enum Tier: String, Codable, Comparable {
    case S, A, B, C

    private static let order: [String: Int] = ["S": 0, "A": 1, "B": 2, "C": 3]

    static func < (lhs: Tier, rhs: Tier) -> Bool {
        (Tier.order[lhs.rawValue] ?? 99) < (Tier.order[rhs.rawValue] ?? 99)
    }
}
