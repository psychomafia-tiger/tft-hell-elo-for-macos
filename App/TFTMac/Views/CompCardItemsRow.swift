import SwiftUI

/// Bottom row of the CompCard showing carry + support item builds with
/// agreement percentages.
///
/// Format: `{Carry} → {Item1} {P1}% · {Item2} {P2}%  |  {Support} → {Item3} {P3}%`
/// - Percentages use `Theme.Colors.accentGold` for visual weight.
/// - Carry = first champion with `isCarry == true`.
/// - Support = first non-carry champion with non-empty items array.
/// - Champion with empty items → renders `{Name} → Flex`.
/// - If carry missing or support missing → separator `|` is dropped.
///
/// Uses SF Mono 10 (`Theme.Fonts.monoCaption`) per wireframe spec.
struct CompCardItemsRow: View {
    let comp: Comp

    private var carry: Champion? {
        comp.champions.first(where: { $0.isCarry })
    }

    private var support: Champion? {
        comp.champions.first(where: { !$0.isCarry && !$0.items.isEmpty })
    }

    var body: some View {
        HStack(spacing: 0) {
            if let carry = carry {
                championSegment(carry, topN: 2)
            }
            if carry != nil, let support = support {
                Text("  |  ")
                    .font(Theme.Fonts.monoCaption)
                    .foregroundStyle(Theme.Colors.textMuted)
                championSegment(support, topN: 1)
            }
            Spacer(minLength: 0)
        }
        .lineLimit(1)
    }

    /// Renders `{Name} → Flex` for empty items, otherwise
    /// `{Name} → {Item1} {P1}% · {Item2} {P2}%` (top N by list order).
    @ViewBuilder
    private func championSegment(_ champ: Champion, topN: Int) -> some View {
        let name = ChampionCatalog.displayName(forId: champ.id)
        if champ.items.isEmpty {
            Text("\(name) → Flex")
                .font(Theme.Fonts.monoCaption)
                .foregroundStyle(Theme.Colors.textMuted)
        } else {
            HStack(spacing: 0) {
                Text("\(name) → ")
                    .font(Theme.Fonts.monoCaption)
                    .foregroundStyle(Theme.Colors.textMuted)
                ForEach(Array(champ.items.prefix(topN).enumerated()), id: \.offset) { idx, item in
                    if idx > 0 {
                        Text(" · ")
                            .font(Theme.Fonts.monoCaption)
                            .foregroundStyle(Theme.Colors.textMuted)
                    }
                    Text(ItemCatalog.displayName(forId: item.id) + " ")
                        .font(Theme.Fonts.monoCaption)
                        .foregroundStyle(Theme.Colors.textMuted)
                    Text("\(Int(item.agreement * 100))%")
                        .font(Theme.Fonts.monoCaption)
                        .foregroundStyle(Theme.Colors.accentGold)
                }
            }
        }
    }
}
