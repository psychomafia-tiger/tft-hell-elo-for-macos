# Project Changelog — TFT Hell Elo

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Append-only — never replace or edit prior entries.

---

## [v0.2-data-pipeline] — 2026-04-25

### Added

- Python aggregator package (`Pipeline/src/tftmac_pipeline/`) — 7 new modules: `riot_client`, `tier_calculator`, `anomaly_aggregator`, `champion_aggregator`, `comp_pipeline`, `json_emitter`, `run_aggregator`
- 134 pytest tests covering aggregator modules + existing infrastructure (existing 14 + new ~120)
- `make smoke` (live API, manual) + `make pipeline-test` (fixtures-only, CI) Makefile targets
- GitHub Actions workflow `.github/workflows/tft-data-refresh.yml` — 12h cron (`0 */12 * * *`), defensive design for public repo (SHA-pinned actions, repo guard, no `pull_request_target`, PII grep guard, hand-rolled commit step)
- `data/tier-list.json` initial stub (overwritten by first cron run)
- App service: `RemoteFetcher` actor — HTTPS fetch with 10s timeout and single retry; production URL `raw.githubusercontent.com/.../data/tier-list.json`
- App service: `DiskCache` struct — atomic read/write to `~/Library/Caches/io.psychomafia.tfthellelo/tier-list.json`
- App service: `SchemaCompatibilityGate` struct — pure gate returning `.ok` or `.updateRequired`
- App model: `Anomaly` struct (`id: String`, `agreement: Double`)
- App model fields: `Comp.anomalies: [Anomaly]` (forward-compat `decodeIfPresent ?? []`), `TierList.region: String` (default `"VN2"`)
- App view: `CompCardAnomaliesRow` — chip row for Set 17 EkkoOffering anomaly recommendations (hidden when empty)
- App view: `UpdateRequiredOverlay` — full-screen overlay for schema major version mismatch
- App state: `BannerState` enum (`.fresh`, `.lastUpdated(hoursAgo:)`, `.staleData(daysAgo:)`, `.offlineBundled`, `.updateRequired`) + `BannerBar` view
- App tests: `RemoteFetcherTests`, `SchemaCompatibilityGateTests`, `DiskCacheTests`, `AnomalyDecodeTests`, `DataManagerLifecycleTests` — 80 unit tests + 1 UI test pass
- `docs/bugs-log.md` — 3 entries documenting historical bugs (TCC cdhash, fullscreen capture, git history bloat anticipated)
- `docs/data-pipeline-architecture.md` — pipeline deep-dive (NEW)
- `docs/system-architecture.md` — overall app + pipeline architecture (NEW)
- `docs/project-changelog.md` — this file (NEW)

### Changed

- `DataManager`: refactored from `enum` (static-only, 39 LOC) to `@MainActor final class DataManager: ObservableObject` (~150 LOC) with `@Published var tierList`, `@Published var bannerState`, and 12h background poll `Timer`
- `DataManager.init()` calls `start()` immediately — no `.onAppear` dependency (required for `MenuBarExtra(.window)` lifecycle where window may not appear until first hotkey press)
- `Comp.swift`: added custom `init(from:)` with `decodeIfPresent ?? []` for `anomalies` field — forward-compat with schema 1.0.0 bundled JSON and schema 1.1.0 remote JSON
- `TierList.swift`: added `region: String` with `decodeIfPresent ?? "VN2"` default
- `OverlayWindowController`, `TierListPopover`, `CompListView`: switched from `let tierList: TierList` snapshot to `@EnvironmentObject DataManager` for live `@Published` updates
- `TFTMacApp`: wired `@StateObject var dataManager` + `.environmentObject(dataManager)` injection; `OverlayWindowController` receives same `DataManager` instance at eager-init time
- `Pipeline/pyproject.toml`: version `0.1.x` → `0.2.0`; added `tft-aggregate` console_scripts entry

### Fixed

- (none — this phase ships net-new functionality; bug fixes from prior phases tracked in `docs/bugs-log.md`)

