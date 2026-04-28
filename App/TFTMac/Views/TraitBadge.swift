import SwiftUI

/// Compact 26×26pt icon-only trait badge for the expanded card section.
///
/// Shows: tinted rounded-square background + async trait icon centered +
/// activation count overlay (bottom-right corner). No text label.
///
/// `.help()` surfaces the full display name on hover — this is the
/// primary way the user reads the trait name, matching TFTactics tooltip
/// UX pattern. Example: hover → tooltip "Dark Star 1".
///
/// Parallel to `ItemBadge` (12pt items) — same async/fallback pattern,
/// larger size and count overlay added for trait context.
struct TraitBadge: View {
    let activation: TraitActivation

    @State private var iconImage: NSImage?

    private static let badgeSize: CGFloat = 26
    private static let iconSize: CGFloat = 16

    var body: some View {
        badgeTile
            .overlay { iconView }                                    // centered
            .overlay(alignment: .bottomTrailing) { countPip }       // pip overflows corner
            .frame(width: Self.badgeSize, height: Self.badgeSize)
            .clipped()  // keep pip visible but stop overflow past frame
            .help("\(TraitCatalog.displayName(forApiName: activation.name)) (\(activation.count))")
            .task {
                guard iconImage == nil,
                      let url = TraitAssetURL.icon(forApiName: activation.name),
                      let data = try? await AssetCache.shared.data(for: url),
                      let img = NSImage(data: data) else { return }
                iconImage = img
            }
    }

    /// Tinted rounded-square background tile.
    private var badgeTile: some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(chipColor.opacity(0.20))
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(chipColor, lineWidth: 1)
            )
            .frame(width: Self.badgeSize, height: Self.badgeSize)
    }

    /// Centered trait icon. Falls back to `star.fill` while loading or on miss.
    @ViewBuilder
    private var iconView: some View {
        if let img = iconImage {
            Image(nsImage: img)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: Self.iconSize, height: Self.iconSize)
                .padding((Self.badgeSize - Self.iconSize) / 2 - 3)
        } else {
            Image(systemName: "star.fill")
                .font(.system(size: 10))
                .foregroundStyle(chipColor.opacity(0.8))
        }
    }

    /// Small count pill at bottom-right corner.
    private var countPip: some View {
        Text("\(activation.count)")
            .font(.system(size: 7, weight: .bold, design: .monospaced))
            .foregroundStyle(.white)
            .padding(.horizontal, 3)
            .padding(.vertical, 1)
            .background(chipColor)
            .clipShape(Capsule())
            .offset(x: 4, y: 4)
    }

    private var chipColor: Color {
        switch activation.style {
        case .bronze:    return Theme.Colors.accentBronze
        case .silver:    return Theme.Colors.accentSilver
        case .gold:      return Theme.Colors.accentGold
        case .chromatic: return Color.purple
        }
    }
}
