import Foundation

/// Champion hex position on the 4×7 TFT board (schema 1.4.0+).
///
/// `pos` is 0-27 mapped row-major (4 rows × 7 cols):
/// - Row 0 (pos 0-6) = backline (your side, far from enemy) — typically carries
/// - Row 3 (pos 21-27) = frontline (closest to enemy) — typically tanks
///
/// `frequency` is the fraction of top-4 placements where this champion
/// appeared at this hex. `1.0` signals "rule-inferred" (Riot Match-v5
/// did not expose positions for Set 17, so the pipeline assigned hexes
/// from cost + carry status). When Riot starts emitting `pos`, the
/// pipeline switches to modal-frequency aggregation and values fall <1.0.
struct Position: Codable, Equatable {
    let championId: String
    let pos: Int
    let frequency: Double

    /// Hex row 0-3. Row 0 = backline, row 3 = frontline.
    var row: Int { pos / 7 }

    /// Hex col 0-6. Col 0 = leftmost.
    var col: Int { pos % 7 }
}
