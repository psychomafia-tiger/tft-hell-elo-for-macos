import XCTest
@testable import TFTMac

final class SchemaCompatibilityGateTests: XCTestCase {

    private let gate = SchemaCompatibilityGate()

    // MARK: - Helpers

    /// Build a minimal TierList with the given schema version for gate testing.
    private func tierList(schema: SchemaVersion) -> TierList {
        // Use bundled JSON as base, then rely on decoder — but TierList.init
        // is custom (no memberwise init exposed). We decode a minimal JSON string.
        let json = """
        {
          "schema_version": "\(schema.major).\(schema.minor).\(schema.patch)",
          "patch_version": "16.8",
          "last_updated": "2026-04-24T12:00:00Z",
          "data_window_hours": 12,
          "elo_bracket": "CHALLENGER",
          "total_matches_sampled": 50,
          "comps": []
        }
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return try! decoder.decode(TierList.self, from: json)
    }

    // MARK: - App schema constant

    func testAppSchemaIsVersion100() {
        XCTAssertEqual(SchemaCompatibilityGate.appSchema, SchemaVersion(major: 1, minor: 0, patch: 0))
    }

    // MARK: - .ok cases

    /// Bundled JSON schema 1.0.0 must pass the gate (same as app schema).
    func testBundledSchema100IsOk() {
        let tl = tierList(schema: SchemaVersion(major: 1, minor: 0, patch: 0))
        XCTAssertEqual(gate.check(tl), .ok)
    }

    /// Remote JSON schema 1.1.0 must pass the gate (data minor 1 >= app minor 0).
    func testRemoteSchema110IsOk() {
        let tl = tierList(schema: SchemaVersion(major: 1, minor: 1, patch: 0))
        XCTAssertEqual(gate.check(tl), .ok)
    }

    /// Schema 1.5.0 passes (data minor 5, within 10-minor forward window from 0).
    func testSchema150IsOk() {
        let tl = tierList(schema: SchemaVersion(major: 1, minor: 5, patch: 0))
        XCTAssertEqual(gate.check(tl), .ok)
    }

    /// Patch version differences are irrelevant — 1.0.3 passes.
    func testPatchVersionIgnored() {
        let tl = tierList(schema: SchemaVersion(major: 1, minor: 0, patch: 3))
        XCTAssertEqual(gate.check(tl), .ok)
    }

    // MARK: - .updateRequired cases

    /// Schema 2.0.0 must be rejected (major version mismatch).
    func testSchema200IsUpdateRequired() {
        let tl = tierList(schema: SchemaVersion(major: 2, minor: 0, patch: 0))
        XCTAssertEqual(gate.check(tl), .updateRequired)
    }

    /// Schema 0.9.0 must be rejected (major version mismatch).
    func testSchema090IsUpdateRequired() {
        let tl = tierList(schema: SchemaVersion(major: 0, minor: 9, patch: 0))
        XCTAssertEqual(gate.check(tl), .updateRequired)
    }

    /// Schema 1.11.0 must be rejected (data minor 11 exceeds 10-minor forward window from 0).
    func testSchema1110ExceedsForwardWindow() {
        let tl = tierList(schema: SchemaVersion(major: 1, minor: 11, patch: 0))
        XCTAssertEqual(gate.check(tl), .updateRequired)
    }

    // MARK: - Decision enum coverage

    func testDecisionIsOkNotUpdateRequired() {
        XCTAssertNotEqual(SchemaCompatibilityDecision.ok, .updateRequired)
    }
}
