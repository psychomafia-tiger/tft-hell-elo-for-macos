import Foundation

/// Async actor that fetches raw JSON data from a remote URL.
///
/// `actor` isolation prevents data races when multiple callers trigger
/// concurrent fetches (e.g., launch fetch + Timer fire racing on wake).
///
/// Fetch budget (concrete numbers):
///   ~50KB JSON gzipped over home network ≈ 200ms
///   URLSession default timeout = 60s (too lenient) → we use 10s
///   Single retry on transient failure with 3s delay → total worst-case = 23s
///   Then propagate error so caller falls back to DiskCache
///
/// GitHub raw URL rate limit: 60 req/hr unauthenticated.
/// App fetches twice/day × ~10 users = 20 req/day = safely within limit.
actor RemoteFetcher {

    // MARK: - Errors

    enum FetchError: Error {
        case httpError(statusCode: Int)
        case emptyResponse
        case networkError(underlying: Error)
    }

    // MARK: - Configuration

    /// Live URL for production fetches.
    static let productionURL = URL(
        string: "https://raw.githubusercontent.com/psychomafia-tiger/tft-hell-elo-for-macos/main/data/tier-list.json"
    )!

    private let session: URLSession

    init(session: URLSession = .makeTierListSession()) {
        self.session = session
    }

    // MARK: - Fetch

    /// Fetches data from `url` with one retry on transient failure.
    ///
    /// Retry policy: any thrown error on first attempt → wait 3s → retry once.
    /// Second failure propagates to caller (DataManager falls back to DiskCache).
    ///
    /// - Parameter url: target URL (injectable for tests via URLProtocol mock)
    /// - Returns: raw response `Data`
    /// - Throws: `FetchError` on HTTP error or persistent network failure
    func fetch(url: URL) async throws -> Data {
        do {
            return try await performRequest(url: url)
        } catch {
            // Single retry after 3s delay for transient failures
            try await Task.sleep(nanoseconds: 3_000_000_000)
            return try await performRequest(url: url)
        }
    }

    // MARK: - Private

    private func performRequest(url: URL) async throws -> Data {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            throw FetchError.networkError(underlying: error)
        }

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw FetchError.httpError(statusCode: http.statusCode)
        }

        guard !data.isEmpty else {
            throw FetchError.emptyResponse
        }

        return data
    }
}

// MARK: - URLSession factory

extension URLSession {
    /// Creates a URLSession configured for tier-list fetches:
    /// 10s timeout (fail fast so fallback chain kicks in quickly),
    /// ATS-enforced HTTPS via `.default` configuration.
    static func makeTierListSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 10
        return URLSession(configuration: config)
    }
}
