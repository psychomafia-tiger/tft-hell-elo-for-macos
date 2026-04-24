import Foundation

/// Static lookup from champion ID (e.g. `TFT17_Viktor`) to display metadata.
///
/// **Phase 1 (v0.1)**: hand-populated with the 15 champion IDs present in
/// `Resources/sample-tier-list.json`. `iconAsset` is always `nil` — portraits
/// render as cost-colored circles with initials, not real art.
///
/// **Phase 2**: this file will be auto-generated from Community Data Dragon.
/// That's why it lives under `Generated/` — the folder name signals
/// "don't hand-edit, regenerate". For v0.1 we hand-edit because generating
/// one file for 15 entries is overkill (YAGNI).
///
/// Fallback rule: `displayName(forId:)` returns the raw ID when not found.
/// This keeps the UI rendering gracefully when the pipeline introduces new
/// champion IDs before the catalog is regenerated, instead of crashing.
enum ChampionCatalog {

    struct Entry {
        /// Human-readable name. Derived by stripping the `TFT17_` prefix.
        let displayName: String
        /// Image asset name in the bundle. Always `nil` for v0.1 — reserved
        /// for Phase 2 when Community Data Dragon icons are downloaded.
        let iconAsset: String?
    }

    static let entries: [String: Entry] = [
        "TFT17_Aatrox":   Entry(displayName: "Aatrox",   iconAsset: nil),
        "TFT17_Ahri":     Entry(displayName: "Ahri",     iconAsset: nil),
        "TFT17_Gwen":     Entry(displayName: "Gwen",     iconAsset: nil),
        "TFT17_Illaoi":   Entry(displayName: "Illaoi",   iconAsset: nil),
        "TFT17_Jinx":     Entry(displayName: "Jinx",     iconAsset: nil),
        "TFT17_KaiSa":    Entry(displayName: "KaiSa",    iconAsset: nil),
        "TFT17_Morgana":  Entry(displayName: "Morgana",  iconAsset: nil),
        "TFT17_Nami":     Entry(displayName: "Nami",     iconAsset: nil),
        "TFT17_Rhaast":   Entry(displayName: "Rhaast",   iconAsset: nil),
        "TFT17_Sivir":    Entry(displayName: "Sivir",    iconAsset: nil),
        "TFT17_Syndra":   Entry(displayName: "Syndra",   iconAsset: nil),
        "TFT17_Varus":    Entry(displayName: "Varus",    iconAsset: nil),
        "TFT17_Viktor":   Entry(displayName: "Viktor",   iconAsset: nil),
        "TFT17_Xerath":   Entry(displayName: "Xerath",   iconAsset: nil),
        "TFT17_Yasuo":    Entry(displayName: "Yasuo",    iconAsset: nil),
    ]

    /// Returns the human-readable display name for a champion ID, or falls
    /// back to the raw ID when the champion is not in the catalog.
    static func displayName(forId id: String) -> String {
        entries[id]?.displayName ?? id
    }

    /// Returns the 2-character initials used on portrait overlays.
    /// For "KaiSa" → "Ka" (first 2 chars of display name, title case preserved).
    static func initials(forId id: String) -> String {
        let name = displayName(forId: id)
        return String(name.prefix(2))
    }
}
