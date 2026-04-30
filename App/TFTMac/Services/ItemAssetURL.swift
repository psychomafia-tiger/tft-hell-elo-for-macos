import Foundation

/// CommunityDragon CDN URL builder for TFT item icons.
///
/// Pattern verified 2026-04-27: en_us.json `data['items'][i].icon` field
/// (e.g. `ASSETS/Maps/TFT/Icons/Items/Hexcore/TFT_Item_GargoyleStoneplate.TFT_Set13.tex`)
/// converts to URL by:
///   1. Take filename only (drop directory prefix)
///   2. Drop `.tex` suffix
///   3. Lowercase
///   4. Append `.png` and prepend CDN base
///
/// The set suffix (`.tft_set13`, `.tft_set17`) varies per item and reflects
/// when Riot last refreshed the texture — NOT the active TFT set. It is part
/// of the canonical filename and must be preserved exactly.
enum ItemAssetURL {

    private static let cdnBase =
        "https://raw.communitydragon.org/latest/game/assets/maps/tft/icons/items/hexcore"

    /// Builds the icon URL for a bundled `iconToken` from `set17-items.json`.
    /// Returns nil for empty / whitespace-only tokens.
    static func icon(forIconToken token: String) -> URL? {
        let trimmed = token.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: "\(cdnBase)/\(trimmed).png")
    }
}
