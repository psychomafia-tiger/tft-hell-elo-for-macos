# Phase 03 — App network fetch + 12h background poll + anomaly UI

## Context Links

- Existing: `App/TFTMac/Services/DataManager.swift` (current bundled-only stub)
- Existing models: `App/TFTMac/Models/{TierList,Comp,Champion,SchemaVersion}.swift`
- Existing UI: `App/TFTMac/Views/{CompCard,CompCardItemsRow}.swift`
- Output URL (after Phase 02): `https://raw.githubusercontent.com/psychomafia-tiger/tft-hell-elo-for-macos/main/data/tier-list.json`

## Overview

- **Priority**: P1 (app-side completion of pipeline; user-visible)
- **Status**: pending
- **Effort**: **5h** (bumped from 3h post code-reviewer audit C1; existing `DataManager` is `enum` static at line 18 — rewrite to `@MainActor ObservableObject` cascades to 6 files: TFTMacApp, OverlayWindowController, TierListPopover, DataManagerTests + 2 dependent test files. Plus MenuBarExtra lifecycle hook fix from step 10.)
- **Description**: Replace bundled-only DataManager with full fetch chain: remote → cache (fresh) → cache (stale + banner) → bundled fallback. Add 12h background poll. Add anomaly chip row to CompCard. Add schema-version compatibility gate.

## Key Insights

1. **Existing model already supports schema versioning**: `SchemaVersion.isCompatible(with:)` is built and tested. We wire it into the fetch path; we don't redesign.

2. **Existing fallback architecture documented in DataManager comments** (lines 6-9): "R2 fetch (fresh) → cache (fresh) → cache (stale with banner) → reject cache >7d → schema version mismatch guard". Plan was already written in. We implement, but swap "R2 fetch" for "GitHub raw URL fetch" (simpler — no S3 setup needed for v0.1).

3. **Cache location decision**: `~/Library/Caches/io.psychomafia.tfthellelo/tier-list.json`. Standard macOS Caches location. System may evict but that's OK — we re-fetch on miss.

4. **MainActor + URLSession (concrete pattern)**:
   - `RemoteFetcher` is an `actor` (data-race safety) that performs URLSession async fetch.
   - `DataManager` `@MainActor` consumes RemoteFetcher results and publishes `@Published var tierList`.
   - 12h Timer scheduled on RunLoop.main; on fire, dispatches Task to RemoteFetcher.

5. **Fetch budget (concrete numbers)**:
   - 50KB JSON gzipped over typical home network = ~200ms.
   - URLSession default timeout 60s — way too lenient. We use 10s (responsive failure).
   - Background poll every 12h × 365 = 730 fetches/year × 50KB = 36.5MB/year. Negligible.

6. **Anomaly UI rendering**: 3 chip pattern matching `CompCardItemsRow` pattern (DRY). Each chip = small rounded rect with anomaly icon placeholder + agreement %.

## Requirements

### Functional

- [F1] On app launch, attempt remote fetch. Cache result.
- [F2] If remote fails (network/HTTP/timeout), use cached data if fresh (<24h old) — show "Last updated Xh ago" subtle banner.
- [F3] If cached data stale (24h-7d), use it but show "Stale data — last updated Xd ago" prominent banner.
- [F4] If cached data >7d old OR missing, fall back to bundled `sample-tier-list.json`. Show "Offline mode — using bundled data" banner.
- [F5] Schema-version gate: if remote/cached data has `schema_version` major != app's, show "Update Required" full-screen overlay (do NOT render comps from incompatible data).
- [F6] Background Timer fires every 12h while app running; performs same fetch chain.
- [F7] On fetch success, replace `@Published var tierList` on MainActor; SwiftUI re-renders.
- [F8] User-triggerable manual refresh (e.g. via menu bar dropdown OR keyboard shortcut). Out of scope for v0.1 minimum, but architecture allows trivial hookup.
- [F9] Anomaly chip row renders in `CompCardV2` between items row and divider; max 3 chips, each shows anomaly name (truncated) + agreement %.

### Non-functional
- [NF1] Fetch attempt timeout 10s; total fetch chain (incl. cache fallback) <500ms p99 (cache reads are local disk).
- [NF2] No network calls on hot path of UI render — all fetch async via Task.
- [NF3] Memory: hold one TierList copy in DataManager; release prior copy on update.
- [NF4] Disk: cache file <100KB. No log files written by app.
- [NF5] Battery: background poll uses URLSessionConfiguration.default (system manages). No GPS, no continuous network.
- [NF6] Anomaly chip row LOC <100. Row only rendered if `comp.anomalies` non-empty.

