import XCTest
@testable import TFTMac

/// Hex grid geometry tests.
///
/// Convention: pointy-top hexes laid out as **offset coordinates** — odd rows
/// shifted right by half a hex width. Vertical row spacing = hexSize × √3/2.
/// hexSize = full diameter (vertex-to-opposite-vertex). hexSize/2 = radius.
///
/// Concrete example (hexSize=30): row 0 col 0 center is at (15, 15) — radius
/// inset from origin. Row 1 col 0 is shifted (odd row offset) to x=30,
/// y=15+30×0.866≈41.
final class HexGridGeometryTests: XCTestCase {

    func test_centerForRow0Col0() {
        let center = HexGeometry.center(row: 0, col: 0, hexSize: 30)
        // Row 0 (even, no offset). Origin inset by radius=15 in both axes.
        XCTAssertEqual(center.x, 15, accuracy: 0.5)
        XCTAssertEqual(center.y, 15, accuracy: 0.5)
    }

    func test_centerForRow1Col0_oddRowShifted() {
        let center = HexGeometry.center(row: 1, col: 0, hexSize: 30)
        // Row 1 is odd → shifted right by hexSize/2 = 15. So x = 15 + 15 = 30.
        // Y: row spacing = 30 × √3/2 ≈ 25.98. Row 1 y = 15 + 25.98 ≈ 41.
        XCTAssertEqual(center.x, 30, accuracy: 0.5)
        XCTAssertEqual(center.y, 41, accuracy: 1.0)
    }

    func test_centerColIncrements() {
        let r0c3 = HexGeometry.center(row: 0, col: 3, hexSize: 30)
        // col 3 of row 0: x = radius + 3 × hexSize = 15 + 90 = 105
        XCTAssertEqual(r0c3.x, 105, accuracy: 0.5)
    }

    func test_totalGridSizeFor4Rows7Cols() {
        let size = HexGeometry.totalSize(rows: 4, cols: 7, hexSize: 30)
        // Width: 7 cols × 30 + half-hex right offset for any odd row = 210 + 15 = 225.
        // Height: hexSize + (rows-1) × hexSize × √3/2 = 30 + 3 × 25.98 ≈ 108.
        XCTAssertEqual(size.width, 225, accuracy: 1.0)
        XCTAssertEqual(size.height, 108, accuracy: 2.0)
    }

    func test_lastHexFitsInsideTotalSize() {
        // The center of the last hex (row 3, col 6) plus its radius must fit
        // inside totalSize. Otherwise HexGridView clips the last cell.
        let hexSize: CGFloat = 30
        let last = HexGeometry.center(row: 3, col: 6, hexSize: hexSize)
        let total = HexGeometry.totalSize(rows: 4, cols: 7, hexSize: hexSize)
        let radius = hexSize / 2
        XCTAssertLessThanOrEqual(last.x + radius, total.width + 0.01)
        XCTAssertLessThanOrEqual(last.y + radius, total.height + 0.01)
    }
}
