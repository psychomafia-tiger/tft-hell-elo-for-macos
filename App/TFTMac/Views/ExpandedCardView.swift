import SwiftUI

/// Inline detail panel revealed when user taps a `CompCardV2`.
///
/// Sections:
/// 1. **Traits** — chip row(s) sorted by activation count. Up to 2 rows × 4 chips
///    (covers comps with ≤8 distinct traits). Empty comps show "—".
/// 2. **Carousel picks** — 1st/2nd priority champions to grab from the carousel.
/// 3. **LV.9 alternatives** — non-carry 4+ cost champions that flex as carries.
///
/// Per plan: hex-board positioning and trait threshold tooltips deferred to v0.2.
struct ExpandedCardView: View {
    let comp: Comp

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            traitsSection
            section(title: "Carousel picks", content: carouselText)
            section(title: "LV.9 alternatives", content: lv9Text)
        }
    }

    // MARK: - Traits

    private var sortedTraits: [TraitActivation] {
        comp.traits.sorted(by: { $0.count > $1.count })
    }

    /// Up to 2 rows of TraitChip, 4 per row, sorted by activation count DESC.
    /// Row-split at 4 so each chip has ~100px — fits 400px card without compression.
    private var traitsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("TRAITS")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Theme.Colors.textMuted)
            traitsChipRows
        }
    }

    @ViewBuilder
    private var traitsChipRows: some View {
        if sortedTraits.isEmpty {
            Text("—")
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.textMuted)
        } else {
            HStack(spacing: 4) {
                ForEach(Array(sortedTraits.prefix(4)), id: \.name) { trait in
                    TraitChip(activation: trait)
                }
                Spacer(minLength: 0)
            }
            if sortedTraits.count > 4 {
                HStack(spacing: 4) {
                    ForEach(Array(sortedTraits.dropFirst(4).prefix(4)), id: \.name) { trait in
                        TraitChip(activation: trait)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    // MARK: - Text sections

    private func section(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Theme.Colors.textMuted)
            Text(content)
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineLimit(2)
        }
    }

    /// Priority 1 = BIS carry (first isCarry).
    /// Priority 2 = any other carry, else first champion.
    private var carouselText: String {
        let carries = comp.champions.filter(\.isCarry)
        let prio1 = carries.first.map { ChampionCatalog.displayName(forId: $0.id) } ?? "—"
        let prio2Source = carries.dropFirst().first
            ?? comp.champions.first(where: { !$0.isCarry })
        let prio2 = prio2Source.map { ChampionCatalog.displayName(forId: $0.id) } ?? "—"
        return "\(prio1) → \(prio2)"
    }

    /// Non-carry 4+ cost champions → flex-carry alternatives at LV.9.
    /// If none qualify, fall back to all non-carry names.
    private var lv9Text: String {
        let nonCarryHighCost = comp.champions
            .filter { !$0.isCarry && $0.cost >= 4 }
            .map { ChampionCatalog.displayName(forId: $0.id) }
        if nonCarryHighCost.isEmpty {
            let nonCarryAny = comp.champions.filter { !$0.isCarry }
                .prefix(3)
                .map { ChampionCatalog.displayName(forId: $0.id) }
            return nonCarryAny.isEmpty ? "—" : nonCarryAny.joined(separator: ", ")
        }
        return nonCarryHighCost.joined(separator: ", ")
    }
}
