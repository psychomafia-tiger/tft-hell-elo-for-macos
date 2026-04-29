import SwiftUI

/// Pointy-top hex grid coordinate math (offset coordinates).
///
/// `hexSize` is the full diameter (vertex to opposite vertex). Radius =
/// `hexSize/2`. Vertical row spacing = `hexSize × √3/2 ≈ 0.866 × hexSize` —
/// this is the distance between row centers; less than the diameter so
/// adjacent rows interlock.
///
/// Odd rows shift right by `hexSize/2` (offset coords). Total grid size
/// reserves that half-hex extension on the width.
///
/// Concrete (hexSize=30): row 0 col 0 → (15, 15). Row 1 col 0 → (30, 41).
/// Row 3 col 6 → (210, 93). 4×7 board total = (225, 108).
enum HexGeometry {
    /// Cached √3/2 — vertical row-spacing factor for pointy-top hexes.
    static let sqrt3Over2: CGFloat = 0.8660254

    /// Center point of hex at (row, col). Origin = top-left of grid.
    static func center(row: Int, col: Int, hexSize: CGFloat) -> CGPoint {
        let radius = hexSize / 2
        let xOffset = (row % 2 == 1) ? radius : 0
        let x = radius + CGFloat(col) * hexSize + xOffset
        let y = radius + CGFloat(row) * hexSize * sqrt3Over2
        return CGPoint(x: x, y: y)
    }

    /// Bounding size for a (rows × cols) grid of hexes.
    static func totalSize(rows: Int, cols: Int, hexSize: CGFloat) -> CGSize {
        // Width: every col contributes hexSize. Plus half-hex if any odd row exists.
        let oddRowExtension: CGFloat = (rows > 1) ? hexSize / 2 : 0
        let width = CGFloat(cols) * hexSize + oddRowExtension
        // Height: first hex full diameter + (rows-1) × row-spacing.
        let height = hexSize + CGFloat(rows - 1) * hexSize * sqrt3Over2
        return CGSize(width: width, height: height)
    }
}

/// Pointy-top hexagon path inscribed in `rect`.
struct HexagonShape: Shape {
    func path(in rect: CGRect) -> Path {
        let r = min(rect.width, rect.height) / 2
        let cx = rect.midX
        let cy = rect.midY
        var path = Path()
        // 6 vertices, starting at the top (-90°). 60° step.
        for i in 0..<6 {
            let angle = CGFloat(i) * .pi / 3 - .pi / 2
            let point = CGPoint(x: cx + r * cos(angle), y: cy + r * sin(angle))
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

/// Single hex cell. Renders the hex outline always; if `championId` non-nil,
/// loads + overlays the champion portrait clipped to a circle.
struct HexCell: View {
    let championId: String?
    var hexSize: CGFloat = 36

    @State private var image: NSImage?

    var body: some View {
        ZStack {
            HexagonShape()
                .fill(Theme.Colors.bgCard.opacity(0.4))
            HexagonShape()
                .stroke(Theme.Colors.borderDefault, lineWidth: 1)

            if let cid = championId {
                Group {
                    if let img = image {
                        Image(nsImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Circle().fill(Theme.Colors.bgCard)
                    }
                }
                .frame(width: hexSize * 0.7, height: hexSize * 0.7)
                .clipShape(Circle())
            }
        }
        .frame(width: hexSize, height: hexSize)
        .help(championId.map { ChampionCatalog.displayName(forId: $0) } ?? "")
        .task(id: championId) {
            guard let cid = championId, image == nil,
                  let url = ChampionAssetURL.squarePortrait(forChampionId: cid),
                  let data = try? await AssetCache.shared.data(for: url),
                  let img = NSImage(data: data) else { return }
            self.image = img
        }
    }
}
