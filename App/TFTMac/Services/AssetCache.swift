import Foundation
import os
import CryptoKit

/// On-disk asset cache backed by URLSession.
///
/// Strategy: SHA-256 of URL → filename in `directory`. Disk hit returns immediately;
/// miss triggers fetch + persist. 30-day TTL via file mtime check. 50MB ceiling
/// enforced lazily on each write (LRU eviction by mtime).
///
/// Returns nil on 4xx/5xx/timeout — callers fall back to placeholder UI.
final class AssetCache {
    static let shared = AssetCache(
        directory: FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("io.psychomafia.tfthellelo.assets")
    )

    private let directory: URL
    private let session: URLSession
    private let logger = Logger(subsystem: "io.psychomafia.tfthellelo", category: "AssetCache")
    private let ttl: TimeInterval = 30 * 24 * 3600
    private let maxBytes: Int = 50 * 1024 * 1024

    init(directory: URL, session: URLSession = .shared) {
        self.directory = directory
        self.session = session
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func data(for url: URL) async throws -> Data? {
        let path = cachePath(for: url)
        if let cached = readFromDisk(path: path) { return cached }

        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                logger.notice("asset miss \(url.absoluteString, privacy: .public): non-200")
                return nil
            }
            try? data.write(to: path)
            evictIfNeeded()
            return data
        } catch {
            logger.notice("asset fetch failed \(url.absoluteString, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private func cachePath(for url: URL) -> URL {
        let hash = url.absoluteString.data(using: .utf8)!.sha256Hex()
        return directory.appendingPathComponent(hash)
    }

    private func readFromDisk(path: URL) -> Data? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path.path),
              let mtime = attrs[.modificationDate] as? Date,
              Date().timeIntervalSince(mtime) < ttl else {
            return nil
        }
        return try? Data(contentsOf: path)
    }

    private func evictIfNeeded() {
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey]
        ) else { return }
        var totalBytes = 0
        var withMeta: [(URL, Int, Date)] = []
        for u in entries {
            let v = try? u.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            let size = v?.fileSize ?? 0
            let mtime = v?.contentModificationDate ?? .distantPast
            totalBytes += size
            withMeta.append((u, size, mtime))
        }
        guard totalBytes > maxBytes else { return }
        let sorted = withMeta.sorted { $0.2 < $1.2 }
        var bytes = totalBytes
        for (u, size, _) in sorted where bytes > maxBytes {
            try? FileManager.default.removeItem(at: u)
            bytes -= size
        }
    }
}

private extension Data {
    func sha256Hex() -> String {
        SHA256.hash(data: self).map { String(format: "%02x", $0) }.joined()
    }
}
