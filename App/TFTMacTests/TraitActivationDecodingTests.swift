import XCTest
@testable import TFTMac

final class TraitActivationDecodingTests: XCTestCase {

    func test_decodesV1_2_0CompWithTraits() throws {
        let json = #"""
        {
          "comp_id": "psionic-conduits",
          "name": "Psionic Conduits",
          "tier": "S",
          "play_rate": 0.082,
          "avg_placement": 3.95,
          "top_4_rate": 0.61,
          "sample_size": 142,
          "champions": [],
          "anomalies": [],
          "traits": [
            {"name": "TFT17_Psionic", "count": 4, "style": "gold"},
            {"name": "TFT17_Conduit", "count": 2, "style": "silver"}
          ]
        }
        """#.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let comp = try decoder.decode(Comp.self, from: json)
        XCTAssertEqual(comp.traits.count, 2)
        XCTAssertEqual(comp.traits.first?.name, "TFT17_Psionic")
        XCTAssertEqual(comp.traits.first?.count, 4)
        XCTAssertEqual(comp.traits.first?.style, .gold)
    }

    func test_decodesV1_1_0CompWithoutTraits() throws {
        let json = #"""
        {
          "comp_id": "old-comp",
          "name": "Old Comp",
          "tier": "B",
          "play_rate": 0.05,
          "avg_placement": 4.5,
          "top_4_rate": 0.50,
          "sample_size": 100,
          "champions": [],
          "anomalies": []
        }
        """#.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let comp = try decoder.decode(Comp.self, from: json)
        XCTAssertEqual(comp.traits, [])
    }
}