## Architecture

### Components

```
DataManager (@MainActor, ObservableObject)
  ├── @Published var tierList: TierList
  ├── @Published var bannerState: BannerState  (offline / stale / update-required / nil)
  ├── private let fetcher: RemoteFetcher
  ├── private let cache: DiskCache
  ├── private let schemaGate: SchemaCompatibilityGate
  ├── private var refreshTimer: Timer?
  ├── start() — kick off launch fetch + schedule 12h Timer
  ├── refresh() async — fetch chain
  └── stop() — invalidate Timer (cleanup on app quit)

RemoteFetcher (actor)
  ├── fetch(url: URL) async throws -> Data
  └── 10s timeout; URLSessionConfiguration.default

DiskCache (struct, file-backed)
  ├── url = ~/Library/Caches/io.psychomafia.tfthellelo/tier-list.json
  ├── read() throws -> (Data, Date)  // returns content + mtime
  ├── write(Data) throws
  └── purge() throws

SchemaCompatibilityGate (struct)
  ├── appSchema = SchemaVersion(major: 1, minor: 1, patch: 0)
  └── check(_ data: TierList) -> .ok | .updateRequired

BannerState (enum)
  ├── case fresh                          (no banner)
  ├── case lastUpdated(hoursAgo: Int)     ("Last updated 3h ago")
  ├── case staleData(daysAgo: Int)        ("Stale data — last updated 2d ago")
  ├── case offlineBundled                 ("Offline mode — bundled data")
  └── case updateRequired                 (full-screen overlay)
```

### Fetch chain decision flow

```
                   refresh()
                       │
                       ▼
              [RemoteFetcher.fetch]
                       │
            ┌──────────┴──────────┐
       success                  failure
            │                      │
            ▼                      ▼
    [SchemaGate.check]      [DiskCache.read]
            │                      │
       ┌────┴────┐            ┌────┴────┐
      ok    updateRequired  exists    no cache
       │         │            │           │
       │         │      [age check]       │
       │         │       │       │        │
       ▼         ▼       ▼       ▼        ▼
   [cache.    show     <24h    24-7d     [bundled]
    write]    overlay   │        │           │
       │                ▼        ▼           ▼
       ▼          [decode +   [decode +   [decode +
   [publish     show last-  show stale   show offline
    fresh]      updated]    banner]      banner]
```

### Background poll (Timer)

```swift
self.refreshTimer = Timer.scheduledTimer(
    withTimeInterval: 12 * 60 * 60, // 12h
    repeats: true
) { [weak self] _ in
    Task { @MainActor in await self?.refresh() }
}
```

Decision: **always fetch on Timer fire, no idle-skip**. Justification (from plan.md):
- 12h × 50KB = trivial battery/network impact.
- Idle detection adds NSAppearance/NSWorkspace observers, edge cases (sleep/wake/lid close) — KISS violated for negligible savings.
- Worst case (laptop closed): Timer pauses with system sleep, fires on wake. Acceptable.

### Anomaly UI — `CompCardAnomaliesRow.swift`

```swift
struct CompCardAnomaliesRow: View {
    let anomalies: [Anomaly]  // already filtered top-3 in pipeline

    var body: some View {
        if anomalies.isEmpty {
            EmptyView()
        } else {
            HStack(spacing: 6) {
                ForEach(anomalies, id: \.id) { anomaly in
                    AnomalyChip(anomaly: anomaly)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

struct AnomalyChip: View {
    let anomaly: Anomaly

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "sparkles")
                .font(.system(size: 10))
                .foregroundStyle(Theme.Colors.accentGold)
            Text(displayName)
                .font(Theme.Fonts.caption)
                .lineLimit(1)
            Text("\(Int(anomaly.agreement * 100))%")
                .font(Theme.Fonts.caption.weight(.semibold))
                .foregroundStyle(Theme.Colors.textMuted)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Theme.Colors.bgChip)
        .clipShape(Capsule())
    }

    private var displayName: String {
        // "TFT17_EkkoOffering_AnomalyItem" → "Anomaly Item"
        // Strip prefix, split CamelCase → space.
        // Falls back to raw id if format unexpected.
        ...
    }
}
```

Insertion point in `CompCardV2.body`:
```swift
VStack(alignment: .leading, spacing: 8) {
    topRow
    championsRow
    CompCardItemsRow(comp: comp)
    CompCardAnomaliesRow(anomalies: comp.anomalies)  // NEW
    if isExpanded { ... }
}
```

If `bgChip` color not in Theme — add it (small Theme.swift edit). Reuse existing if present.

