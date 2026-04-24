import Foundation

/// Menu bar icon visual state machine.
///
/// Phase 1 scope (eng review decision #1): `.default` only. Data is
/// bundled into the app binary in v0.1 so no loading/error/stale states
/// are reachable yet — there's no fetch to be pending, no cache to go
/// stale, no network to fail.
///
/// Phase 2 will expand when R2 fetch + cache land:
/// - `.loading`   — pulsing icon while fetch in-flight
/// - `.error`     — red 6x6 badge when fetch fails AND no cache fallback
/// - `.stale`     — yellow 6x6 badge when cache >24h old
/// - `.cacheOnly` — grayed icon when offline but cache present
///
/// See `docs/product-spec-v0.1.md` §Feature 3 for visual spec per state.
enum IconState {
    case `default`
    // Phase 2: .loading, .error, .stale, .cacheOnly (eng review decision #1)
}
