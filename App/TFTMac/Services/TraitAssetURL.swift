import Foundation

/// Builds CommunityDragon trait icon URLs. Pattern verified 2026-04-26:
/// `https://raw.communitydragon.org/latest/game/assets/ux/traiticons/trait_icon_17_<token>.tft_set17.png`
///
/// Token comes from TraitCatalog (NOT from apiName — they differ:
/// `TFT17_PsyOps` → token `psyops`, `TFT17_APTrait` → token `replicator`).
enum TraitAssetURL {
    private static let base = "https://raw.communitydragon.org/latest/game/assets/ux/traiticons"

    /// Builds icon URL from Riot apiName via catalog lookup.
    /// Returns nil for unknown traits (caller renders placeholder).
    static func icon(forApiName apiName: String) -> URL? {
        guard let token = TraitCatalog.iconToken(forApiName: apiName), !token.isEmpty else {
            return nil
        }
        return URL(string: "\(base)/trait_icon_17_\(token).tft_set17.png")
    }
}