### Architecture impact

- See `docs/data-pipeline-architecture.md` for full pipeline deep-dive
- See `docs/system-architecture.md` for updated overall architecture diagram including pipeline layer
- Schema versioning: bundled JSON stays at 1.0.0; remote JSON at 1.1.0; `SchemaCompatibilityGate.appSchema = SchemaVersion(major: 1, minor: 0, patch: 0)` accepts both. Forward-compat decoder handles missing `anomalies` key gracefully (C2 fix from code-reviewer audit)
- Public repo security: workflow defenses applied — SHA pins, repo guard `if: github.repository == 'psychomafia-tiger/tft-hell-elo-for-macos'`, PII grep guard before commit, hand-rolled commit step. Defense-in-depth on top of Riot Dev key 24h auto-rotation
- `DataManager` refactor cascaded to 6 files (TFTMacApp, OverlayWindowController, TierListPopover, CompListView + 2 test files) — acknowledged in Phase 03 effort bump from 3h to 5h per C1 code-reviewer audit finding

### Audit findings resolved (2026-04-25)

- **C1**: Phase 03 effort 3h → 5h; DataManager enum-to-ObservableObject refactor scope + MenuBarExtra lifecycle hook correctly wired via `DataManager.init()` not `.onAppear`
- **C2**: Anomaly decode uses `decodeIfPresent ?? []`; bundled JSON stays at schema 1.0.0; rollback stays clean
- **C3**: Workflow PII grep guard step added before `git add` — catches PUUID / key fragments before they reach public commit history
- **C4**: SHA-pin policy documented in workflow header comment; manual monthly bump via `gh api`; no Renovate for v0.1

### Known issues

See `docs/bugs-log.md`:
- Bug #002: TFT fullscreen exclusive keyboard capture — deferred to Phase 2
- Bug #003: Git history bloat year-2 (730 commits/year from cron) — deferred to v0.2

### Deferred to v0.2

- Data-drift alerting (PR distribution shift detection)
- Git history bloat mitigation (orphan branch / Git LFS / separate data repo)
- SHA auto-bump tooling (Renovate/Dependabot)
- Multi-region match pool (KR mix when shipping 9 testers)

---

## [v0.2-data-pipeline-hotfix-260426] — 2026-04-26

### Fixed

- **Bug #001b** — Over-defensive `AXIsProcessTrusted()` gate in `HotkeyRegistrar.register()` blocked Carbon hotkey registration despite Carbon `RegisterEventHotKey` not requiring Accessibility permission. Removed gate. Hotkey now binds on first launch without user grant. (See bugs-log Bug #001b for full reasoning.)
- **Bug #001c** — All NSLog string interpolations redacted as `<private>` in unified log (macOS default privacy), making in-process diagnose impossible. Migrated diagnostic logging to `os.Logger` with explicit `\(value, privacy: .public)` interpolation. New shared logger: `AppLog.diagnostics` (subsystem `io.psychomafia.tfthellelo`, category `diagnostics`).

### Changed

- `HotkeyRegistrar.register()` no longer invokes `trustedCheck()` — parameter retained as dead-code for future opt-in (CGEventTap features in Phase 2).
- Removed obsolete tests `testAccessibilityDeniedInvokesPermissionCallback` + `testPermissionDeniedBypassesRegistration`. Replaced with `testRegisterSucceedsEvenWhenTrustedCheckReturnsFalse` (asserts new contract).
- `OverlayWindowController.toggle()` + `TFTMacApp` init NSLogs migrated to `AppLog.diagnostics.notice(_:)`.

### Architecture impact

- None at high-level (no new modules, no API surface change to public callers).
- Internal: `SignpostChannels.swift` now hosts `AppLog` enum alongside `PopoverSignpost` (single shared logging namespace).

### Test gate progress (founder dogfood)

- ✅ Test 3 Cmd+Shift+T hotkey — verified 4 consecutive toggles, <1ms latency hotkey→toggle, state machine consistent