### Schema model additions

`App/TFTMac/Models/Anomaly.swift` (NEW):
```swift
struct Anomaly: Codable {
    let id: String          // "TFT17_EkkoOffering_AnomalyItem"
    let agreement: Double   // 0.40 - 1.0
}
```

`App/TFTMac/Models/Comp.swift` MODIFY:
```swift
struct Comp: Codable {
    let compId: String
    let name: String
    let tier: Tier
    let playRate: Double
    let avgPlacement: Double
    let top4Rate: Double
    let sampleSize: Int
    let champions: [Champion]
    let anomalies: [Anomaly]   // NEW — populated when present, defaults to [] via decodeIfPresent
}
```

**Forward-compat decoding (C2 fix from code-reviewer audit, anh chốt 2026-04-25)**: Custom `init(from:)` uses `decodeIfPresent ?? []` — old JSON v1.0.0 (no `anomalies` key) decodes to empty array. New JSON v1.1.0 decodes populated:

```swift
extension Comp: Decodable {
    enum CodingKeys: String, CodingKey {
        case compId, name, tier, playRate, avgPlacement, top4Rate, sampleSize, champions, anomalies
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.compId = try c.decode(String.self, forKey: .compId)
        self.name = try c.decode(String.self, forKey: .name)
        self.tier = try c.decode(Tier.self, forKey: .tier)
        self.playRate = try c.decode(Double.self, forKey: .playRate)
        self.avgPlacement = try c.decode(Double.self, forKey: .avgPlacement)
        self.top4Rate = try c.decode(Double.self, forKey: .top4Rate)
        self.sampleSize = try c.decode(Int.self, forKey: .sampleSize)
        self.champions = try c.decode([Champion].self, forKey: .champions)
        self.anomalies = (try? c.decodeIfPresent([Anomaly].self, forKey: .anomalies)) ?? []
    }
}
```

**Bundled JSON STAYS at schema 1.0.0** (do NOT bump in this phase). Schema 1.1.0 lives only in remote-fetched JSON. Rationale:
- Existing tests `TierListDecodingTests` + `DataManagerTests` (asserts schema 1.0.0) pass without modification
- Rollback stays clean: revert phase-03 → bundled JSON unchanged, app degrades to pre-pipeline behavior
- Forward-compat decoder handles BOTH old (no anomalies key) and new (with anomalies array) JSON

**Implementation Steps update**: step 2 below previously said "Bump bundled to 1.1.0" — IGNORE that. Bundled stays at 1.0.0. See updated Step 2 wording.

`App/TFTMac/Models/TierList.swift` MODIFY:
- Add `region: String` field (additive, present in pipeline emit).
- App schema bump: `SchemaCompatibilityGate.appSchema = SchemaVersion(major: 1, minor: 1, patch: 0)`.

## Related Code Files

### Create
- `App/TFTMac/Services/RemoteFetcher.swift` (~80 LOC)
- `App/TFTMac/Services/DiskCache.swift` (~70 LOC)
- `App/TFTMac/Services/SchemaCompatibilityGate.swift` (~40 LOC)
- `App/TFTMac/Models/Anomaly.swift` (~15 LOC)
- `App/TFTMac/Views/CompCardAnomaliesRow.swift` (~80 LOC, includes AnomalyChip)
- `App/TFTMac/Views/UpdateRequiredOverlay.swift` (~60 LOC) — full-screen takeover for schema gate failure

### Modify
- `App/TFTMac/Services/DataManager.swift` — full rewrite (~150 LOC; was 39 LOC stub)
- `App/TFTMac/Models/Comp.swift` — add `anomalies` field
- `App/TFTMac/Models/TierList.swift` — add `region` field, expand decoder
- `App/TFTMac/Views/CompCard.swift` — insert `CompCardAnomaliesRow` line
- `App/TFTMac/Views/HeaderBar.swift` (or `Banners.swift`) — render BannerState (depending on which view owns banner area; verify in implementation)
- `App/TFTMac/TFTMacApp.swift` — wire DataManager.start() on app launch, .stop() on quit
- `App/TFTMac/Resources/sample-tier-list.json` — UNCHANGED per C2 fix (stays at schema 1.0.0). Forward-compat decoder handles missing `anomalies` field by defaulting to `[]`.

### Delete
- None.

## Implementation Steps

1. **Add Anomaly model** + Comp/TierList field updates. Run Swift compile check (`swift build` or Xcode build) — catch decoder mismatches early.

