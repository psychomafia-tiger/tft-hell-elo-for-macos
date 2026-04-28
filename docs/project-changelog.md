# Project Changelog — TFT Hell Elo

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Append-only — never replace or edit prior entries.

---

## [phase-03-tftactics-portrait-redesign] — 2026-04-28

### Added

- **Bundled `set17-items.json`** (183 entries: apiName → displayName + iconToken + itemClass) generated from CommunityDragon `en_us.json`.
- **`ItemAssetURL.swift`** (Services/) — CDragon CDN URL builder using verified pattern `game/assets/maps/tft/icons/items/hexcore/<token>.png` (set suffix `.tft_set13` / `.tft_set17` preserved per item).
- **`ItemBadge.swift`** (Views/) — 12×12pt async-loading view via `AssetCache` with class-tinted RoundedRectangle fallback (tank=blue, ad=red, ap=purple, utility=green, unknown=gray "?").
- **`Pipeline/scripts/generate-set17-items.py`** — CDragon → set17-items.json gen script. Skips items with null/empty name (e.g. `TFT_Item_Blank`). Manual OVERRIDES dict for ~30 known items + keyword heuristic on description for itemClass.
- **23 new tests** across phases: 1 pipeline (Phase 0 itemNames extraction), 3 ItemAssetURL + 6 ItemCatalog (Phase 1), 8 ItemBadge (Phase 2), 5 ChampionPortrait extensions (Phase 3).

### Changed

- **`ChampionPortrait` border ring**: tier-color (S/A/B/C, carry-only) → **cost-color (always)** per TFT canonical convention (1=gray, 2=green, 3=blue, 4=purple, 5=gold).
- **Carry champions** now show 3 `ItemBadge`s overlaid on bottom of portrait (ZStack alignment `.bottom`).
- **`ItemCatalog`** refactored from hardcoded 17-entry dict → bundled JSON load with `iconToken` and `itemClass` fields.
- **Removed `tierColor:` parameter** from `ChampionPortrait.init` — all callers updated to drop argument.

### Fixed

- **Bug #008**: Pipeline `comp_grouping.py` now reads `unit.itemNames` (Set 17 string format like `TFT_Item_GargoyleStoneplate`) instead of `unit.items` (legacy int format that Riot leaves empty). `items[]` in `tier-list.json` is now populated for every champion.

### Removed

- **`CompCardItemsRow.swift`** — legacy text format ("Illaoi → Gargoyle Stoneplate 49%") replaced by portrait overlay. Plus stale comment refs in `CompCardAnomaliesRow.swift` and `ChampionPortrait.swift`.

### Architecture impact

- **New deep-dive doc**: `docs/portrait-redesign-architecture.md`.
- **AssetCache cumulative footprint estimate**: ~1.5MB (champions + traits + items at typical scale). Well under 50MB LRU ceiling.
- **Cold-launch fetch count**: ~1184 (37 comps × 8 champions × ≤4 fetches). Async parallel via URLSession default config; 30-60s to fully populate at typical CDragon p50 latency. Subsequent launches >99% cache hit.

### Commits

