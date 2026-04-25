import Foundation

/// Top-level structure decoded from tier-list.json (schema v1.0.0).
///
/// `schema_version` arrives as a dotted string in JSON ("1.0.0") rather than
/// a nested object, so this type uses a custom decoder to parse it via
/// `SchemaVersion(string:)`. All other keys use `.convertFromSnakeCase`.
struct TierList: Codable {
    let schemaVersion: SchemaVersion
    let patchVersion: String
    let lastUpdated: Date
    let dataWindowHours: Int
    let eloBracket: String
    let totalMatchesSampled: Int
    let region: String          // NEW v1.1.0 — defaults to "VN2" for v1.0.0 bundled JSON
    let comps: [Comp]

    // Explicit keys required because schemaVersion needs custom string parsing.
    // The string values here match the snake_case JSON keys exactly; JSONDecoder
    // with .convertFromSnakeCase will translate them before lookup.
    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case patchVersion
        case lastUpdated
        case dataWindowHours
        case eloBracket
        case totalMatchesSampled
        case region
        case comps
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        let versionString = try c.decode(String.self, forKey: .schemaVersion)
        guard let version = SchemaVersion(string: versionString) else {
            throw DecodingError.dataCorruptedError(
                forKey: .schemaVersion, in: c,
                debugDescription: "Invalid schema_version: \(versionString). Expected X.Y.Z."
            )
        }
        self.schemaVersion = version
        self.patchVersion = try c.decode(String.self, forKey: .patchVersion)
        self.lastUpdated = try c.decode(Date.self, forKey: .lastUpdated)
        self.dataWindowHours = try c.decode(Int.self, forKey: .dataWindowHours)
        self.eloBracket = try c.decode(String.self, forKey: .eloBracket)
        self.totalMatchesSampled = try c.decode(Int.self, forKey: .totalMatchesSampled)
        // Forward-compat: `region` absent in v1.0.0 bundled JSON → default to "VN2"
        self.region = (try? c.decodeIfPresent(String.self, forKey: .region)) ?? "VN2"
        self.comps = try c.decode([Comp].self, forKey: .comps)
    }
}
