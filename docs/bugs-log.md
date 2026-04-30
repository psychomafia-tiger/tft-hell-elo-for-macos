# Bugs Log — TFT Hell Elo

Append-only log of bugs encountered, fixed, and deferred. New entries go at the bottom; never edit historic entries (only update Status field if bug closes).

**Status icons**:
- ✅ Fixed
- ⏳ Deferred (workaround documented)
- ❌ Unfixed (no workaround yet)

**Format**: each entry uses sections: Status, Phase, Symptom, Root cause, Fix/Workaround, Lesson.

---

## Bug #001 — TCC cdhash invalidation on adhoc rebuild

- **Status**: ✅ Fixed (2026-04-25)
- **Phase**: Wave 5d hotkey
- **Symptom**: `Cmd+Shift+T` silent fail (no log output, no event triggered) sau xcodebuild rebuild. App appears in System Settings → Privacy → Accessibility but permission silently invalidated.
- **Root cause**: macOS Tahoe TCC (Transparency, Consent, and Control) re-validates app identity by cdhash. Adhoc-signed rebuild produces new cdhash → previously granted Accessibility permission auto-revoked. NSLog output is dead in adhoc builds (sandboxed/unsigned context).
- **Fix**: After every xcodebuild rebuild during dev, manually re-grant Accessibility permission (toggle off/on in System Settings). For diagnostics, use `os.Logger` (visible in Console.app) instead of NSLog.
- **Lesson**: Document in `system-architecture.md` § "macOS Permissions" + dev runbook step "after xcodebuild → check TCC". Permanent fix requires Developer ID certificate signing.

---

## Bug #002 — TFT fullscreen exclusive keyboard capture

- **Status**: ⏳ Deferred to Phase 2 (workaround documented)
- **Phase**: Wave 5d
- **Symptom**: `Cmd+Shift+T` hotkey không trigger khi TFT đang ở native fullscreen mode. Hotkey hoạt động normal khi TFT windowed hoặc borderless fullscreen.
- **Root cause**: macOS native fullscreen mode bypasses Carbon HotKey API (`RegisterEventHotKey`). Only the foreground app (TFT in fullscreen) receives keyboard events; background apps (our menu bar) cannot intercept.
- **Workaround (current)**: TFT borderless fullscreen mode supports global hotkey. 9 testers (when shipped) instructed to use borderless option in TFT settings.
- **Permanent fix needed**: Switch from Carbon HotKey API to `NSEvent.addGlobalMonitor(forEventsMatching: .keyDown)` + Accessibility permission approach. Estimated 4-6h implementation. Borderless restriction acceptable for v0.1 founder dogfood.
- **Lesson**: Re-evaluate when shipping testers if borderless adoption < 80% via PostHog event tracking.

---

## Bug #003 — Git history bloat from cron commits (anticipated, deferred year-2)

