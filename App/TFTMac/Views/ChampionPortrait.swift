import SwiftUI

/// Phase 3 (TFTactics-style) upgrade: cost-color border on every champion (was
/// tier-color, carry-only) + 3-item overlay on bottom of carry portraits
/// (replaces the legacy text-row item display).
///
/// Layout:
/// ```
///    ⭐⭐⭐                ← StarLevelIndicator (top, only when starLevel >= 3)
///   ┌──────┐
///   │ FACE │             ← portrait image, costColor border ring 2pt (always)
///   │ ┌──┐ │             ← 3 ItemBadge overlay bottom 30%, ZStack alignment .bottom
///   │ │II│I│
///   └──────┘
///    Jinx                ← Text(displayName)
/// ```
///
/// Plain-language: trước Phase 3 user thấy portrait với border tier (S/A/B/C
/// color) chỉ trên carry. Sau Phase 3: mọi champion có border màu theo cost
/// (1=gray, 2=green, 3=blue, 4=purple, 5=gold) — match TFTactics web. Carry
/// thêm 3 ô item nhỏ (12pt) overlay đáy portrait — user glance 0.3s nhận diện
/// build (xây dựng) item carry mà không phải đọc text row riêng.
struct ChampionPortrait: View {
    let champion: Champion

    /// Portrait diameter. Default matches wireframe 40px.
    var size: CGFloat = 40

    @State private var image: NSImage?

    var body: some View {
        VStack(spacing: 3) {
            portraitStack
            Text(ChampionCatalog.displayName(forId: champion.id))
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineLimit(1)
                .frame(maxWidth: size + 12)
        }
        .task {
            guard image == nil,
                  let url = ChampionAssetURL.squarePortrait(forChampionId: champion.id),
                  let data = try? await AssetCache.shared.data(for: url),
                  let nsImage = NSImage(data: data) else { return }
            self.image = nsImage
        }
    }

    private var portraitStack: some View {
        ZStack(alignment: .bottom) {
            portraitFill
                .frame(width: size, height: size)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(costBorderColor(champion.cost), lineWidth: 2)
                )

            if champion.isCarry && !champion.items.isEmpty {
                itemsOverlay
                    .padding(.bottom, 2)  // tiny inset so badges don't kiss the border
            }
        }
        .overlay(alignment: .top) {
            // Star indicator only renders for starLevel >= 3 (per Phase 2 fix).
            // Offset above portrait so it doesn't occlude the face fill.
            StarLevelIndicator(level: champion.starLevel)
                .offset(y: -8)
        }
        .frame(height: size + 6)
    }

    /// 3-item HStack overlay at bottom of portrait. 16pt badges with a
    /// semi-transparent dark pill background so icons pop on any portrait color.
    private var itemsOverlay: some View {
        HStack(spacing: 2) {
            ForEach(champion.items.prefix(3), id: \.id) { item in
                ItemBadge(itemId: item.id, size: 16)
            }
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 1)
        .background(.black.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    @ViewBuilder
    private var portraitFill: some View {
        if let image {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            placeholder
        }
    }

    /// Cost-colored placeholder fill (used when async load is in flight or
    /// the URL miss). Keeps user able to identify cost while artwork resolves.
    private var placeholder: some View {
        ZStack {
            Circle().fill(costBorderColor(champion.cost))
            Image(systemName: "person.fill")
                .font(.system(size: size * 0.5))
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    /// Cost → border color mapping. TFT canonical: 1=gray, 2=green, 3=blue,
    /// 4=purple, 5=gold. Cost outside 1-5 (Riot edge cases for high-rarity
    /// special units) → black fallback.
    private func costBorderColor(_ cost: Int) -> Color {
        switch cost {
        case 1: return .gray
        case 2: return .green
        case 3: return .blue
        case 4: return .purple
        case 5: return Theme.Colors.accentGold
        default: return .black
        }
    }
}
