import XCTest
@testable import TFTMac

final class SchemaVersionTests: XCTestCase {
    // appSchemaVersion is the schema version the app was built against (v0.1 = 1.0.0).
    private let appSchemaVersion = SchemaVersion(major: 1, minor: 0, patch: 0)

    func testAcceptsExactMatch() {
        let data = SchemaVersion(major: 1, minor: 0, patch: 0)
        XCTAssertTrue(appSchemaVersion.isCompatible(with: data))
    }

    func testAcceptsMinorForwardWithinWindow() {
        let data = SchemaVersion(major: 1, minor: 1, patch: 0)
        XCTAssertTrue(appSchemaVersion.isCompatible(with: data),
                      "App 1.0.0 should accept data 1.1.0 (minor forward within 10-window)")
    }

    func testAcceptsTenMinorForward() {
        let data = SchemaVersion(major: 1, minor: 10, patch: 0)
        XCTAssertTrue(appSchemaVersion.isCompatible(with: data),
                      "App 1.0.0 should accept data 1.10.0 (exactly at 10-minor boundary)")
    }

    func testRejectsMajorBump() {
        let data = SchemaVersion(major: 2, minor: 0, patch: 0)
        XCTAssertFalse(appSchemaVersion.isCompatible(with: data),
                       "App 1.0.0 should reject data 2.0.0 (major breaking change)")
    }

    func testRejectsBeyondTenMinorWindow() {
        let data = SchemaVersion(major: 1, minor: 11, patch: 0)
        XCTAssertFalse(appSchemaVersion.isCompatible(with: data),
                       "App 1.0.0 should reject data 1.11.0 (beyond 10-minor forward window)")
    }

    // Bonus: backward data rejection — app 1.0.0 reading data 0.9.0
    func testRejectsBackwardMinor() {
        let data = SchemaVersion(major: 1, minor: 0, patch: 0)
        let newerApp = SchemaVersion(major: 1, minor: 5, patch: 0)
        XCTAssertFalse(newerApp.isCompatible(with: data),
                       "App 1.5.0 should reject data 1.0.0 (data too old, may be missing fields)")
    }

    // Bonus: string init happy path
    func testInitFromValidString() {
        let version = SchemaVersion(string: "1.2.3")
        XCTAssertNotNil(version)
        XCTAssertEqual(version?.major, 1)
        XCTAssertEqual(version?.minor, 2)
        XCTAssertEqual(version?.patch, 3)
    }

    // Bonus: malformed string returns nil (no crash)
    func testInitFromMalformedStringReturnsNil() {
        XCTAssertNil(SchemaVersion(string: "not-a-version"))
        XCTAssertNil(SchemaVersion(string: "1.2"))
        XCTAssertNil(SchemaVersion(string: ""))
    }
}