2. **Bundled `sample-tier-list.json` UNCHANGED** (C2 fix — stays at schema 1.0.0):
   - Forward-compat decoder reads bundled v1.0.0 (no anomalies key) → empty array
   - Forward-compat decoder reads remote v1.1.0 (with anomalies) → populated array
   - For UI smoke test of anomaly chips during dev, add inline test fixture in `CompCardAnomaliesRow_Previews` SwiftUI preview ONLY, NOT in shipped JSON
   - Existing tests `TierListDecodingTests` + `DataManagerTests` (asserts schema 1.0.0) require zero modification
   - Skip this step if bundled JSON already schema 1.0.0 (which it is)

3. **Create `SchemaCompatibilityGate.swift`**:
   - Defines `appSchema = SchemaVersion(major: 1, minor: 1, patch: 0)`.
   - `check(_ tierList: TierList) -> Decision` returns `.ok` or `.updateRequired`.
   - Pure logic, easy unit-test.

4. **Create `DiskCache.swift`**:
   - URL: `FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first! + "io.psychomafia.tfthellelo/tier-list.json"`.
   - Create dir if missing.
   - `read()` returns (data, mtime); throws if file missing.
   - `write(data)` atomic write.

5. **Create `RemoteFetcher.swift`**:
   - `actor` for thread-safety.
   - `fetch(url:) async throws -> Data` with `URLSessionConfiguration.default`, 10s timeout.
   - Single retry on transient failure (3s delay), then propagate error.

6. **Rewrite `DataManager.swift`**:
   - `@MainActor`, `ObservableObject`.
   - `@Published var tierList: TierList` (initialize with bundled JSON synchronously — guarantees app shows SOMETHING on launch even if all async paths fail).
   - `@Published var bannerState: BannerState`.
   - `start()` schedules Timer + kicks first refresh Task.
   - `refresh() async` — fetch chain per architecture flow.
   - `stop()` invalidates Timer.

7. **Create `UpdateRequiredOverlay.swift`** — simple full-window overlay shown when `bannerState == .updateRequired`. Text: "Update Required — TFT Hell Elo data is newer than this app version. Please download the latest .dmg from GitHub Releases."

8. **Wire banner display**: identify whether HeaderBar.swift or Banners.swift currently owns banner area; insert `BannerView(state: dataManager.bannerState)` there.

9. **Wire `CompCardAnomaliesRow`** into `CompCardV2.body` (1-line insertion).

10. **Wire DataManager into App** (C1 fix — app uses `MenuBarExtra(.window)`, NOT `WindowGroup`):
    - `TFTMacApp.swift` instantiates `@StateObject var dataManager = DataManager()`
    - `.start()` called in `DataManager.init()` — immediate fetch on app launch (`.onAppear` unreliable for hotkey-only triggers since menu bar window may not have appeared)
    - `.stop()` in `deinit` — cleanup Timer when DataManager deallocated; app quit triggers naturally
    - `MenuBarExtra(.window)` lifecycle: window content reuses across hotkey toggles; no per-toggle `.onAppear` fire
    - Manual refresh (future): wire to hotkey toggle event via shared notification or environment object

11. **Build + run** in Xcode. Verify:
    - Bundled load works on launch (offline test: turn off Wi-Fi).
    - Online: fetches `data/tier-list.json` from raw GitHub URL (set URL constant; flag for prod-vs-dev).
    - Anomaly chips render below items row.
    - Schema mismatch overlay: temporarily edit DiskCache file to `"schema_version":"2.0.0"`, restart app, verify overlay shows.

## Todo List

- [ ] Add `Anomaly.swift` model
- [ ] Modify `Comp.swift` to include `anomalies`
- [ ] Modify `TierList.swift` to include `region`
- [x] Bundled `sample-tier-list.json` STAYS at 1.0.0 (C2 fix — no action needed; forward-compat decoder handles)
- [ ] Create `SchemaCompatibilityGate.swift`
- [ ] Create `DiskCache.swift`
- [ ] Create `RemoteFetcher.swift` actor
- [ ] Rewrite `DataManager.swift` with full fetch chain + 12h Timer
- [ ] Create `CompCardAnomaliesRow.swift` (with AnomalyChip subview)
- [ ] Create `UpdateRequiredOverlay.swift`
- [ ] Insert anomalies row in `CompCardV2.body`
- [ ] Wire banner state into HeaderBar/Banners view
- [ ] Wire DataManager into TFTMacApp lifecycle (start/stop)
- [ ] Build app — zero compile errors
- [ ] Manual offline test (Wi-Fi off → bundled fallback + offline banner)
- [ ] Manual online test (Wi-Fi on → remote fetch + chips render)
- [ ] Manual schema-mismatch test (edit cache to 2.0.0 → overlay)

