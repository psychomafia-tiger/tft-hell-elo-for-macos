import SwiftUI

/// Wave 5c comp card — superset of the original v1 with:
///
/// - ALL `comp.champions` rendered via `ForEach` (v1 was hard-capped at 4,
///   which blocked Cavalier/8-unit comp visualization).
/// - `PlaystyleLabel` next to comp name ("Fast 8" / "Slow Roll" / "Standard").
/// - `ChampionPortrait` v2 (placeholder + name text + star overlay) replaces
///   v1's cost-colored initials circle.
/// - Click-to-expand via `@State isExpanded` — reveals `ExpandedCardView`
///   inline (traits list + carousel picks + LV.9 alternatives; hex board
///   positioning deferred to v0.2 per plan "NOT in scope").
///
/// Card width: `width: CGFloat` parameter so the same view renders in
/// 440px popover AND 520px overlay. Height grows dynamically when expanded.
///
/// Low-confidence handling retained from v1: <100 sample matches → 50%
/// opacity + "Low confidence" metadata suffix.
struct CompCardV2: View {
    let comp: Comp
    /// Card width — 400 default for popover (440 minus popover padding),
    /// overlay pass 480 (520 minus overlay padding). Height is dynamic.
    var width: CGFloat = 400

    @State private var isExpanded: Bool = false

    private var isLowConfidence: Bool { comp.sampleSize < 100 }

    private var tierColor: Color {
        switch comp.tier {
        case .S: return Theme.Colors.accentGold
        case .A: return Theme.Colors.accentSilver
        case .B: return Theme.Colors.accentBronze
        case .C: return Color.gray
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            topRow
            if !comp.traits.isEmpty {
                traitsRow
            }
            championsRow
            CompCardAnomaliesRow(anomalies: comp.anomalies)  // Phase 03: anomaly chips
            if isExpanded {
                Divider().background(Theme.Colors.borderDefault)
                ExpandedCardView(comp: comp)
            }
        }
        .padding(Theme.Spacing.paddingCard)
        .frame(width: width, alignment: .topLeading)
        .background(Theme.Colors.bgCard)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radii.card)
                .stroke(Theme.Colors.borderDefault, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radii.card))
        .opacity(isLowConfidence ? 0.5 : 1.0)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.15)) {
                isExpanded.toggle()
            }
        }
    }

    private var topRow: some View {
        HStack(alignment: .top, spacing: 10) {
            TierBadge(tier: comp.tier)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(comp.name)
                        .font(Theme.Fonts.title)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .lineLimit(1)
                    PlaystyleLabel(text: PlaystyleLabel.derivedPlaystyle(for: comp))
                }
                Text(metadataText)
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.textMuted)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.Colors.textMuted)
        }
    }

    /// Horizontal strip of `TraitChip` badges, one per active trait in the comp.
    /// Sorted by activation count descending (most-active trait first) so the
    /// dominant synergy reads left-to-right without scanning. Hidden when
    /// `comp.traits` is empty — forward-compatible with v1.1.0 schema that
    /// omits the `traits` key (defaults to `[]`).
    private var traitsRow: some View {
        HStack(spacing: 4) {
            ForEach(comp.traits.sorted(by: { $0.count > $1.count }), id: \.name) { trait in
                TraitChip(activation: trait)
            }
            Spacer(minLength: 0)
        }
    }

    /// Horizontal row of ALL champion portraits in the comp. Wraps via HStack
    /// for v0.1 (max ~8 champions in TFT comps — fits 480px width at 40px
    /// portrait + gap). Phase 2 may adopt `LazyHStack` if 8+ emerges.
    private var championsRow: some View {
        HStack(spacing: Theme.Spacing.gapChampionIcons) {
            ForEach(comp.champions, id: \.id) { champ in
                ChampionPortrait(champion: champ)
            }
            Spacer(minLength: 0)
        }
    }

    private var metadataText: String {
        let avg = String(format: "%.1f", comp.avgPlacement)
        let play = String(format: "%.1f%%", comp.playRate * 100)
        let base = "Avg \(avg) · Play \(play) · \(comp.sampleSize) matches"
        return isLowConfidence ? "\(base) · Low confidence" : base
    }
}

/// Legacy v1 alias for any external references (internal callers updated in
/// Wave 5c). Kept as a thin passthrough so accidental imports of `CompCard`
/// still compile; future cleanup (post-Wave 5e dogfood) can delete this.
typealias CompCard = CompCardV2

// MARK: - Tier Badge

/// 28×28 px circular tier indicator. Letter + tier-color background.
struct TierBadge: View {
    let tier: Tier

    var body: some View {
        Text(tier.rawValue)
            .font(Theme.Fonts.badge)
            .foregroundStyle(Color.black)
            .frame(width: Theme.Spacing.tierBadge, height: Theme.Spacing.tierBadge)
            .background(background)
            .clipShape(Circle())
    }

    private var background: Color {
        switch tier {
        case .S: return Theme.Colors.accentGold
        case .A: return Theme.Colors.accentSilver
        case .B: return Theme.Colors.accentBronze
        case .C: return Color.gray
        }
    }
}

// MARK: - (Wave 5c) ChampionPortrait + ChampionPortraitRow moved
//
// The v1 `ChampionPortrait` (cost-colored circle + initials, 32px) and
// `ChampionPortraitRow` (prefix 4) were extracted and replaced in Wave 5c:
//
// - `ChampionPortrait.swift` — new v2 with placeholder circle + SF Symbol +
//   name text (per D5 decision). Phase 2 swaps to AsyncImage in 1 line.
// - `CompCardV2` body below iterates ALL `comp.champions` (not just prefix 4),
//   matching the TFTactics reference layout that shows the full team.
