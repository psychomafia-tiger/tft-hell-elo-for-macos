import SwiftUI

/// Renders a single active trait as a pill chip: icon + display name + activation count.
///
/// Style (bronze/silver/gold/chromatic) drives chip background tint and border color.
/// Icon loads async via AssetCache; falls back to star.fill placeholder on URL miss or
/// network failure — mirrors the ChampionPortrait async pattern.
///
/// Plain-language: như badge trait trong TFT in-game hud — "Psionic 4" với viền vàng
/// khi đạt gold tier (4 units active). Background tint opacity 25% nên chip đọc được
/// trên nền tối của popover mà không choán mắt.
struct TraitChip: View {
    let activation: TraitActivation

    /// Loaded asynchronously; nil until fetch resolves or on any failure.
    @State private var iconImage: NSImage?

    /// Display label: catalog-resolved name + count.
    /// Example: TraitActivation(name: "TFT17_PsyOps", count: 4) → "Psionic 4"
    /// Fallback for unknown apiName: strip "TFT17_" prefix → "Mystery 2"
    var displayLabel: String {
        "\(TraitCatalog.displayName(forApiName: activation.name)) \(activation.count)"
    }

    var body: some View {
        HStack(spacing: 4) {
            iconCircle
            Text(displayLabel)
                .font(Theme.Fonts.monoCaption)
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(chipColor.opacity(0.25))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(chipColor, lineWidth: 1))
        .task {
            guard iconImage == nil,
                  let url = TraitAssetURL.icon(forApiName: activation.name),
                  let data = try? await AssetCache.shared.data(for: url),
                  let img = NSImage(data: data) else { return }
            iconImage = img
        }
    }

    /// 18pt circle housing the trait icon (or star.fill placeholder while loading / on miss).
    private var iconCircle: some View {
        ZStack {
            Circle().fill(chipColor)
            if let img = iconImage {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 12, height: 12)
            } else {
                Image(systemName: "star.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 18, height: 18)
    }

    /// Maps trait activation style to Theme accent color.
    /// Chromatic (prismatic) tier uses purple — no dedicated Theme token yet.
    private var chipColor: Color {
        switch activation.style {
        case .bronze:    return Theme.Colors.accentBronze
        case .silver:    return Theme.Colors.accentSilver
        case .gold:      return Theme.Colors.accentGold
        case .chromatic: return Color.purple
        }
    }
}
