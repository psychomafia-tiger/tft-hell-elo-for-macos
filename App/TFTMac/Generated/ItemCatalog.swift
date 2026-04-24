import Foundation

/// Static lookup from item ID (e.g. `TFT_Item_JeweledGauntlet`) to display metadata.
///
/// **Phase 1 (v0.1)**: hand-populated with the 17 item IDs present in
/// `Resources/sample-tier-list.json`. `iconAsset` is always `nil` — the items
/// row renders as text only, not with icons.
///
/// **Phase 2**: this file will be auto-generated from Community Data Dragon.
/// Same rationale as `ChampionCatalog` — generated folder signals do-not-edit.
///
/// Fallback rule: `displayName(forId:)` returns the raw ID when not found,
/// keeping the UI graceful when the pipeline introduces new item IDs.
enum ItemCatalog {

    struct Entry {
        /// Human-readable item name.
        let displayName: String
        /// Image asset name in the bundle. Always `nil` for v0.1.
        let iconAsset: String?
    }

    static let entries: [String: Entry] = [
        "TFT_Item_AdaptiveHelm":       Entry(displayName: "Adaptive Helm",       iconAsset: nil),
        "TFT_Item_ArchangelsStaff":    Entry(displayName: "Archangel's Staff",   iconAsset: nil),
        "TFT_Item_BlueBuff":           Entry(displayName: "Blue Buff",           iconAsset: nil),
        "TFT_Item_GargoyleStoneplate": Entry(displayName: "Gargoyle Stoneplate", iconAsset: nil),
        "TFT_Item_GiantSlayer":        Entry(displayName: "Giant Slayer",        iconAsset: nil),
        "TFT_Item_HandOfJustice":      Entry(displayName: "Hand of Justice",     iconAsset: nil),
        "TFT_Item_InfinityEdge":       Entry(displayName: "Infinity Edge",       iconAsset: nil),
        "TFT_Item_IonicSpark":         Entry(displayName: "Ionic Spark",         iconAsset: nil),
        "TFT_Item_JeweledGauntlet":    Entry(displayName: "Jeweled Gauntlet",    iconAsset: nil),
        "TFT_Item_LastWhisper":        Entry(displayName: "Last Whisper",        iconAsset: nil),
        "TFT_Item_RabadonsDeathcap":   Entry(displayName: "Rabadon's Deathcap",  iconAsset: nil),
        "TFT_Item_Redemption":         Entry(displayName: "Redemption",          iconAsset: nil),
        "TFT_Item_Runaans":            Entry(displayName: "Runaan's Hurricane",  iconAsset: nil),
        "TFT_Item_Shojin":             Entry(displayName: "Spear of Shojin",     iconAsset: nil),
        "TFT_Item_StatikkShiv":        Entry(displayName: "Statikk Shiv",        iconAsset: nil),
        "TFT_Item_SunfireCape":        Entry(displayName: "Sunfire Cape",        iconAsset: nil),
        "TFT_Item_TitansResolve":      Entry(displayName: "Titan's Resolve",     iconAsset: nil),
    ]

    /// Returns the human-readable display name for an item ID, or falls back
    /// to the raw ID when the item is not in the catalog.
    static func displayName(forId id: String) -> String {
        entries[id]?.displayName ?? id
    }
}
