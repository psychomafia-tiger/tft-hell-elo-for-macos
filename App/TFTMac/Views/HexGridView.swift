import SwiftUI

/// 4×7 TFT board with champion portraits placed at each comp's modal hex.
///
/// `pos` mapping (schema 1.4.0): row = pos/7, col = pos%7.
/// - Row 0 (pos 0-6) = backline (your side, far from enemy)
/// - Row 3 (pos 21-27) = frontline (closest to enemy)
///
/// Empty hexes still render (outline only) so users see the full board
/// shape and can read positioning at a glance.
struct HexGridView: View {
    let positioning: [Position]
    var hexSize: CGFloat = 32

    private var positionMap: [Int: String] {
        // Last write wins on duplicate pos — should never happen since the
        // pipeline guarantees no collisions, but be defensive.
        Dictionary(positioning.map { ($0.pos, $0.championId) }, uniquingKeysWith: { _, b in b })
    }

    var body: some View {
        let total = HexGeometry.totalSize(rows: 4, cols: 7, hexSize: hexSize)
        ZStack(alignment: .topLeading) {
            ForEach(0..<4, id: \.self) { row in
                ForEach(0..<7, id: \.self) { col in
                    let pos = row * 7 + col
                    let center = HexGeometry.center(row: row, col: col, hexSize: hexSize)
                    HexCell(championId: positionMap[pos], hexSize: hexSize)
                        .position(x: center.x, y: center.y)
                }
            }
        }
        .frame(width: total.width, height: total.height)
    }
}

/// Card section wrapping a labeled HexGridView for inclusion in ExpandedCardView.
struct PositioningSection: View {
    let positioning: [Position]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("POSITIONING")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Theme.Colors.textMuted)
            HexGridView(positioning: positioning)
                .padding(.vertical, 4)
        }
    }
}
