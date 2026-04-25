import Foundation

/// A single comp entry inside tier-list.json.
///
/// `anomalies` is populated by Phase 01 pipeline (Set 17 Anomaly mechanic).
/// Forward-compat decoder: old JSON v1.0.0 (no `anomalies` key) → empty array.
/// New JSON v1.1.0 (with `anomalies` array) → populated array.
///
/// Custom `init(from:)` required because:
/// 1. `anomalies` uses `decodeIfPresent ?? []` for forward-compat
/// 2. Existing `top_4_rate` → `top4Rate` snake_case conversion still handled
///    by JSONDecoder `.convertFromSnakeCase` at container level
///
/// Explicit memberwise init with `anomalies` defaulting to `[]` so existing
/// test fixtures (CompCardV2Tests, ExpandedCardViewTests) compile unchanged.
struct Comp: Encodable {
    let compId: String
    let name: String
    let tier: Tier
    let playRate: Double
    let avgPlacement: Double
    let top4Rate: Double
    let sampleSize: Int
    let champions: [Champion]
    let anomalies: [Anomaly]   // NEW — empty array for v1.0.0 bundled data

    init(
        compId: String,
        name: String,
        tier: Tier,
        playRate: Double,
        avgPlacement: Double,
        top4Rate: Double,
        sampleSize: Int,
        champions: [Champion],
        anomalies: [Anomaly] = []
    ) {
        self.compId = compId
        self.name = name
        self.tier = tier
        self.playRate = playRate
        self.avgPlacement = avgPlacement
        self.top4Rate = top4Rate
        self.sampleSize = sampleSize
        self.champions = champions
        self.anomalies = anomalies
    }
}

extension Comp: Decodable {
    enum CodingKeys: String, CodingKey {
        case compId
        case name
        case tier
        case playRate
        case avgPlacement
        case top4Rate
        case sampleSize
        case champions
        case anomalies
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.compId = try c.decode(String.self, forKey: .compId)
        self.name = try c.decode(String.self, forKey: .name)
        self.tier = try c.decode(Tier.self, forKey: .tier)
        self.playRate = try c.decode(Double.self, forKey: .playRate)
        self.avgPlacement = try c.decode(Double.self, forKey: .avgPlacement)
        self.top4Rate = try c.decode(Double.self, forKey: .top4Rate)
        self.sampleSize = try c.decode(Int.self, forKey: .sampleSize)
        self.champions = try c.decode([Champion].self, forKey: .champions)
        // Forward-compat: key absent in v1.0.0 bundled JSON → default to []
        self.anomalies = (try? c.decodeIfPresent([Anomaly].self, forKey: .anomalies)) ?? []
    }
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
