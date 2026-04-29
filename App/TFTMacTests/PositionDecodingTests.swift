import XCTest
@testable import TFTMac

final class PositionDecodingTests: XCTestCase {

    func test_decodesPositionFromV1_4_0() throws {
        let json = #"""
        {"championId": "TFT17_Aatrox", "pos": 14, "frequency": 0.85}
        """#.data(using: .utf8)!
        let p = try JSONDecoder().decode(Position.self, from: json)
        XCTAssertEqual(p.championId, "TFT17_Aatrox")
        XCTAssertEqual(p.pos, 14)
        XCTAssertEqual(p.frequency, 0.85, accuracy: 0.0001)
        // Derived row/col from pos.
        XCTAssertEqual(p.row, 2)  // 14 / 7
        XCTAssertEqual(p.col, 0)  // 14 % 7
    }

    func test_rowAndColMappingForBoardCorners() {
        // pos 0 → row 0 col 0 (top-left, your backline corner)
        XCTAssertEqual(Position(championId: "x", pos: 0, frequency: 1).row, 0)
        XCTAssertEqual(Position(championId: "x", pos: 0, frequency: 1).col, 0)
        // pos 6 → row 0 col 6 (top-right backline)
        XCTAssertEqual(Position(championId: "x", pos: 6, frequency: 1).col, 6)
        // pos 27 → row 3 col 6 (bottom-right frontline)
        XCTAssertEqual(Position(championId: "x", pos: 27, frequency: 1).row, 3)
        XCTAssertEqual(Position(championId: "x", pos: 27, frequency: 1).col, 6)
    }

    func test_compForwardCompatMissingPositioning() throws {
        // Schema v1.2.0 / v1.3.0 JSON without `positioning` should decode with [].
        let json = #"""
        {
          "comp_id": "x", "name": "X", "tier": "B",
          "play_rate": 0.02, "avg_placement": 4.5, "top_4_rate": 0.4,
          "sample_size": 50, "champions": [], "anomalies": [], "traits": []
        }
        """#.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let comp = try decoder.decode(Comp.self, from: json)
        XCTAssertEqual(comp.positioning, [])
    }

    func test_compDecodesV1_4_0Positioning() throws {
        let json = #"""
        {
          "comp_id": "viktor-karma", "name": "Viktor Karma", "tier": "S",
          "play_rate": 0.10, "avg_placement": 3.8, "top_4_rate": 0.6,
          "sample_size": 120, "champions": [], "anomalies": [], "traits": [],
          "positioning": [
            {"championId": "TFT17_Viktor", "pos": 3, "frequency": 1.0},
            {"championId": "TFT17_Karma", "pos": 1, "frequency": 1.0}
          ]
        }
        """#.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let comp = try decoder.decode(Comp.self, from: json)
        XCTAssertEqual(comp.positioning.count, 2)
        XCTAssertEqual(comp.positioning[0].championId, "TFT17_Viktor")
        XCTAssertEqual(comp.positioning[0].pos, 3)
    }
}
