import SwiftUI

/// Inline detail panel revealed when user taps a `CompCardV2`.
///
/// Per plan "NOT in scope": hex-board positioning of champions is DEFERRED
/// to v0.2 (vector math = 1 full weekend, YAGNI for v0.1). Wave 5c ships
/// three sections that fit the available data:
///
/// 1. **Traits** — list of comp's trait bonuses + their thresholds. v0.1
///    data fixture does not include traits, so we render a placeholder
///    line acknowledging this; Phase 2 pipeline adds the field.
/// 2. **Carousel picks** — 1st/2nd priority champions to grab from the
///    carousel (derived: BIS carry → prio 1, other isCarry → prio 2).
/// 3. **LV.9 alternatives** — names of non-carry champions that can flex
///    as carries if RNG denies BIS. Derived: 4+ cost non-carry champions.
///
/// Visual: stacked labeled rows, caption-size text, minimal chrome to keep
/// card height under 280px when expanded.
struct ExpandedCardView: View {
    let comp: Comp

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            section(title: "Traits", content: traitsText)
            section(title: "Carousel picks", content: carouselText)
            section(title: "LV.9 alternatives", content: lv9Text)
        }
    }

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

    /// Phase 2 will enrich `Comp` with traits; v0.1 placeholder.
    private var traitsText: String {
        "Trait breakdown available in v0.2 pipeline (Phase 2)"
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
