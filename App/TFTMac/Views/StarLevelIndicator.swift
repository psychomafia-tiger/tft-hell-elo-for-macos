import SwiftUI

/// 3-star overlay rendered on top of `ChampionPortrait`.
///
/// Per TFTactics reference layout: only 3-star champions show star pips.
/// 1-star and 2-star champions render no overlay (EmptyView) — matching the
/// TFTactics Windows app behaviour observed in Phase 2 research.
///
/// The pipeline now emits `star_level` per champion (schema 1.2.0+) as the
/// modal observed tier, so `champion.starLevel` is passed directly and this
/// view gates on `level >= 3`.
///
/// Visual: 3 yellow star glyphs in a tight HStack, pinned to top-leading of
/// the portrait ZStack. 8pt size fits above 32-40pt portraits without
/// obscuring the champion fill.
struct StarLevelIndicator: View {
    let level: Int  // expected 1...3

    var body: some View {
        if level >= 3 {
            HStack(spacing: 1) {
                ForEach(0..<3, id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(Theme.Colors.accentGold)
                }
            }
        } else {
            EmptyView()
        }
    }

    /// Placeholder derivation from Wave 5c — superseded by `champion.starLevel`.
    ///
    /// Retained for `CompCardV2Tests` test assertions that verify the old heuristic
    /// still works as documented (carry → 2, non-carry → 1). New code should pass
    /// `champion.starLevel` directly to `StarLevelIndicator(level:)`.
    @available(*, deprecated, message: "Use champion.starLevel directly — pipeline now emits star_level per champion (schema 1.2.0+)")
    static func derivedLevel(for champion: Champion) -> Int {
        champion.isCarry ? 2 : 1
    }
}
