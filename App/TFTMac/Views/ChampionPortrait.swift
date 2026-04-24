import SwiftUI

/// Wave 5c placeholder champion portrait.
///
/// Per D5 decision: v0.1 renders a gray placeholder circle + SF Symbol
/// `person.circle.fill` + display name under the portrait. Phase 2 pipeline
/// swaps the gray circle for `AsyncImage(url: champion.iconURL)` — a 1-line
/// change inside `portraitFill` below, no callsite churn.
///
/// Why placeholder over cost-colored circle: the TFTactics reference image
/// (docs/reference_image/tfttactics_windows.png) shows real icons with name
/// labels. Cost-colored initials worked for Wave 1-4 as a tier list, but the
/// overlay (Wave 5b) demands recognizable portraits — placeholder + text name
/// gives users the hook they need while real icons are pending.
///
/// Layout:
/// ```
///    ★★          ← StarLevelIndicator (top-overlay)
///  ┌────┐
///  │  ◯ │        ← placeholder circle + SF Symbol
///  └────┘
///   Jinx         ← Text(displayName)
/// ```
///
/// Plain-language: analogy — như avatar mặc định trong Slack khi user chưa
/// upload ảnh. User vẫn nhìn ra "ai là ai" nhờ tên dưới (display name), icon
/// thực thay vào Phase 2 không thay đổi layout.
struct ChampionPortrait: View {
    let champion: Champion

    /// Tier color applied as border when `champion.isCarry == true`.
    /// Non-carry champions render with no border.
    let tierColor: Color

    /// Portrait diameter. Default matches wireframe 40px (slightly larger than
    /// v1's 32px to accommodate the star overlay + leave room for name).
    var size: CGFloat = 40

    var body: some View {
        VStack(spacing: 3) {
            portraitStack
            Text(ChampionCatalog.displayName(forId: champion.id))
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineLimit(1)
                .frame(maxWidth: size + 12)
        }
    }

    private var portraitStack: some View {
        ZStack(alignment: .top) {
            portraitFill
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .stroke(champion.isCarry ? tierColor : Color.clear, lineWidth: 2)
                )

            // Star overlay pinned top; offsets push it above the portrait edge
            // so it doesn't occlude the placeholder icon.
            StarLevelIndicator(level: StarLevelIndicator.derivedLevel(for: champion))
                .offset(y: -8)
        }
        .frame(height: size + 6)  // room for the offset star row
    }

    /// Phase 2 swap point: replace this with `AsyncImage(url: champion.iconURL)`.
    /// Keeping it isolated so Phase 2 is a 1-line change, not a view restructure.
    private var portraitFill: some View {
        ZStack {
            Circle()
                .fill(Color.gray.opacity(0.3))
            Image(systemName: "person.circle.fill")
                .font(.system(size: size * 0.6))
                .foregroundStyle(Color.gray.opacity(0.7))
        }
    }
}
