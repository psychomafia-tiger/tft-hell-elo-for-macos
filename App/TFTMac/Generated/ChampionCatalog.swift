import Foundation
import os

/// Static lookup from champion ID to display metadata.
///
/// Loaded once at app start from `Resources/set17-champions.json` (bundled).
/// Source of truth: derived from `data/tier-list.json` champion IDs +
/// manual displayName corrections for camelCase quirks (Kaisa → Kai'Sa).
///
/// Fallback: unknown IDs return the raw ID string — UI degrades gracefully.
enum ChampionCatalog {

    struct Entry: Decodable {
        let id: String
        let displayName: String
        /// Reserved for Phase 2 (Community Data Dragon icons). Always nil today.
        let iconAsset: String?

        init(id: String, displayName: String, iconAsset: String? = nil) {
            self.id = id
            self.displayName = displayName
            self.iconAsset = iconAsset
        }
    }

    static let entries: [String: Entry] = loadFromBundle()

    static func displayName(forId id: String) -> String {
        entries[id]?.displayName ?? id
    }

    /// 2-character initials for portrait overlays. "Kai'Sa" → "Ka".
    static func initials(forId id: String) -> String {
        String(displayName(forId: id).prefix(2))
    }

    private static func loadFromBundle() -> [String: Entry] {
        let logger = Logger(subsystem: "io.psychomafia.tfthellelo", category: "ChampionCatalog")
        guard let url = Bundle.main.url(forResource: "set17-champions", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let arr = try? JSONDecoder().decode([Entry].self, from: data) else {
            logger.error("set17-champions.json missing or malformed — falling back to empty catalog")
            return [:]
        }
        return Dictionary(uniqueKeysWithValues: arr.map { ($0.id, $0) })
    }
}
