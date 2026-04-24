import Foundation

/// Semantic version tracking for tier-list.json schema.
///
/// Compatibility rule (app reading data):
/// - Reject if major version differs (breaking change).
/// - Reject if data minor is below app minor (data too old, missing fields).
/// - Accept if data minor is within 10-minor forward window from app.
///
/// Patch version ignored — patch changes are non-breaking by definition.
///
/// Rationale: Codable silently ignores unknown fields, so newer data with
/// additive fields works with older app. 10-minor cap prevents drift over
/// many releases from accumulating breaking changes the app can't model.
struct SchemaVersion: Equatable, Codable {
    let major: Int
    let minor: Int
    let patch: Int

    static let forwardMinorWindow = 10

    /// True if `self` (app's built-against version) is compatible with `dataVersion`.
    func isCompatible(with dataVersion: SchemaVersion) -> Bool {
        guard dataVersion.major == major else { return false }
        guard dataVersion.minor >= minor else { return false }
        guard dataVersion.minor - minor <= Self.forwardMinorWindow else { return false }
        return true
    }

    /// Parse `"X.Y.Z"` format. Returns nil on malformed input.
    init?(string: String) {
        let parts = string.split(separator: ".").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        self.major = parts[0]
        self.minor = parts[1]
        self.patch = parts[2]
    }

    init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }
}
