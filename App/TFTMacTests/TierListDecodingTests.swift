import XCTest
@testable import TFTMac

final class TierListDecodingTests: XCTestCase {

    private func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .iso8601
        return d
    }

    // MARK: - Test 1: Valid JSON decodes with all fields populated

    func testValidJSONDecodesWithAllFields() throws {
        let json = """
        {
          "schema_version": "1.0.0",
          "patch_version": "16.8",
          "last_updated": "2026-04-24T12:00:00Z",
          "data_window_hours": 12,
          "elo_bracket": "CHALLENGER",
          "total_matches_sampled": 98,
          "comps": [
            { "comp_id": "test-comp", "name": "Test Comp", "tier": "S",
              "play_rate": 0.15, "avg_placement": 3.5, "top_4_rate": 0.6,
              "sample_size": 120,
              "champions": [
                { "id": "TFT17_Viktor", "cost": 5, "is_carry": true,
                  "items": [{"id": "TFT_Item_JeweledGauntlet", "agreement": 0.77}] }
              ]
            }
          ]
        }
        """.data(using: .utf8)!

        let tierList = try decoder().decode(TierList.self, from: json)

        XCTAssertEqual(tierList.schemaVersion, SchemaVersion(major: 1, minor: 0, patch: 0))
        XCTAssertEqual(tierList.patchVersion, "16.8")
        XCTAssertEqual(tierList.dataWindowHours, 12)
        XCTAssertEqual(tierList.eloBracket, "CHALLENGER")
        XCTAssertEqual(tierList.totalMatchesSampled, 98)
        XCTAssertEqual(tierList.comps.count, 1)

        let comp = tierList.comps[0]
        XCTAssertEqual(comp.compId, "test-comp")
        XCTAssertEqual(comp.name, "Test Comp")
        XCTAssertEqual(comp.tier, .S)
        XCTAssertEqual(comp.playRate, 0.15, accuracy: 0.0001)
        XCTAssertEqual(comp.avgPlacement, 3.5, accuracy: 0.0001)
        XCTAssertEqual(comp.top4Rate, 0.6, accuracy: 0.0001)
        XCTAssertEqual(comp.sampleSize, 120)

        let champ = try XCTUnwrap(comp.champions.first)
        XCTAssertEqual(champ.id, "TFT17_Viktor")
        XCTAssertEqual(champ.cost, 5)
        XCTAssertEqual(champ.isCarry, true)

        let item = try XCTUnwrap(champ.items.first)
        XCTAssertEqual(item.id, "TFT_Item_JeweledGauntlet")
        XCTAssertEqual(item.agreement, 0.77, accuracy: 0.0001)
    }

    // MARK: - Test 2: Unknown fields ignored gracefully (forward-compat)

    func testUnknownFieldsIgnoredGracefully() throws {
        // Future pipeline versions may add "new_field" — app v0.1 must not crash.
        let json = """
        {
          "schema_version": "1.0.0",
          "patch_version": "16.8",
          "last_updated": "2026-04-24T12:00:00Z",
          "data_window_hours": 12,
          "elo_bracket": "CHALLENGER",
          "total_matches_sampled": 98,
          "unknown_top_level_field": "should_not_cause_error",
          "comps": [
            { "comp_id": "t", "name": "T", "tier": "S",
              "play_rate": 0.15, "avg_placement": 3.5, "top_4_rate": 0.6,
              "sample_size": 120,
              "mystery_metric": 42,
              "champions": []
            }
          ]
        }
        """.data(using: .utf8)!

        XCTAssertNoThrow(try decoder().decode(TierList.self, from: json))
    }

    // MARK: - Test 3: Missing required field throws DecodingError

    func testMissingRequiredFieldThrows() {
        // patch_version omitted — decoder must throw DecodingError.keyNotFound
        let json = """
        {
          "schema_version": "1.0.0",
          "last_updated": "2026-04-24T12:00:00Z",
          "data_window_hours": 12,
          "elo_bracket": "CHALLENGER",
          "total_matches_sampled": 98,
          "comps": []
        }
        """.data(using: .utf8)!

        XCTAssertThrowsError(try decoder().decode(TierList.self, from: json)) { error in
            XCTAssert(error is DecodingError, "Expected DecodingError, got \(error)")
        }
    }

    // MARK: - Test 4: comps sorted by tier (S first) is preserved

    func testCompsSortedByTierRespected() throws {
        // Decoder must preserve input array order — no accidental re-sort.
        // Pipeline is responsible for S → A → B → C ordering.
        let json = """
        {
          "schema_version": "1.0.0",
          "patch_version": "16.8",
          "last_updated": "2026-04-24T12:00:00Z",
          "data_window_hours": 12,
          "elo_bracket": "CHALLENGER",
          "total_matches_sampled": 98,
          "comps": [
            { "comp_id": "s1", "name": "S1", "tier": "S",
              "play_rate": 0.15, "avg_placement": 3.5, "top_4_rate": 0.6,
              "sample_size": 120, "champions": [] },
            { "comp_id": "a1", "name": "A1", "tier": "A",
              "play_rate": 0.08, "avg_placement": 4.1, "top_4_rate": 0.5,
              "sample_size": 110, "champions": [] },
            { "comp_id": "b1", "name": "B1", "tier": "B",
              "play_rate": 0.03, "avg_placement": 4.5, "top_4_rate": 0.45,
              "sample_size": 105, "champions": [] }
          ]
        }
        """.data(using: .utf8)!

        let tierList = try decoder().decode(TierList.self, from: json)
        XCTAssertEqual(tierList.comps.map(\.tier), [.S, .A, .B])
    }

    // MARK: - Test 5: Fixture file decodes without error

    func testFixtureDecodes() throws {
        // Bundle.main resolves to the app bundle when TEST_HOST is set (unit test host model).
        let url = Bundle(for: type(of: self)).url(forResource: "sample-tier-list", withExtension: "json")
            ?? Bundle.main.url(forResource: "sample-tier-list", withExtension: "json")

        guard let fixtureURL = url else {
            XCTFail("sample-tier-list.json not found in any bundle")
            return
        }

        let data = try Data(contentsOf: fixtureURL)
        let tierList = try decoder().decode(TierList.self, from: data)

        XCTAssertEqual(tierList.comps.count, 10, "Fixture should contain 10 comps")
        XCTAssertTrue(tierList.comps.allSatisfy { $0.sampleSize > 0 })
        XCTAssertEqual(tierList.comps.first?.tier, .S, "First comp should be S-tier")
    }
}
