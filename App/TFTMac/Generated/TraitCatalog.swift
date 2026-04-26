import Foundation
import os

/// Loads Set 17 trait metadata from bundled `set17-traits.json`.
/// Source-of-truth for both display names and icon URL tokens —
/// apiName from Riot Match-v5 maps to neither directly.
enum TraitCatalog {
    struct Entry: Decodable, Equatable {
        let apiName: String      // e.g. "TFT17_PsyOps" — what Riot API returns
        let displayName: String  // e.g. "Psionic" — user-facing label
        let iconToken: String    // e.g. "psyops" — used in CommunityDragon URL
    }

    static let entries: [String: Entry] = loadFromBundle()

    /// Returns user-facing display name. Falls back to apiName with `TFT17_` stripped.
    static func displayName(forApiName apiName: String) -> String {
        entries[apiName]?.displayName ?? apiName.replacingOccurrences(of: "TFT17_", with: "")
    }

    /// Returns CommunityDragon icon token (lowercase). Returns nil if unknown — caller falls back to placeholder.
    static func iconToken(forApiName apiName: String) -> String? {
        entries[apiName]?.iconToken
    }

    private static func loadFromBundle() -> [String: Entry] {
        let logger = Logger(subsystem: "io.psychomafia.tfthellelo", category: "TraitCatalog")
        guard let url = Bundle.main.url(forResource: "set17-traits", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let arr = try? JSONDecoder().decode([Entry].self, from: data) else {
            logger.error("set17-traits.json missing or malformed — empty catalog")
            return [:]
        }
        return Dictionary(uniqueKeysWithValues: arr.map { ($0.apiName, $0) })
    }
}
