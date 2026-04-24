import SwiftUI

/// 400 × 120 px tier card matching `docs/wireframe-v0.1-standard-card.md`.
///
/// Layout (inside 12 px padding):
/// ```
/// [Tier badge 28×28] [Name + metadata VStack]         [Champion portraits →]
/// [                                  Items row at bottom                  ]
/// ```
///
/// Icons are placeholder cost-colored circles with initials — real art
/// arrives in Phase 2 via `ChampionCatalog.iconAsset`. Items row is text-only.
///
/// Low-sample comps (<100 matches) render at 50% opacity and append
/// `· Low confidence` to the metadata row — signal exists but treat as noisy.
struct CompCard: View {
    let comp: Comp

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
        VStack(alignment: .leading, spacing: 6) {
            topRow
            Spacer(minLength: 0)
            CompCardItemsRow(comp: comp)
        }
        .padding(Theme.Spacing.paddingCard)
        .frame(width: 400, height: Theme.Spacing.cardHeight, alignment: .topLeading)
        .background(Theme.Colors.bgCard)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radii.card)
                .stroke(Theme.Colors.borderDefault, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radii.card))
        .opacity(isLowConfidence ? 0.5 : 1.0)
    }

    private var topRow: some View {
        HStack(alignment: .top, spacing: 10) {
            TierBadge(tier: comp.tier)
            VStack(alignment: .leading, spacing: 2) {
                Text(comp.name)
                    .font(Theme.Fonts.title)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(1)
                Text(metadataText)
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.textMuted)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            ChampionPortraitRow(champions: Array(comp.champions.prefix(4)),
                                tierColor: tierColor)
        }
    }

    private var metadataText: String {
        let avg = String(format: "%.1f", comp.avgPlacement)
        let play = String(format: "%.1f%%", comp.playRate * 100)
        let base = "Avg \(avg) · Play \(play) · \(comp.sampleSize) matches"
        return isLowConfidence ? "\(base) · Low confidence" : base
    }
}

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

// MARK: - Champion Portrait Row

/// Horizontal row of up to 4 champion portraits, 6 px gap.
struct ChampionPortraitRow: View {
    let champions: [Champion]
    /// Border color applied to BIS-carry portraits (matches comp tier).
    let tierColor: Color

    var body: some View {
        HStack(spacing: Theme.Spacing.gapChampionIcons) {
            ForEach(champions, id: \.id) { champ in
                ChampionPortrait(champion: champ, tierColor: tierColor)
            }
        }
    }
}

/// Single 32×32 px circular portrait.
/// Fill = cost color; overlay = 2-char initials; BIS carry = 2 px tier border.
struct ChampionPortrait: View {
    let champion: Champion
    let tierColor: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(costColor)
            Text(ChampionCatalog.initials(forId: champion.id))
                .font(.system(size: 10, weight: .bold, design: .default))
                .foregroundStyle(Color.white)
        }
        .frame(width: Theme.Spacing.championPortrait,
               height: Theme.Spacing.championPortrait)
        .overlay(
            Circle()
                .stroke(champion.isCarry ? tierColor : Color.clear, lineWidth: 2)
        )
    }

    /// TFT in-game cost colors: 1=gray, 2=green, 3=blue, 4=purple, 5=gold.
    private var costColor: Color {
        switch champion.cost {
        case 1: return Color.gray
        case 2: return Color.green
        case 3: return Color.blue
        case 4: return Color.purple
        case 5: return Theme.Colors.accentGold
        default: return Color.gray
        }
    }
}
