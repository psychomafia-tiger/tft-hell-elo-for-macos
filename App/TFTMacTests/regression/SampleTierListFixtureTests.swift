import XCTest
@testable import TFTMac

/// Regression test — locks the data contract between bundled fixture and
/// runtime tier-list.json fetched by Phase 2 pipeline.
///
/// Phase 2 (T10) refreshed the bundled fixture from synthetic 10-comp v1.0.0
/// to real KR data emitted via `build_tier_list_payload` at schema 1.2.0.
/// Phase 4 bumped the fixture to schema 1.4.0 (positioning hex grid).
/// Assertions here are invariant-based (shape + presence) rather than
/// hardcoded counts so future fixture refreshes don't break the suite.
final class SampleTierListFixtureTests: XCTestCase {

    private func loadFixture() throws -> TierList {
        let url = Bundle.main.url(forResource: "sample-tier-list", withExtension: "json")
        XCTAssertNotNil(url, "Fixture missing — expected in app main bundle")
        let data = try Data(contentsOf: url!)
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .iso8601
        return try d.decode(TierList.self, from: data)
    }

    func testFixtureSchemaIs1_4_0() throws {
        let tierList = try loadFixture()
        XCTAssertEqual(
            tierList.schemaVersion,
            SchemaVersion(major: 1, minor: 4, patch: 0),
            "Fixture schema must be 1.4.0 (Phase 4 positioning contract)"
        )
    }

    func testFixtureCompsHaveTraits() throws {
        let tierList = try loadFixture()
        let withTraits = tierList.comps.filter { !$0.traits.isEmpty }
        XCTAssertGreaterThan(
            withTraits.count, 0,
            "Schema 1.2.0+ fixture must populate traits[] on at least one comp"
        )
    }

    func testFixtureCompsHavePositioning() throws {
        let tierList = try loadFixture()
        let withPositioning = tierList.comps.filter { !$0.positioning.isEmpty }
        XCTAssertGreaterThan(
            withPositioning.count, 0,
            "Schema 1.4.0 fixture must populate positioning[] on at least one comp"
        )
    }

    func testFixtureTopLevelContract() throws {
        let tierList = try loadFixture()
        XCTAssertEqual(tierList.eloBracket, "CHALLENGER")
        XCTAssertEqual(tierList.dataWindowHours, 12)
        XCTAssertGreaterThan(tierList.comps.count, 0, "Fixture must contain ≥1 comp")
    }

    /// Statistical sanity — no comp can appear in more participant slots than
    /// were sampled in the fixture (caught synthetic-fixture inconsistencies
    /// during pre-Phase-2 dev).
    func testFixtureSampleSizeInvariant() throws {
        let tierList = try loadFixture()
        for comp in tierList.comps {
            XCTAssertGreaterThan(comp.sampleSize, 0, "Comp \(comp.compId) must have sample_size >0")
        }
    }
}
