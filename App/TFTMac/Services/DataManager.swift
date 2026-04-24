import Foundation

/// Phase 1 stub: loads bundled sample-tier-list.json synchronously.
///
/// Phase 2 Task 2.13 will expand this into the full fallback chain:
///   R2 fetch (fresh) → cache (fresh) → cache (stale with banner)
///   → reject cache >7d → schema version mismatch guard.
///
/// For v0.1, data is baked into the app binary — DataManager's only job
/// is to produce a TierList the popover can render on launch.
///
/// `loadBundledJSON()` uses fatalError on missing resource because a
/// missing fixture means the app shipped broken — the build itself is
/// the safeguard, not a runtime catch. No dev will ever see the crash
/// because CI will have failed before distribution.
enum DataManager {

    /// Decodes the bundled `sample-tier-list.json` resource.
    /// - Returns: decoded TierList
    /// - Precondition: `sample-tier-list.json` must be present in the main bundle.
    ///   If absent, crashes with an actionable error message (build-time bug,
    ///   not runtime path).
    static func loadBundledJSON(bundle: Bundle = .main) -> TierList {
        guard let url = bundle.url(forResource: "sample-tier-list", withExtension: "json") else {
            fatalError("sample-tier-list.json missing from app bundle — check project.yml resources block")
        }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(TierList.self, from: data)
        } catch {
            fatalError("Failed to decode sample-tier-list.json: \(error)")
        }
    }
}