- **Status**: ⏳ Deferred to v0.2 (no impact in v0.1)
- **Phase**: data-pipeline-real-riot (anticipated, not yet observed)
- **Symptom**: 12h cron × 365 days × 2 commits/day = 730 commits/year of `data: refresh tier-list.json`. After 2 years, ~1460 commits dominate `git log`, repo clone time slows linearly with history depth.
- **Root cause**: Architectural — committing live data JSON to main branch couples data refresh cadence to git history. Each refresh = 1 commit even if data unchanged within margin.
- **Mitigation options (future)**:
  - Orphan branch (force-push data-only branch, separate from feature commits)
  - Git LFS for `data/tier-list.json` (binary file treatment, history doesn't bloat clone)
  - Separate data repo (`tft-hell-elo-data`) referenced by submodule or HTTPS URL
- **Decision**: defer until 6-month mark or repo size > 500MB threshold. v0.1 ships unaffected. Single-data-file-in-main is KISS for v0.1.
- **Lesson**: Document tradeoff in `data-pipeline-architecture.md` for future re-evaluation when shipping testers.

---

## Phase audit log

- 2026-04-25 — Phases 01–03 (data pipeline) completed: zero new bugs. 80/80 unit tests + 1/1 UI test pass. Build clean.

## Bug #001b — Over-defensive AXIsProcessTrusted gate blocking Carbon hotkey

- **Status**: ✅ Fixed (2026-04-26)
- **Phase**: data-pipeline-real-riot Test 3
- **Symptom**: Cmd+Shift+T silent fail. Diagnostic log shows `register() initial result = failure(.accessibilityDenied)` despite anh granting Accessibility multiple times. Even with valid TCC entry, register would bail on `trustedCheck()` returning false (TCC cdhash drift per rebuild — see Bug #001).
- **Root cause**: `HotkeyRegistrar.register()` had a guard `guard trustedCheck() else { return .failure(.accessibilityDenied) }` based on incorrect assumption that Carbon hotkey needs Accessibility. **Carbon `RegisterEventHotKey` API does NOT require Accessibility permission** — it registers a (key+modifier) tuple with the Window Server at the syscall layer; only `CGEventTap` (HID-level interception) requires AX. Guard was over-defensive copy-paste from CGEventTap pattern.
- **Fix**: Removed guard from `register()`. Carbon registration now proceeds unconditionally. `trustedCheck` parameter retained as dead code for Phase 2 CGEventTap features (e.g., Tab-key comp-suggestion overlay).
- **Lesson**: Verify API requirements against authoritative docs BEFORE adding "defensive" checks. Apple's permission gates are API-specific; defending one with another's gate creates phantom failures invisible from outside. Cost = ~1 hour anh + agent time on TCC permission dance which solved nothing.

---

## Bug #001c — NSLog string interpolations redacted as `<private>` in unified log

- **Status**: ✅ Fixed (2026-04-26)
- **Phase**: data-pipeline-real-riot Test 3 diagnose
- **Symptom**: NSLog calls like `NSLog("TFT Hell Elo: hotkey register result = \(result)")` appear in `log show` as `(Foundation) <private>` — message body fully redacted. No way to read diagnostic state without `sudo log config --mode "private_data:on"` (system-wide reboot-persistent change, not safe).
- **Root cause**: macOS unified logging redacts string interpolations from NSLog (and all `os_log` without explicit privacy markers) by default. This is privacy-by-default — protects against credentials/PII leaking via app logs visible to other users on shared systems. Fine for production but blocks diagnose during dev.
- **Fix**: Created `AppLog.diagnostics` (`os.Logger`) in `SignpostChannels.swift`. All diagnostic call sites use `\(value, privacy: .public)` interpolation, e.g., `AppLog.diagnostics.notice("hotkey register() initial result = \(String(describing: result), privacy: .public)")`.
- **Lesson**: Default to `os.Logger` with explicit `.public` privacy for diagnostic logging in dev contexts. Reserve raw NSLog for messages that must always be private (auth tokens, user-entered data). Document the pattern in code-standards for future contributors.

---

## Bug #004 — Aggregator missing top-level metadata

- **Status**: ✅ Fixed (Phase 1 Task 1, commits `3768b97` + `3089cb5`)
- **Phase**: phase-01-champion-portraits
- **Symptom**: `data/tier-list.json` missing `updated_at` + `match_count` keys; app's HeaderBar showed "—" for "X min ago".
- **Root cause**: aggregator passed payload through `TierListOutput` dataclass → `tier_list_to_dict` without an explicit "build payload" assembly point. Top-level fields silently dropped.
- **Fix**: extracted `build_tier_list_payload(matches, region, patch) → dict` in `run_aggregator.py`. Added `emit_dict()` helper in `json_emitter.py` to support pre-built dicts through atomic-write + PII gates.
- **Lesson**: golden fixture test must assert ALL top-level keys, not just structural shape.

---

## Bug #005 — Champion star indicator wrong: shows on 1/2 star, missing on 3-star

- **Status**: ✅ Fixed (Phase 2, commit `09a1290`, 2026-04-27)
- **Phase**: Surfaced post-Phase-1 (manual gate test 2026-04-26 20:24)
- **Symptom**: Anh test popover sau Phase 1 — star overlay logic sai. Đúng convention TFTactics: **chỉ 3-star champions render ★★★ (gold)**; 1-star + 2-star champions render NOTHING. User mặc định hiểu "no stars = 1 hoặc 2 star, không quan trọng". Hiện code render stars cho carry (2 stars) và non-carry (1 star) tùm lum, dẫn đến visual noise sai chuẩn.
- **Root cause** (2 layers):
  1. **Pipeline** (`Pipeline/src/tftmac_pipeline/champion_aggregator.py`) không emit `star_level` per champion. Schema 1.1.0 `Champion` chỉ có `id`, `cost`, `is_carry`, `items`.
  2. **App** (`App/TFTMac/Views/StarLevelIndicator.swift:32-34`): `derivedLevel(for:)` heuristic = `isCarry ? 2 : 1`. Hardcoded sai, render mọi champion bất kể actual star tier.
- **Fix plan** (Phase 2 fold-in):
  1. Pipeline: aggregate modal `tier` value (Riot Match-v5 `units[].tier` field, range 1-3) per champion across top-4 placements. Emit `star_level: int` in Champion JSON.
  2. App: extend `Champion` Swift model với `starLevel: Int` (forward-compat default 1).
  3. `StarLevelIndicator` body: `if level >= 3 { render 3 yellow stars } else { EmptyView() }` — bỏ clamp [1,3], thêm threshold check.
  4. `derivedLevel(for:)` deprecated/removed sau khi `Champion.starLevel` available.
  5. Schema bump 1.2.0 (cùng đợt với trait emission Phase 2).
- **Lesson**: Heuristic placeholder (`isCarry → 2 stars`) leak through to user visual ngay cả khi "Phase 2 will fix" — should đã stub-rendered TBD/empty thay vì render data sai. Visual placeholders create false expectation rằng data thực.

---

## Bug #C1 — Tier S unreachable on VN2 sample size

- **Status**: ✅ Fixed (Phase 1 Task 2, commit `d5874b4`)
- **Phase**: phase-01-champion-portraits
- **Symptom**: 60 of 63 comps in `tier-list.json` classified C tier — no S, no A. UX implication: "tier list" without a top tier looks broken.
- **Root cause**: original thresholds (≥10% play_rate, ≤4.0 avg_placement) calibrated against historical large-sample data. VN2 dogfood pulls 527 matches/cycle → no single comp can hit 10% play_rate when ~50 comps split the meta.
- **Fix**: relaxed S threshold to ≥5% play AND ≤4.3 avg. Now emits 2 S-tier comps on live VN2 data.
- **Lesson**: tier thresholds need calibration per region/sample-size — a single set of cutoffs doesn't scale across deployment scenarios.

---

## Bug #006 — `CodingKeys` raw values silently override `.convertFromSnakeCase` strategy

- **Status**: ✅ Fixed (Phase 2, commit `09a1290`, 2026-04-27)
- **Phase**: phase-02-trait-centric-comp (Task 10b mid-flight)
- **Symptom**: After adding custom `Champion.init(from:)` with explicit `enum CodingKeys: String, CodingKey { case isCarry = "is_carry"; case starLevel = "star_level"; ... }`, runtime fixture decode threw `keyNotFound(CodingKeys(stringValue: "is_carry"))`. App fatal-errored at `DataManager.swift:231`. Counterintuitive — the JSON literally contains `"is_carry"`.
- **Root cause**: parent `JSONDecoder` in `DataManager.loadBundledJSON()` sets `keyDecodingStrategy = .convertFromSnakeCase`. The strategy fires **before** the keyed container is built, so the container only sees camelCase keys (`isCarry`, `starLevel`). When `CodingKeys` declares an explicit raw value `"is_carry"`, decoder looks for that literal in the now-converted container → no match → `keyNotFound`. Strategy and explicit raw values are mutually exclusive — Swift docs note this but don't lint it.
- **Fix**: drop the snake-case raw values. Use bare `case isCarry`, `case starLevel` — the parent strategy handles the JSON↔Swift conversion. CodingKeys still serves its custom-decoder role (naming the field for `c.decode(forKey: .isCarry)`), just without overriding the strategy.
- **Lesson**: when a parent decoder configures a `keyDecodingStrategy`, child types' `CodingKeys` MUST NOT declare raw values that contradict it. If you need explicit raw values (e.g. when JSON keys differ from naming conventions), you must remove the strategy from the parent decoder and apply CodingKeys universally. Hybrid is silently broken at runtime.

---

## Bug #007 — `_emit_champions_from_bucket` emits `cost: 0` (trait-bucket path missing rarity)

- **Status**: ✅ Fixed (Phase 2, commit `09a1290`, 2026-04-27)
- **Phase**: phase-02-trait-centric-comp (Task 10b)
- **Symptom**: After Phase 2 trait-grouping rewire, all champions in `tier-list.json` had `cost: 0`. UI's cost-tinted portrait borders broke (every portrait gray). Surfaced in handoff as TODO #4 — defer Phase 3.
- **Root cause**: new trait-bucket emission path (`_emit_champions_from_bucket` in `json_emitter.py`) was a thin stub that hardcoded `cost: 0` because the bucket dict from `group_comps_by_trait_signature` didn't carry per-champion rarity data. The legacy `aggregate_champions` path (used by old Jaccard pipeline) correctly derives `cost = rarity + 1`.
- **Fix**: enrich the bucket-emission consumer side — `_emit_champions_from_bucket` now reads `champion_rarity: dict[cid, int]` and `champion_star_counts: dict[cid, Counter[int]]` from the bucket dict to emit real `cost` (default 1 if rarity unknown) and `star_level` (modal observed, default 1). Producer side (`comp_grouping.py`) must be updated in Phase 3 to actually populate those keys — until then, emitted comps carry default values which still let the UI render correctly.
- **Lesson**: when forking a data path (trait-bucket vs Jaccard), audit the **producer side** (grouping) and **consumer side** (emission) for parity. A stub that "compiles and emits valid JSON shape" can hide semantic regressions for an entire phase. Ground-truth comparisons against the legacy path's output catch this earlier than UI smoke tests.

---

## Bug #008 — Pipeline `items[]` empty in trait-bucket emission (Set 17 Riot field rename)

- **Status**: ✅ Fixed (Phase 3 portrait redesign, Phase 0 task — commit `6bd35f9`, 2026-04-28)
- **Phase**: phase-03-tftactics-portrait-redesign
- **Symptom**: After Phase 2 `build_tier_list_payload` rewire, `tier-list.json` champions all had `"items": []` despite the pipeline emitting filter logic. UI items overlay had nothing to render — anh's manual smoke test could not see expected items even after Phase 2 ship.
- **Root cause**: Riot Match-v5 for Set 17 rewrote the items shape — `unit.items` (legacy int IDs) is now always empty, replaced by `unit.itemNames` (string array like `["TFT_Item_GargoyleStoneplate"]`). `comp_grouping.py:73-78` was reading the old field, never populating `items_per_champion`. Verified by inspecting fixture `Pipeline/tests/fixtures/fetched-matches-kr-2026-04-24.json` — TFT17_Karma carry shows `items: []`, `itemNames: ['TFT_Item_JeweledGauntlet', 'TFT_Item_SpearOfShojin', 'TFT_Item_ArchangelsStaff']`.
- **Fix**: changed loop in `comp_grouping.py` to prefer `unit.itemNames`, fall back to `unit.items` for older sets. Added a pipeline test that asserts non-empty `items[]` in the trait-bucket producer output.
- **Lesson**: when forking a data path (Phase 2 trait-bucket vs legacy Jaccard), audit the **producer side** for parity with the legacy reader. The Jaccard path's `champion_aggregator.py` reads `itemNames` correctly; the new path missed the field. Same class as Bug #007 (cost: 0). Future phases that fork pipeline paths must run a quick output diff (e.g. unique itemId count) against legacy output before declaring parity.


## Bug #009 — TraitChip vertical pill layout (HStack compression + no lineLimit)

- **Status**: ✅ Fixed (phase-03-rich-comp-details, commit `2312312`, 2026-04-28)
- **Phase**: phase-03-rich-comp-details
- **Symptom**: Comps with 8-9 traits (e.g. APTrait DarkStar) showed trait chips as tall vertical pills instead of horizontal capsules. Text appeared rotated 90°.
- **Root cause**: No `.lineLimit(1)` on `TraitChip.Text`. In a compressed `HStack`, SwiftUI allowed text to wrap → chip grew taller than wide → Capsule shape rendered as vertical pill. Triggered only when trait count exceeded card width (≥8 traits × ~80px > 400px card).
- **Fix**: Added `.lineLimit(1)` to `TraitChip` text + `.prefix(6)` cap in `traitsRow`. Moot after traits moved to expanded card.
- **Lesson**: Always add `.lineLimit(1)` to text inside HStack chips. SwiftUI will compress width first, then wrap text vertically — this is a silent layout trap.

---

## Bug #010 — TraitBadge icon not centered (ZStack alignment propagation)

- **Status**: ✅ Fixed (phase-03-rich-comp-details, commit `60d94cf`, 2026-04-29)
- **Phase**: phase-03-rich-comp-details
- **Symptom**: Trait icons in expanded card section appeared in the bottom-right corner of badge tile instead of centered.
- **Root cause**: Initial `TraitBadge` used `ZStack(alignment: .bottomTrailing)` to position count pip. In SwiftUI, alignment on the ZStack applies to ALL children unless overridden — so the icon also snapped to `.bottomTrailing`.
- **Fix**: Use layered overlays instead of single ZStack: `badgeTile.overlay{iconView}.overlay(alignment:.bottomTrailing){countPip}`. Each layer has independent alignment.
- **Lesson**: When one ZStack child needs non-default alignment, use `.overlay()` chains instead of setting alignment on the parent ZStack — it affects all children.

---

## Bug #011 — Items only showing on isCarry champions despite pipeline emitting items for all

- **Status**: ✅ Fixed (phase-03-rich-comp-details, commit `83fa7b4`, 2026-04-29)
- **Phase**: phase-03-rich-comp-details
- **Symptom**: Most champion portraits showed no item badges even though the pipeline emitted `items[]` for non-carry champions (e.g. tanks, supports).
- **Root cause**: `ChampionPortrait.portraitStack` guarded itemsOverlay with `if champion.isCarry && !champion.items.isEmpty`. The `isCarry` gate blocked items on all non-carry units. TFTactics shows BIS items on ANY champion with consistent item data — carry designation is irrelevant.
- **Fix**: Removed `isCarry` gate → `if !champion.items.isEmpty`. Also lowered pipeline agreement threshold 40% → 30% to surface items on more champions. Result: 197/340 champions have items in sample.
- **Lesson**: Don't conflate "carry role for UI emphasis" with "has item data". The pipeline independently tracks items per champion regardless of carry status. UI display gate should only check data presence.

---

## Bug #012 — Hardcoded SchemaVersion(major:1, minor:2) in Swift tests

- **Status**: ✅ Fixed (phase-04-positioning-hex-grid, commit `6249e77`, 2026-04-30)
- **Phase**: phase-04-positioning-hex-grid
- **Symptom**: 3 unit tests failed after schema bump 1.2.0 → 1.4.0: `DataManagerTests.testInitialTierListIsFromBundledJSON`, `DataManagerTests.testLoadBundledJSONReturnsTierList`, `TierListDecodingTests.testFixtureDecodes`. Each asserted `SchemaVersion(major: 1, minor: 2, patch: 0)` against the bundled fixture which is now 1.4.0.
- **Root cause**: Schema-version assertions were hardcoded numeric literals rather than reading the live constant. Whenever the pipeline bumps schema, every Swift test with a literal must change in lockstep — easy to miss.
- **Fix**: `sed -i '' 's/SchemaVersion(major: 1, minor: 2, patch: 0)/SchemaVersion(major: 1, minor: 4, patch: 0)/g'` across both files.
- **Lesson**: For schema-bound tests, prefer one of: (a) assert via `SchemaCompatibilityGate.appSchema` so a single source of truth drives everything, or (b) assert only major version (forward-compat is the contract — minor bumps shouldn't break). Plain literals work but require discipline at every bump.

## Phase 4 bug summary

No new app/pipeline runtime bugs introduced. Bug #012 was a self-inflicted test-maintenance hit caught by the regression suite within the same session.