## Success Criteria

- [ ] App launches, fetches remote `tier-list.json` within 10s, decodes successfully, renders comps with anomaly chips
- [ ] Wi-Fi off → app shows bundled data + "Offline mode" banner; no crash
- [ ] Cached data simulated 25h old → app shows cache + "Last updated 25h ago" banner
- [ ] Cached data simulated 8d old → app falls back to bundled + "Offline mode" banner
- [ ] Schema 2.0.0 in cache → "Update Required" overlay displays, comps not rendered from bad data
- [ ] 12h Timer scheduled (verify with debug log on fire OR force-fire via `refreshTimer.fire()` in debugger)
- [ ] `swift build` / Xcode build clean
- [ ] No memory leaks (instruments quick scan: 1 TierList instance held, prior released on update)

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| URLSession timeout 10s too aggressive on slow network | Med | Med | Timeout = abort fetch only, fallback chain still serves cache/bundled. User sees stale banner, not crash. |
| GitHub raw URL rate-limited (60 req/hr unauth) | Low | Med | App fetches twice/day per user. 1000 users = 2000/day = 83/hr max — within unauth limit. Won't hit at v0.1 (founder + ~10 testers eventually). |
| Anomaly displayName parser fails on unexpected ID format | Low | Low | Fallback to raw ID if parse fails. Test with known IDs + 1 malformed. |
| Cache file corrupted (partial write on crash) | Low | Med | DiskCache.write uses atomic write (`.atomic` flag). Read errors → cache treated as missing → bundled fallback. |
| Background Timer not firing when app idle in background | Low | Low | macOS preserves Timers when app windowed (not suspended). User only loses 12h Timer if app quit, which is fine — relaunch triggers fetch. |
| Anomaly chip row breaks card height layout | Low | Low | Empty arrays render `EmptyView()` — zero height. Pre-merge visual check in popover + overlay both. |
| Schema 1.0.0 cached data rejected after app upgrade to 1.1.0 | Med | Low | App schema 1.1.0 + minor>=app.minor rule means 1.0.0 cache (minor 0) < app minor 1 → REJECTED → re-fetches remote (which is 1.1.0). Edge case lasts one fetch cycle. Acceptable. |
| Concurrent refresh races (launch + Timer fire ~ same time) | Very Low | Low | DataManager guards with `private var refreshTask: Task?`; cancel pending Task before new fetch. |

## Security Considerations

- **TLS**: URLSession default config = ATS-enforced TLS. raw.githubusercontent.com is HTTPS-only.
- **No auth tokens in app**: app fetches PUBLIC raw URL — zero credentials in client. Riot key never reaches end-user app.
- **Cache permissions**: `~/Library/Caches/...` is user-scoped; standard macOS sandbox if app sandboxed (per existing entitlements file).
- **Schema gate prevents code injection vector**: malformed/incompatible JSON rejected before Comp/Champion init runs. Codable failures logged but never fatal in release builds (returned as bannerState change, not crash).
- **No PII transmitted**: app makes one URL request to public file. No telemetry yet (PostHog deferred per current scope).

## Next Steps

After Phase 03:
- Phase 04 tests cover RemoteFetcher (URLProtocol mock), SchemaCompatibilityGate (pure unit), DiskCache (tmp dir).
- Phase 04 also adds the 4 doc updates (Phase Completion Protocol).

## Backwards Compatibility

- **Existing testers (when shipped)**: anh's 10 testers are not yet on this app version. No live migration needed; first install = clean slate.
- **Bundled JSON**: stays at v1.0.0 schema (C2 fix). Forward-compat decoder reads both 1.0.0 and 1.1.0. App's `appSchema = 1.1.0` accepts cached/remote 1.0.0 data via `isCompatible` rule (minor backward-compat).
- **Cache**: on app upgrade where schema bumps major, cache becomes invalid — handled by SchemaCompatibilityGate (rejects + re-fetches). On minor bump, cache forward-compatible per `isCompatible` rule.
- **Anomalies field**: pipeline emits `[]` when no anomalies. App decoder requires field present. If old pipeline output (before Phase 01 deploy) lacks field → decode fails → cache rejected → bundled fallback. Acceptable transient.

## Rollback

- Revert `DataManager.swift` to bundled-only stub (current state). App reverts to v0.1-pre-pipeline behavior; bundled JSON renders.
- Revert anomalies field in Comp.swift if blocking; bundled JSON stays at 1.0.0.
- `git revert` of phase-03 commit cleanly reverses without DB/migration impact (no persistent state outside cache file, which can be rm'd).
