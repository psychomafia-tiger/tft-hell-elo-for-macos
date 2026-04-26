import Foundation

/// Builds CommunityDragon CDN URLs for Set 17 champion assets.
///
/// Pattern verified Task 0 (research/communitydragon-set17.md):
/// `https://raw.communitydragon.org/latest/game/assets/characters/{lower_id}/hud/{lower_id}_square.tft_set17.png`
///
/// IDs are lowercased; embedded camelCase (e.g. `KaiSa`) flattens to `kaisa`.
enum ChampionAssetURL {
    private static let base = "https://raw.communitydragon.org/latest/game/assets/characters"

    static func squarePortrait(forChampionId id: String) -> URL? {
        guard !id.isEmpty else { return nil }
        let lower = id.lowercased()
        return URL(string: "\(base)/\(lower)/hud/\(lower)_square.tft_set17.png")
    }
}
