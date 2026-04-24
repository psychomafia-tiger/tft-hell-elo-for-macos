import SwiftUI

/// 1/2/3-star overlay rendered on top of `ChampionPortrait`.
///
/// Per TFTactics reference layout: carry champions show 2-star or 3-star pips
/// above the portrait; supports show 1-star. For v0.1 placeholder we derive
/// star level from `Champion.isCarry` (carry→2, non-carry→1) — Phase 2 pipeline
/// will enrich the schema with actual observed star level.
///
/// Visual: N yellow filled-circle glyphs in a tight HStack, pinned to top-leading
/// of the portrait ZStack. 8pt size fits above 32-40pt portraits without
/// obscuring the champion fill.
struct StarLevelIndicator: View {
    let level: Int  // expected 1...3; clamped defensively

    private var clampedLevel: Int {
        max(1, min(3, level))
    }

    var body: some View {
        HStack(spacing: 1) {
            ForEach(0..<clampedLevel, id: \.self) { _ in
                Image(systemName: "star.fill")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(Theme.Colors.accentGold)
            }
        }
    }

    /// Wave 5c placeholder derivation — Phase 2 schema will carry `starLevel`
    /// per champion as an observed statistic. Until then: carry → 2, else → 1.
    static func derivedLevel(for champion: Champion) -> Int {
        champion.isCarry ? 2 : 1
    }
}
