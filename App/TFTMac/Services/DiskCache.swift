import Foundation

/// File-backed cache for the remote tier-list JSON.
///
/// Cache location: `~/Library/Caches/io.psychomafia.tfthellelo/tier-list.json`
/// Standard macOS Caches — system may evict under memory pressure, which is
/// fine: re-fetch on next launch covers the miss.
///
/// Atomic write: uses `.atomic` write option so a crash mid-write leaves the
/// previous valid file intact (no partial-JSON corruption). On read failure
/// the fallback chain degrades to bundled data, never crashes.
///
/// Concrete age thresholds:
///   <24h  → fresh (show "Last updated Xh ago" subtle banner only)
///   24h–7d → stale (show prominent "Stale data" banner)
///   >7d   → treat as missing (bundled fallback)
struct DiskCache {

    // MARK: - Cache location

    private static let cacheDir: URL = {
        let base = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)
            .first!
        return base.appendingPathComponent("io.psychomafia.tfthellelo", isDirectory: true)
    }()

    static let cacheFileURL: URL = cacheDir
        .appendingPathComponent("tier-list.json")

    // MARK: - Errors

    enum CacheError: Error {
        case fileNotFound
        case unreadable(underlying: Error)
    }

    // MARK: - Read

    /// Returns cached data + file modification date.
    /// Throws `CacheError.fileNotFound` if cache absent,
    /// `CacheError.unreadable` on any other read failure.
    func read() throws -> (data: Data, modificationDate: Date) {
        let url = Self.cacheFileURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw CacheError.fileNotFound
        }
        do {
            let data = try Data(contentsOf: url)
            let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
            let mtime = (attrs[.modificationDate] as? Date) ?? Date(timeIntervalSince1970: 0)
            return (data, mtime)
        } catch {
            throw CacheError.unreadable(underlying: error)
        }
    }

    // MARK: - Write

    /// Atomically writes `data` to the cache file.
    /// Creates the cache directory if missing.
    func write(_ data: Data) throws {
        let dir = Self.cacheDir
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(
                at: dir,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
        // .atomic: writes to a temp file first, then renames → crash-safe
        try data.write(to: Self.cacheFileURL, options: .atomic)
    }

    // MARK: - Purge

    /// Removes the cache file. Used in tests; not called in production flow.
    func purge() throws {
        let url = Self.cacheFileURL
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }
}
