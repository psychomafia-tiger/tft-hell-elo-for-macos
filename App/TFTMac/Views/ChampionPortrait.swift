import SwiftUI

/// Phase 1 (P1.T6) upgrade: real CommunityDragon Set 17 artwork loaded async via
/// `AssetCache` + `ChampionAssetURL`, with cost-colored placeholder fallback on
/// miss/offline. Display name + star overlay rendered identically to Wave 5c.
///
/// Layout:
/// ```
///    ★★          ← StarLevelIndicator (top-overlay)
///  ┌────┐
///  │ IMG│        ← real portrait (or placeholder while loading / on miss)
///  └────┘
///   Jinx         ← Text(displayName)
/// ```
///
/// Plain-language: trước Phase 1 user thấy avatar xám mặc định (như Slack chưa
/// upload ảnh). Sau P1.T6: user thấy real portrait Aatrox/Viktor/Illaoi từ
/// CommunityDragon CDN. Async load qua `.task` — nếu offline hoặc URL miss,
/// fallback về placeholder cost-colored circle (ví dụ: 5-cost = vàng gold,
/// 1-cost = xám) → user vẫn nhận diện được tier qua màu.
///
/// Caller contract preserved: `ChampionPortrait(champion:tierColor:)` —
/// `size` parameter retained as optional default (40pt) for any future callers.
struct ChampionPortrait: View {
    let champion: Champion

    /// Tier color applied as border when `champion.isCarry == true`.
    /// Non-carry champions render with no border.
    let tierColor: Color

    /// Portrait diameter. Default matches wireframe 40px (slightly larger than
    /// v1's 32px to accommodate the star overlay + leave room for name).
    var size: CGFloat = 40

    /// Loaded NSImage cached in @State so re-renders don't re-fetch.
    /// Nil before load completes / on URL miss / on network failure.
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
            // Guard re-fetch on view re-render (e.g. parent state change).
            // Swift's task modifier already re-runs on .id() change, but @State
            // image survives within the same identity — explicit guard is cheap.
            guard image == nil,
                  let url = ChampionAssetURL.squarePortrait(forChampionId: champion.id),
                  let data = try? await AssetCache.shared.data(for: url),
                  let nsImage = NSImage(data: data) else { return }
            self.image = nsImage
        }
    }

    private var portraitStack: some View {
        ZStack(alignment: .top) {
            portraitFill
                .frame(width: size, height: size)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(champion.isCarry ? tierColor : Color.clear, lineWidth: 2)
                )

            // Star overlay pinned top; offsets push it above the portrait edge
            // so it doesn't occlude the champion fill.
            StarLevelIndicator(level: StarLevelIndicator.derivedLevel(for: champion))
                .offset(y: -8)
        }
        .frame(height: size + 6)  // room for the offset star row
    }

    /// Renders real portrait if loaded; otherwise cost-colored placeholder.
    /// Phase 2 may add a brief loading shimmer — current behavior swaps
    /// instantly when image arrives (acceptable for cached/fast paths).
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

    /// Cost-colored fallback (1-cost gray → 5-cost gold). Matches TFT's in-game
    /// shop tier colors so users can still identify champion cost while async
    /// load is in flight or has failed.
    private var placeholder: some View {
        ZStack {
            Circle().fill(costColor(champion.cost))
            Image(systemName: "person.fill")
                .font(.system(size: size * 0.5))
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    private func costColor(_ cost: Int) -> Color {
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
