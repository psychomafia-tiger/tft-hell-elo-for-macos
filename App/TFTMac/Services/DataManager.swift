import Foundation
import Combine

// MARK: - BannerState

/// UI state communicated from DataManager to the banner slot in CompListView.
///
/// Concrete meanings:
///   .fresh           → no banner shown (data is current)
///   .lastUpdated(3)  → "Last updated 3h ago" subtle grey bar
///   .staleData(2)    → "Stale data — last updated 2d ago" amber bar
///   .offlineBundled  → "Offline mode — using bundled data" orange bar
///   .updateRequired  → full-screen overlay, comps NOT rendered
enum BannerState: Equatable {
    case fresh
    case lastUpdated(hoursAgo: Int)
    case staleData(daysAgo: Int)
    case offlineBundled
    case updateRequired
}

// MARK: - DataManager

/// Central data source for the TFT Hell Elo app.
///
/// Lifecycle: instantiated as `@StateObject` in TFTMacApp. `start()` is called
/// in `init()` for immediate launch fetch — `.onAppear` is unreliable for
/// MenuBarExtra(.window) because the window may not appear until first hotkey.
///
/// Fetch chain (refresh):
///   RemoteFetcher.fetch → SchemaGate.check
///     .ok          → DiskCache.write + publish + bannerState = .fresh
///     .updateRequired → bannerState = .updateRequired (don't publish bad data)
///   on failure:
///     DiskCache.read
///       < 24h old  → publish + .lastUpdated(h)
///       24h – 7d   → publish + .staleData(d)
///       > 7d / missing → bundled fallback + .offlineBundled
///
/// Concurrent refresh guard: if a refresh Task is already running when Timer
/// fires, the in-flight Task is cancelled and a new one starts. Rationale:
/// Timer can fire on wake right after a launch fetch — we prefer fresh data.
///
/// `loadBundledJSON()` is kept as a static method for backward compatibility
/// with existing `DataManagerTests` (which call it directly).
@MainActor
final class DataManager: ObservableObject {

    // MARK: - Published state

    @Published private(set) var tierList: TierList
    @Published private(set) var bannerState: BannerState = .fresh

    // MARK: - Private dependencies

    private let fetcher: RemoteFetcher
    private let cache: DiskCache
    private let schemaGate: SchemaCompatibilityGate
    private var refreshTimer: Timer?
    private var refreshTask: Task<Void, Never>?

    // MARK: - Constants

    private static let remoteURL = RemoteFetcher.productionURL
    private static let freshThresholdSeconds: TimeInterval = 24 * 60 * 60       // 24h
    private static let staleThresholdSeconds: TimeInterval = 7 * 24 * 60 * 60   // 7d
    private static let pollInterval: TimeInterval = 12 * 60 * 60                 // 12h

    // MARK: - Init / Deinit

    init(
        fetcher: RemoteFetcher = RemoteFetcher(),
        cache: DiskCache = DiskCache(),
        schemaGate: SchemaCompatibilityGate = SchemaCompatibilityGate()
    ) {
        self.fetcher = fetcher
        self.cache = cache
        self.schemaGate = schemaGate
        // Synchronous bundled load guarantees app shows SOMETHING immediately,
        // even if all async paths fail. Decode is <10ms on M1.
        self.tierList = DataManager.loadBundledJSON()
        start()
    }

    deinit {
        // Inline cleanup — calling @MainActor stop() from nonisolated deinit
        // is illegal. Timer.invalidate() and Task.cancel() are thread-safe.
        refreshTimer?.invalidate()
        refreshTask?.cancel()
    }

    // MARK: - Lifecycle

    /// Kick off launch fetch + schedule 12h background poll.
    /// Called in `init()` — do not call again externally.
    private func start() {
        // Immediate launch fetch
        scheduleRefresh()

        // 12h background Timer — always fires, no idle skip
        // (12h × 50KB = trivial battery; idle detection adds edge cases: KISS)
        refreshTimer = Timer.scheduledTimer(
            withTimeInterval: Self.pollInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.scheduleRefresh()
            }
        }
    }

    /// Invalidate Timer and cancel in-flight Task. Called in `deinit`.
    func stop() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        refreshTask?.cancel()
        refreshTask = nil
    }

    // MARK: - Refresh scheduling

    /// Cancels any in-flight refresh and starts a new one.
    /// Safe to call from Timer fire or future manual-refresh trigger.
    func scheduleRefresh() {
        refreshTask?.cancel()
        refreshTask = Task {
            await refresh()
        }
    }

    // MARK: - Fetch chain

    /// Full fetch chain: remote → cache (fresh) → cache (stale) → bundled.
    /// Must run on MainActor (called via `Task { @MainActor in ... }`).
    private func refresh() async {
        guard !Task.isCancelled else { return }

        // --- Attempt remote fetch ---
        if let remoteData = await attemptRemoteFetch() {
            // Decode and schema-check remote data
            if let decoded = decode(remoteData) {
                switch schemaGate.check(decoded) {
                case .ok:
                    try? cache.write(remoteData)
                    tierList = decoded
                    bannerState = .fresh
                    return
                case .updateRequired:
                    bannerState = .updateRequired
                    return
                }
            }
            // Remote data decoded but gate rejected — fall through to cache
        }

        guard !Task.isCancelled else { return }

        // --- Remote failed: try disk cache ---
        if let (cachedData, mtime) = tryReadCache() {
            if let decoded = decode(cachedData) {
                // Check schema on cached data too
                if schemaGate.check(decoded) == .updateRequired {
                    bannerState = .updateRequired
                    return
                }
                let ageSeconds = Date().timeIntervalSince(mtime)
                if ageSeconds < Self.freshThresholdSeconds {
                    let hoursAgo = Int(ageSeconds / 3600)
                    tierList = decoded
                    bannerState = .lastUpdated(hoursAgo: hoursAgo)
                    return
                } else if ageSeconds < Self.staleThresholdSeconds {
                    let daysAgo = Int(ageSeconds / 86400)
                    tierList = decoded
                    bannerState = .staleData(daysAgo: daysAgo)
                    return
                }
                // Cache > 7d — fall through to bundled
            }
        }

        guard !Task.isCancelled else { return }

        // --- All remote/cache paths failed: bundled fallback ---
        tierList = DataManager.loadBundledJSON()
        bannerState = .offlineBundled
    }

    // MARK: - Helpers

    private func attemptRemoteFetch() async -> Data? {
        do {
            return try await fetcher.fetch(url: Self.remoteURL)
        } catch {
            return nil
        }
    }

    private func tryReadCache() -> (Data, Date)? {
        do {
            return try cache.read()
        } catch {
            return nil
        }
    }

    private func decode(_ data: Data) -> TierList? {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(TierList.self, from: data)
    }

    // MARK: - Bundled JSON (static — backward compat with DataManagerTests)

    /// Decodes the bundled `sample-tier-list.json` resource.
    ///
    /// `fatalError` on missing resource because a missing fixture means the
    /// app shipped broken — the build itself is the safeguard, not runtime catch.
    static func loadBundledJSON(bundle: Bundle = .main) -> TierList {
        guard let url = bundle.url(forResource: "sample-tier-list", withExtension: "json") else {
            fatalError("sample-tier-list.json missing from app bundle — check project.yml resources block")
        }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(TierList.self, from: data)
        } catch {
            fatalError("Failed to decode sample-tier-list.json: \(error)")
        }
    }
}
