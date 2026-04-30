import XCTest
@testable import TFTMac

final class AssetCacheTests: XCTestCase {

    func test_returnsNilForUnreachableURL() async throws {
        let cache = AssetCache(directory: FileManager.default.temporaryDirectory.appendingPathComponent("ac-test-\(UUID())"))
        let url = URL(string: "https://raw.communitydragon.org/latest/game/assets/characters/tft17_doesnotexist/hud/tft17_doesnotexist_square.tft_set17.png")!
        let data = try await cache.data(for: url)
        XCTAssertNil(data)
    }

    func test_diskCachePersistsAcrossInstances() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("ac-test-\(UUID())")
        let url = URL(string: "https://raw.communitydragon.org/latest/game/assets/characters/tft17_aatrox/hud/tft17_aatrox_square.tft_set17.png")!

        let first = AssetCache(directory: dir)
        let firstData = try await first.data(for: url)
        try XCTSkipIf(firstData == nil, "network unavailable — skipping")

        let second = AssetCache(directory: dir)
        let secondData = try await second.data(for: url)
        XCTAssertEqual(firstData?.count, secondData?.count)
    }
}
