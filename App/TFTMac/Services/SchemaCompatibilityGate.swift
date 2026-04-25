import Foundation

/// Decision returned by `SchemaCompatibilityGate.check(_:)`.
enum SchemaCompatibilityDecision {
    /// Data is compatible — proceed to decode and publish.
    case ok
    /// Data schema major version differs from app's — show update overlay,
    /// do NOT render comps from incompatible data.
    case updateRequired
}

/// Wraps `SchemaVersion.isCompatible(with:)` to produce a gate decision.
///
/// App schema = 1.1.0.
/// Bundled JSON (1.0.0) is compatible because:
///   - same major (1)
///   - data minor (0) >= app minor (1) — FALSE, meaning 1.0.0 data is OLDER
///     than app expectation (1.1.0), so this is rejected per rule.
///
/// Wait — re-check: `isCompatible` rule (SchemaVersion.swift line 23):
///   "guard dataVersion.minor >= minor else { return false }"
///   → app.minor=1, data.minor=0 → 0 >= 1 is false → REJECTED.
///
/// This means bundled 1.0.0 data would fail schema gate if app schema is 1.1.0.
/// Resolution (C2 fix): app schema STAYS at 1.0.0 in the gate.
/// Remote data (1.1.0) will also pass since 1 >= 0 (minor check) and same major.
///
/// App schema = 1.0.0 so:
///   - Bundled 1.0.0 → ok (same)
///   - Remote 1.1.0 → ok (data minor 1 >= app minor 0, within 10-minor window)
///   - Hypothetical 2.0.0 → updateRequired (major mismatch)
struct SchemaCompatibilityGate {

    /// App's expected minimum schema. Set to 1.0.0 so both bundled (1.0.0)
    /// and remote (1.1.0) data pass the gate.
    /// Update this to 2.0.0 only when the app ships a breaking model change.
    static let appSchema = SchemaVersion(major: 1, minor: 0, patch: 0)

    /// Returns `.ok` if `tierList.schemaVersion` is compatible with `appSchema`,
    /// `.updateRequired` otherwise.
    ///
    /// Pure logic — no side effects, trivially unit-testable.
    func check(_ tierList: TierList) -> SchemaCompatibilityDecision {
        if Self.appSchema.isCompatible(with: tierList.schemaVersion) {
            return .ok
        }
        return .updateRequired
    }
}