- `6bd35f9` fix(pipeline): read unit.itemNames (Set 17 Riot API) in trait-bucket producer (bug #008)
- `7e88d2d` feat(app): set17 item asset metadata + CDragon URL builder
- `24806a9` feat(app): ItemBadge view (12pt async icon + class-tinted fallback)
- `601355f` feat(app): TFTactics-style portrait — cost border always, 3-item overlay on carry
- `93ac39e` docs: handoff portrait redesign phase 0-3 done, phase 4 pending

---

## [phase-02-trait-centric-comp] — 2026-04-27

### Added

- **Pipeline trait grouping**: `comp_grouping.py` (`group_comps_by_trait_signature`) replaces Jaccard-on-champion-set as primary comp identifier. Sorted-tuple-of-(name, tier_current) per participant.
- **Pipeline name resolver**: `comp_name_resolver.py` (`resolve_comp_name`) reads curated `Pipeline/data/trait_name_map.json` (~6 entries, will grow). Falls back to top-2 trait apiNames stripped of `TFT17_` / `Set17_` prefix.
- **Swift `TraitActivation` model** + `Comp.traits[]` field with forward-compat `decodeIfPresent ?? []`.
- **Swift `TraitCatalog`** loads bundled `set17-traits.json` (38 Set 17 traits from CommunityDragon `cdragon/tft/en_us.json`). Maps `apiName → (displayName, iconToken)`.
- **Swift `TraitAssetURL`** builder for CDragon trait icons (`trait_icon_17_<token>.tft_set17.png` — verified suffix via probe).
- **Swift `TraitChip` view** — async-loading badge (count + 16pt icon + display name) using `AssetCache` + `Theme.Fonts.monoCaption`.
- **Pipeline test**: `test_star_level_aggregation.py` — 16 cases covering modal star aggregation + cost-from-rarity fix in trait-bucket emission path.

### Changed

- **Schema 1.1.0 → 1.2.0** (additive). New field `comp.traits: [{name, count, tier_current}, ...]`. Forward-compat decoder retains 1.0.0/1.1.0 support — `traits[]` defaults to `[]` when key absent.
- **`build_tier_list_payload`** rewires to use trait-signature grouping. Iterates buckets, calls `resolve_comp_name`, computes `play_rate = bucket.sample_size / total_participants`.
- **`CompCard.body`** renders trait chips row between `topRow` and `championsRow`, sorted by activation count descending. Hidden when `comp.traits` is empty.
- **`_strip_prefix` regex** handles both `Set17_` and `TFT17_` (Discovery: real Riot API uses `TFT17_*`, not `Set17_*` as the design doc assumed).
- **Bundled fixture `sample-tier-list.json`** regenerated from KR fixture via `build_tier_list_payload` at schema 1.2.0 — 32 comps with populated traits[]. Threshold `min_sample` relaxed to 3 for small-fixture demo (production uses 10).
- **Test suite refactor** — `SampleTierListFixtureTests`, `DataManagerTests`, `TierListDecodingTests` rewritten from hardcoded synthetic-fixture assertions (count=10, S=4 A=4 B=2) to invariant-based shape checks (≥1 comp, schema=1.2.0, traits[] non-empty for ≥1 comp). Future fixture refreshes no longer require test edits.

### Fixed

- **Bug #005 — star_level data-driven + 3-star-only render**:
  - Pipeline: `aggregate_champions` aggregates modal `tier` per champion across top-4 placements (Riot Match-v5 `units[].tier`). Emits `star_level: int` in champion dict.
  - `json_emitter._emit_champions_from_bucket` now derives real `cost` from rarity (was hardcoded 0 — handoff TODO #4) AND `star_level` from `champion_star_counts` (defaults 1 — full counts pending Phase 3 `comp_grouping.py` enrichment).
  - Swift `Champion.starLevel: Int` (default 1) with custom `init(from:)` for forward-compat decode of legacy fixtures.
  - `StarLevelIndicator` body: `if level >= 3 { 3 stars } else { EmptyView }` per TFTactics convention. `derivedLevel(for:)` marked `@available(*, deprecated)`.
  - `ChampionPortrait` passes `champion.starLevel` directly (replaces placeholder `StarLevelIndicator.derivedLevel(for: champion)`).
- **`Champion.CodingKeys` snake-case raw values** — removed mid-fix. Explicit `case isCarry = "is_carry"` short-circuited parent decoder's `.convertFromSnakeCase` strategy → keyNotFound at runtime. Strategy alone now handles snake/camel conversion.

### Architecture impact

- Pipeline grouping reshaped — comp count may collapse (trait similarity tighter than Jaccard). Tier thresholds may need re-tuning post-cron-run on production VN2 data.
- Champion `cost` previously emitted 0 from new trait-bucket path — fixed in this phase. Real `cost` derived from `champion_rarity + 1`. `star_level` similarly emits from `champion_star_counts` modal (defaults to 1 in trait-bucket path until Phase 3 wires `champion_star_counts` into bucket dict from `comp_grouping.py`).
- New deep-dive doc: `docs/trait-aggregation-architecture.md`.
- Curated `trait_name_map.json` keys may MISS on real data (use semantic apiNames like `TFT17_Psionic+TFT17_Conduit`, but real API emits `TFT17_PsyOps`). Phase 3 action: regenerate keys from real apiNames after first cron run.

### Bug fixes

- Bug #005 (star_level over-render) — see `docs/bugs-log.md` (status updated ⏳ Deferred → ✅ Fixed).

### Commits

- `197e432` feat(app): render trait chips row in CompCard
- `2012053` data: refresh bundled fixture to schema 1.2.0 (trait-aware)
- `09a1290` fix(app+pipeline): star_level data-driven, 3-star-only render (bug #005)
- `268be11` feat(app): TraitChip view with async icon load via TraitCatalog (predecessor session)
- `299ac6d` feat(app): TraitCatalog + TraitAssetURL with verified Set 17 metadata (predecessor session)
- `a7bc0d1` feat(app): explicit test for schema 1.2.0 acceptance (predecessor session)
- `7ac2954` feat(app): TraitActivation model + Comp.traits with forward-compat decode (predecessor session)
- `350d93b` fix(pipeline): TFT17_ prefix support (predecessor session)
- `a4c1cad` feat(pipeline): wire trait grouping + schema 1.2.0 (predecessor session)
- `55efa40` feat(pipeline): group_comps_by_trait_signature (predecessor session)
- `693060b` feat(pipeline): comp_name_resolver curated map (predecessor session)
- `e1cf46c` feat(pipeline): trait_combo_signature (predecessor session)

---

## [phase-01-champion-portraits] — 2026-04-26

### Added

- `AssetCache` service (URLSession + 30-day disk cache, 50MB LRU eviction). SHA-256 URL → filename. Returns nil on 4xx/5xx/timeout for graceful UI fallback.
- `ChampionAssetURL` builder for CommunityDragon Set 17 CDN. Pattern: `tft17_{lower}/hud/tft17_{lower}_square.tft_set17.png`.
- Bundled `set17-champions.json` (59 Set 17 IDs with curated displayNames — Kai'Sa, Bel'Veth, Cho'Gath, etc.).
- New tests: `AssetCacheTests`, `ChampionAssetURLTests`, `ChampionCatalogDataDrivenTests`, `test_aggregator_metadata`.

### Changed

- `ChampionPortrait` renders real CommunityDragon artwork via `.task` async load (was: cost-colored placeholder circles only).
- `ChampionCatalog` now data-driven from bundled JSON (was: 15-entry hand-coded dict).
- Tier thresholds relaxed: S = ≥5% play / ≤4.3 avg (was: ≥10% / ≤4.0). Live VN2 data now emits 2 S-tier comps.
- Pipeline schema unchanged (`1.1.0`).

### Fixed

- **Bug #004**: aggregator now populates top-level `updated_at` + `match_count` fields. App's HeaderBar will show real "X min ago" timestamp on next pipeline run (was: "—").

### Architecture impact

- New Services layer member: `AssetCache.shared` singleton.
- Disk cache directory: `~/Library/Caches/io.psychomafia.tfthellelo.assets/`.
- Bundle size +3KB (`set17-champions.json`). No asset bundling — all artwork lazy-fetched.
- New deep-dive doc: `docs/asset-pipeline-architecture.md`.

### Commits

- `3768b97` fix(pipeline): populate updated_at + match_count metadata (bug #004)
- `3089cb5` test(pipeline): cover build_tier_list_payload with real matches
- `d5874b4` tune(pipeline): relax S-tier to 5% play / 4.3 avg (VN2 meta — bug #C1)
- `bf285a1` feat(app): ChampionAssetURL builder for CommunityDragon CDN
- `e4004d5` feat(app): AssetCache service with disk persistence + LRU eviction
- `b35a848` feat(app): data-driven Set 17 champion catalog (~50+ entries)
- `6605802` feat(app): ChampionPortrait loads real Set 17 art from CommunityDragon

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
