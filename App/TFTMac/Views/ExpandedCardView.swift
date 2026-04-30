import SwiftUI

/// Inline detail panel revealed when user taps a `CompCardV2`.
///
/// Sections (matching TFTactics expanded layout):
/// 1. **Traits** — TraitChip rows (2 × max 4, sorted by count DESC).
/// 2. **Carousel picks** — carry portrait icons with `>` separators.
/// 3. **LV.9 options** — non-carry 4+ cost portrait icons with LV.9 label.
/// 4. **Positioning** — 4×7 hex board with champion portraits at modal hexes
///    (schema 1.4.0+; rendered only when `comp.positioning` non-empty).
struct ExpandedCardView: View {
    let comp: Comp

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            traitsSection
            Divider().background(Theme.Colors.borderDefault)
            carouselSection
            Divider().background(Theme.Colors.borderDefault)
            lv9Section
            if !comp.positioning.isEmpty {
                Divider().background(Theme.Colors.borderDefault)
                PositioningSection(positioning: comp.positioning)
            }
        }
    }

    // MARK: - Traits

    /// Traits to show: sorted by count DESC, filtered to hide trivially-inactive
    /// single-unit non-unique traits (matches TFTactics behavior of hiding
    /// traits not yet at a meaningful breakpoint).
    /// Unique champion traits (name contains "UniqueTrait") activate at 1 → keep.
    private var sortedTraits: [TraitActivation] {
        comp.traits
            .filter { $0.count >= 2 || $0.name.contains("UniqueTrait") }
            .sorted(by: { $0.count > $1.count })
    }

    private var traitsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionHeader("Traits")
            traitsChipRows
        }
    }

    /// Single-row icon-only badges — 26pt each, hover tooltip shows name.
    /// All traits fit in one row (9 × 30px = 270px < 400px card width).
    @ViewBuilder
    private var traitsChipRows: some View {
        if sortedTraits.isEmpty {
            Text("—")
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.textMuted)
        } else {
            HStack(spacing: 4) {
                ForEach(sortedTraits, id: \.name) { trait in
                    TraitBadge(activation: trait)
                }
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - Carousel picks

    /// Priority order: carry champions first (BIS → secondary carry).
    /// Shown as 32pt portraits with chevron separators, matching TFTactics.
    private var carouselSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionHeader("Carousel Picks")
            HStack(spacing: 4) {
                let carries = Array(comp.champions.filter(\.isCarry).prefix(3))
                if carries.isEmpty {
                    Text("—").font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textMuted)
                } else {
                    ForEach(Array(carries.enumerated()), id: \.element.id) { idx, champ in
                        if idx > 0 {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(Theme.Colors.textMuted)
                                .padding(.bottom, 12) // align with portrait center
                        }
                        ChampionPortrait(champion: champ, size: 32)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - LV.9 options

    /// Non-carry 4+ cost champions shown as 32pt portraits with "LV.9 ›" prefix.
    /// Falls back to first 3 non-carry champions if no 4+ cost found.
    private var lv9Section: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionHeader("LV.9 Options")
            HStack(spacing: 4) {
                Text("LV.9")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textMuted)
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textMuted)
                    .padding(.bottom, 12)
                ForEach(lv9Champions.prefix(3), id: \.id) { champ in
                    ChampionPortrait(champion: champ, size: 32)
                }
                Spacer(minLength: 0)
            }
        }
    }

    /// Champions to show in LV.9 section:
    /// 1. Overflow champions from the main row (9th+) — these are the cap victims.
    /// 2. Fallback: non-carry 4+ cost champions (the usual flex picks at LV.9).
    /// 3. Last resort: first 3 non-carry champions.
    private var lv9Champions: [Champion] {
        let overflow = Array(comp.champions.dropFirst(8))
        if !overflow.isEmpty { return overflow }
        let highCost = comp.champions.filter { !$0.isCarry && $0.cost >= 4 }
        if !highCost.isEmpty { return highCost }
        return Array(comp.champions.filter { !$0.isCarry }.prefix(3))
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(Theme.Colors.textMuted)
    }
}
