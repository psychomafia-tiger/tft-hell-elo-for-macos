import XCTest
@testable import TFTMac

/// Regression test T4 — locks the data contract between Phase 1 bundled fixture
/// and Phase 2 R2-fetched tier-list.json.
///
/// If the Phase 2 pipeline adds, removes, or renames a field, this test catches
/// the drift and forces an explicit schema_version bump + fixture update before
/// the app can ship.
final class SampleTierListFixtureTests: XCTestCase {

    func testFixtureStructureMatchesContract() throws {
        let url = Bundle.main.url(forResource: "sample-tier-list", withExtension: "json")
        XCTAssertNotNil(url, "Fixture missing — expected in app main bundle")

        let data = try Data(contentsOf: url!)
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .iso8601
        let tierList = try d.decode(TierList.self, from: data)

        // --- Top-level contract ---
        XCTAssertEqual(
            tierList.schemaVersion,
            SchemaVersion(major: 1, minor: 0, patch: 0),
            "schema_version must be 1.0.0"
        )
        XCTAssertEqual(tierList.eloBracket, "CHALLENGER")
        XCTAssertEqual(tierList.dataWindowHours, 12)
        XCTAssertEqual(tierList.comps.count, 10, "Fixture must have exactly 10 comps")

        // --- Tier distribution contract (used by Task 1.9 UI rendering) ---
        let tierCounts = Dictionary(grouping: tierList.comps, by: \.tier).mapValues(\.count)
        XCTAssertEqual(tierCounts[.S] ?? 0, 4, "Expected 4 S-tier comps")
        XCTAssertEqual(tierCounts[.A] ?? 0, 4, "Expected 4 A-tier comps")
        XCTAssertEqual(tierCounts[.B] ?? 0, 2, "Expected 2 B-tier comps")

        // --- Low sample size required for Task 1.9 gray-out rendering test ---
        XCTAssertTrue(
            tierList.comps.contains { $0.sampleSize < 100 },
            "Need ≥1 comp with sample_size <100 for Task 1.9 gray-out UI test"
        )

        // --- Flex champions required for Task 1.9 "Flex" label UI test ---
        let flexChampions = tierList.comps.flatMap(\.champions).filter { $0.items.isEmpty }
        XCTAssertGreaterThanOrEqual(
            flexChampions.count, 2,
            "Need ≥2 Flex champions (empty items array) for Task 1.9 UI test"
        )

        // --- Exactly one carry per comp (pipeline data invariant) ---
        for comp in tierList.comps {
            let carryCount = comp.champions.filter(\.isCarry).count
            XCTAssertEqual(
                carryCount, 1,
                "Comp \(comp.compId) should have exactly 1 carry champion"
            )
        }

        // --- Tier ordering preserved (S first in sorted fixture) ---
        XCTAssertEqual(tierList.comps.first?.tier, .S, "First comp must be S-tier")
        XCTAssertEqual(tierList.comps.last?.tier, .B, "Last comp must be B-tier")

        // --- Statistical sanity: no comp can appear in more matches than were sampled ---
        XCTAssertTrue(
            tierList.comps.allSatisfy { $0.sampleSize <= tierList.totalMatchesSampled },
            "Individual comp sample_size cannot exceed total matches sampled"
        )
    }
}
