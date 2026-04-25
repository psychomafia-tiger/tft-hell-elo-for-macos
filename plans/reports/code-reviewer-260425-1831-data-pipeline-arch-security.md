# Code-reviewer report — Data pipeline plan (architecture + security dual review)

**Date**: 2026-04-25 18:31 ICT
**Plan reviewed**: `plans/260425-1817-data-pipeline-real-riot/` (plan.md + phase-01..04)
**Reviewer mode**: PUBLIC repo paranoia + KISS bias

---

## 1. Architecture verdict: **APPROVE_WITH_CHANGES**

Plan is solid (vững), reuse strategy correct, phase split clean. 4 critical claims need correction before implementation; otherwise the design holds.

## 2. Security verdict: **APPROVE_WITH_CHANGES**

Phase-02 defensive checklist is comprehensive and correct (SHA-pin, repo guard, no `pull_request_target`, no `${{ github.event.* }}`, scoped `permissions:`). 3 security gaps need patching before workflow merges.

---

## 3. Critical findings (MUST fix before implement)

### C1. Plan-03 `DataManager` rewrite premise mismatch with current code (architecture)

**File**: `App/TFTMac/Services/DataManager.swift` line 18 — current is `enum DataManager` with one static method (no instance state). Plan-03 lines 64–73 design `DataManager (@MainActor, ObservableObject)` with `@Published` properties.

**Impact**: This is a **breaking API change** for 4 callers, not a "rewrite":
- `TFTMacApp.swift:39` — `DataManager.loadBundledJSON()` static call from `init()`
- `TFTMacApp.swift:42` — passes loaded `TierList` (let, not @StateObject) into `OverlayWindowController(tierList:)`
- `TierListPopover.swift:22` — receives `let tierList: TierList`
- `OverlayWindowController.swift:41` — holds `private let tierList: TierList?`

The eager-init-in-`init()` pattern (line 38-42 of `TFTMacApp.swift`) hardcodes a synchronous bundled load. Switching to `@StateObject` + async fetch chain requires:
- `TFTMacApp` becomes `@StateObject var dataManager` (App-scope) — plan-03 step 10 hand-waves this in 1 line
- `OverlayWindowController` must observe via `@ObservedObject` or take `@Binding`, not plain `let TierList?` — currently it stores a snapshot at init time and never updates. **If plan-03 doesn't rewire this, the overlay stays frozen on bundled data forever even after remote fetch succeeds.**
- `TierListPopover(tierList:)` likewise needs `@ObservedObject dataManager` plumbing

**Plan-03 step 10 wording**: "TFTMacApp instantiates `@StateObject var dataManager = DataManager()`, calls `.start()` in `onAppear` of root view; `.stop()` in `WindowGroup.onChange(of: scenePhase)`". Wrong on 2 counts:
1. App is `MenuBarExtra(.window)`, not `WindowGroup`. `scenePhase` semantics differ.
2. `.onAppear` fires only when the menu bar popover opens. If user never opens popover but overlay shows via hotkey, `.start()` never fires → no fetch ever happens.

**Fix**: Plan-03 must specify
- Lifecycle hook = `init()` of `TFTMacApp` or a `.task` on a hidden Settings scene (always-active)
- `OverlayWindowController` rewired to observe DataManager (not snapshot tierList at init) — this is a non-trivial NSHostingView rebuild on tierList change
- Acknowledge this is at minimum a 6-file change, not the "1-line wire" implied

### C2. Plan-03 `Comp.anomalies` non-optional decode breaks existing tests + bundled rollback (architecture)

**File**: `App/TFTMacTests/TierListDecodingTests.swift` lines 16-35, `App/TFTMacTests/DataManagerTests.swift` line 13 — both assert against schema 1.0.0 JSON literals **without** `anomalies` field.

**Plan-03 line 225**: `let anomalies: [Anomaly]   // NEW — non-optional, defaults to [] in pipeline emit`. Plan-03 line 229 acknowledges the fixture-default-decoder option but rejects it: "Default in this plan: simple `decode` requiring field present, since bundled JSON is updated in lockstep."

**Impact**:
- `TierListDecodingTests.testValidJSONDecodesWithAllFields` (line 16) hard-codes JSON literal without `anomalies` → fails on `decode` after Comp change
- `DataManagerTests.testLoadBundledJSONReturnsTierList` (line 13) asserts `schemaVersion == 1.0.0` → fails after bundled JSON bump to 1.1.0
- Phase-03 rollback plan (line 372): "Revert anomalies field in Comp.swift if blocking; bundled JSON stays at 1.0.0" — but the bundled JSON has been bumped in the same phase. Rollback = bundled JSON 1.1.0 + Comp.swift 1.0.0 = decode failure. **Cascading rollback not graceful**, contradicting plan.md line 147.

**Fix**: Use `decodeIfPresent([Anomaly].self) ?? []` for Comp.anomalies. Pros:
- Bundled JSON 1.0.0 fixtures still load (preserves rollback safety net)
- Future pipeline emits without anomalies (transient deploy gap) still decode
- Test fixtures unchanged — no shotgun edits to TierListDecodingTests
- Forward-compat: if Set 18 removes anomalies, app doesn't crash

The "bundled JSON in lockstep" argument is fragile against any rollback, partial deploy, or test isolation.

### C3. Phase-02 security: `git push` after secret-step missing audit guards (security)

**File spec**: phase-02 lines 94-106 — commit & push step.

**Gap 1 — no `--no-edit`/no-untracked check**: `git add data/tier-list.json` is fine, but if aggregator panic-writes any sibling file (logs, partial JSON) before exit, `git status` could show extra untracked files. The `git add` is targeted but a future maintainer "simplifying" to `git add -A` would silently commit secrets if RIOT_API_KEY was ever written to disk by future telemetry.

**Gap 2 — no post-aggregator output sanity check**: workflow commits `data/tier-list.json` without grep-asserting absence of `puuid|riotId|RIOT_API_KEY` substrings. Phase-01 line 306 mentions this as a test, but the test runs in pytest (CI test suite), NOT in the production workflow. **A bug in aggregator that leaks PUUIDs to output JSON ships to public repo on next cron run; tests don't catch it because tests use a different fixture.**

**Gap 3 — `[skip ci]` in commit message is not a security issue but a foot-gun**: future test workflow added by Renovate/Dependabot would skip running on data refresh commits. Acceptable IF anh adds a separate test workflow that explicitly runs on push to `Pipeline/**` paths only.

**Fix**: Add post-aggregator sanity step before `git add`:
```yaml
- name: Sanity-check no PII/secrets in output
  run: |
    if grep -qE '"puuid"|"riotIdGameName"|RGAPI-' data/tier-list.json; then
      echo "::error::Aggregator output contains PII or API key fragment — REFUSING TO COMMIT"
      exit 1
    fi
```

### C4. Phase-02 security: workflow injection vector via `name:` of action SHAs comments (security, low likelihood, defense-in-depth)

**File spec**: phase-02 lines 119-122 — `# v4.x.x` comments after SHA pin.

**Issue**: Not an immediate exploit, but if anh ever pivots to `dependabot.yml` or Renovate auto-updates, those tools parse the comment to determine "current version". Comment drift → tool either silently skips updates or auto-bumps to wrong SHA. KISS solution: use the canonical Renovate format `# v4 # ratchet:disable` or just omit the version comment and rely on Renovate's pinDigests config.

**Fix**: Either (a) commit to Renovate config that handles SHA pinning explicitly, or (b) document in `tft-data-refresh.yml` header comment that SHA bumps are manual-only with link to Phase-02 spec. Don't leave the version-comment convention undefined.

---

## 4. Recommended improvements (nice-to-have, not blocking)

### R1. Plan-01 — `aggregator` exit code 3 ("insufficient data") edge case (architecture)

Phase-01 line 196: "0 valid matches at end → Abort with exit code 3, 'Insufficient data — refusing to overwrite tier-list.json with empty output'". Good. But threshold is "0", not "<10" or "<min_sample". VN2 Challenger may legitimately return 50 matches with messy queue mix → 5 valid post-filter. That's data-disaster (insufficient signal) but exits 0 with garbage output. Suggest threshold `<200 matches` aborts with exit 3.

### R2. Plan-02 — workflow log retention (security observability)

GitHub Actions logs retain 90 days by default. If a 401 ever surfaces with key fragment in error body (Riot API responses sometimes echo first/last 4 chars), key fragment is permanently in logs. Phase-01 NF1 says aggregator log-redacts; verify Riot's 401 response body is also redacted before being logged. Suggest aggregator catches HTTP errors and logs only status code + URL path, never response body.

### R3. Phase-01 — `aiolimiter` 50/60s vs Riot 100/120s leaves 50% capacity unused

Phase-01 line 31 + 221: chose 50/60s for "20% safety margin" but Riot is 100/120s = 50/60s exactly half. That's a 50% safety margin (over-conservative). Phase-01 line 31 wall-time math (12 min for 1101 reqs at 50/min) is correct given the conservative choice, but anh could go to 75/60s and still have 25% headroom. KISS bias says: leave at 50/60s for safety, but don't claim "20% safety margin" in spec — actual is 50%. Update doc accuracy.

### R4. Phase-03 — anomaly chip displayName parser unspecified

Phase-03 lines 184-188 leaves `displayName` parser body as `...`. Not blocking, but spec is hand-waving — "Strip prefix, split CamelCase → space" has edge cases (`TFT17_EkkoOffering_AnomalyItem_Tier3` → "Anomaly Item Tier 3"? Or "Anomaly Item Tier3"?). Suggest: write regex + 5 test cases in same spec, or punt to "raw ID rendered for v0.1, parser deferred to v0.2" (matches founder dogfood scope).

### R5. Phase-02 — first-run timing assumption

Phase-02 line 162: "After merge to default branch, scheduled run appears in Actions UI within 12h". GitHub Actions cron has known 5-15 min drift on free tier (well-documented; cron drift on shared runners). For founder dogfood, acceptable. For 9-tester ship, document this — first-cron-after-merge might fire at +13h. Add to runbook.

### R6. Phase-04 — golden file regen workflow security

Phase-04 line 134: `make regenerate-golden` runs locally only, dev-tool. Good. But add to spec: "Golden file is committed; PR review must include human-eyeball-diff of golden JSON when regenerated." Otherwise a PR that quietly regenerates golden after introducing a bug = silent test bypass.

### R7. Plan-03 `DataManager` snake_case decoder collision risk

Phase-03 step 1: "Add Anomaly model" with `let id: String; let agreement: Double`. Pipeline will emit `{"id": "TFT17_EkkoOffering_AnomalyItem", "agreement": 0.71}`. With `.convertFromSnakeCase`, single-word `id` and `agreement` are fine. But check for any future Anomaly field with multi-word name (e.g. `effect_description`) — `.convertFromSnakeCase` rule converts to `effectDescription`. Document the convention so contributors don't add `effectDesc` and break decode.

### R8. Phase-03 cache 7-day TTL undocumented edge

Phase-03 F4: "If cached data >7d old OR missing, fall back to bundled". 7d TTL hardcoded. What if anh on 2-week trip + offline? Cache rejected, bundled (which is from app build date, possibly months stale) shown. UX: "Offline mode" banner is honest, OK. But document: "7d TTL was chosen for fresh-meta priority; future iteration could surface cached-but-stale via toggle".

---

## 5. Strengths (what plan got right)

1. **Existing-code reuse claims VERIFIED**:
   - `Pipeline/src/tftmac_pipeline/{jaccard,comp_grouping,comp_signature,tuning}.py` — all present, plan accurately cites them
   - `Pipeline/tests/fixtures/fetched-matches-kr-2026-04-24.json` — fixture exists
   - `SchemaVersion.isCompatible(with:)` — implemented and tested (SchemaVersionTests covers 7 cases)
   - 14 existing pytest tests claim is plausible (5 test files visible)

2. **STRIDE coverage in phase-02 is exemplary**:
   - SHA pin discipline ✓
   - Repo guard `if: github.repository == ...` ✓ (correct identifier `psychomafia-tiger/tft-hell-elo-for-macos`)
   - No `pull_request_target` ✓
   - No `${{ github.event.* }}` in run blocks (NF2) ✓
   - `permissions: contents: write` minimum ✓
   - Hand-rolled commit (no third-party action) ✓ — KISS + supply-chain
   - 24h key auto-rotation as built-in damage cap ✓

3. **Output JSON design correctly avoids PII** (phase-01 line 306). Aggregator dataclass field list excludes puuid/riotId. Phase-04 F6 makes this a test assertion. Good defense-in-depth.

4. **Schema additive bump** (1.0.0 → 1.1.0) respects backwards-compat semantically. SchemaVersion.isCompatible logic tolerates minor forward 10-window. (Reviewed `App/TFTMac/Models/SchemaVersion.swift:20-28`.)

5. **Rollback plan per phase** mostly graceful (caveat: C2 above breaks the Phase-03 rollback claim).

6. **Test strategy split (CI fixtures vs local smoke)** correctly avoids 24h dev-key flake in CI. Smart.

7. **Aggregator atomicity**: phase-01 line 198 "NEVER overwrite data/tier-list.json with empty/error output" + "Workflow stops on exit !=0 → previous good JSON preserved" is the right durability invariant.

8. **`.env` correctly gitignored** (`.gitignore:42`). `.env.example` template referenced (lines 51-54 of handoff). No secret in repo at HEAD.

9. **KISS adherence overall good**: chose raw GitHub URL over CDN/R2, hand-rolled bash commit over third-party action, fixture tests over live API. No over-engineering.

10. **Phase Completion Protocol coverage**: phase-04 F13-F16 maps 1:1 to CLAUDE.md lines 110-115. Verified.

---

## 6. Unresolved questions (escalate to anh)

1. **DataManager rewire scope** (C1): does anh accept that "DataManager from enum to ObservableObject" is a 6-file refactor touching TFTMacApp, OverlayWindowController, TierListPopover, plus 2 test files (DataManagerTests + OverlayWindowControllerTests potentially)? Phase-03 effort estimate 3h likely under by 1-2h. Either bump effort to 5h or split into Phase-03a (model+service rewire) and Phase-03b (UI anomaly chips).

2. **Bundled JSON rollback contract** (C2): does anh prefer (a) `decodeIfPresent` graceful decoder (preserves rollback) or (b) lockstep schema bump (simpler invariant, breaks rollback)? Recommend (a). Anh chốt before phase-03 starts.

3. **Workflow "data drift" detection**: should workflow alert anh (e.g. send email via `actions/github-script` to open issue) if play_rate distribution shifts wildly between consecutive runs? Defers to v0.2 — out of scope, but flag now so anh decides whether to instrument observability hooks in phase-01 dataclasses (cheap to add early, expensive to retrofit).

4. **Output JSON commit cadence**: 12h cron × 365 days = 730 commits/year to default branch. Each commit ~50KB JSON diff. 1 year = ~36 MB git history bloat just for tier-list.json. Acceptable for v0.1, but plan should note: at year 2-3, consider rewriting history or moving to GitHub Pages deploy (separate branch, force-push) to keep main branch clean. Not urgent.

5. **Failed-key silent stale**: phase-02 line 195 risk row says "anh sees red X in Actions UI". But anh travels / sick / etc. → data goes stale 24-72h. App fallback chain handles this gracefully (offline banner). But should workflow attempt to send anh notification (GitHub mobile push on failure is built-in if anh's notifications are on)? Document expected anh-action-on-red-X SLA.

---

## 7. Files spot-checked during review

- `App/TFTMac/Services/DataManager.swift` (39 LOC, enum)
- `App/TFTMac/Models/Comp.swift` (29 LOC, no anomalies field)
- `App/TFTMac/Models/SchemaVersion.swift` (44 LOC, isCompatible verified)
- `App/TFTMac/Models/TierList.swift` (48 LOC, custom decoder)
- `App/TFTMac/Models/Champion.swift` (20 LOC)
- `App/TFTMac/TFTMacApp.swift` (108 LOC, eager-init pattern)
- `App/TFTMac/Views/CompCard.swift` (147 LOC, CompCardV2)
- `App/TFTMac/Views/TierListPopover.swift`
- `App/TFTMac/Views/CompListView.swift` (55 LOC)
- `App/TFTMac/Views/HeaderBar.swift` (46 LOC)
- `App/TFTMac/Views/Banners.swift` (18 LOC, stub)
- `App/TFTMac/Views/OverlayWindowController.swift` (155 LOC, holds let tierList)
- `App/TFTMac/Resources/sample-tier-list.json` (schema 1.0.0)
- `App/TFTMacTests/DataManagerTests.swift` (44 LOC)
- `App/TFTMacTests/SchemaVersionTests.swift` (61 LOC, 7 cases)
- `App/TFTMacTests/TierListDecodingTests.swift` (excerpt, JSON literal hard-coded)
- `Pipeline/src/tftmac_pipeline/__init__.py` (bare `__version__`)
- `Pipeline/scripts/fetch_riot_sample.py` (172 LOC, prototype)
- `Pipeline/pyproject.toml` (asyncio_mode auto, deps pinned)
- `Pipeline/tests/test_riot_schema_parse.py` (excerpt, schema lock tests)
- `.gitignore` (line 42 = `.env` gitignored ✓)
- `CLAUDE.md` lines 108-122 (Phase Completion Protocol)
- All 4 plan files + handoff

---

**Status**: DONE_WITH_CONCERNS
**Summary**: Plan architecture is correct and security defenses comprehensive; 4 critical issues (C1 DataManager refactor scope underestimated, C2 anomalies decode strategy breaks rollback, C3 workflow needs PII grep guard, C4 SHA-comment convention) need fixes before phase-01 starts.
**Verdicts**: ARCHITECTURE=APPROVE_WITH_CHANGES | SECURITY=APPROVE_WITH_CHANGES
**Critical blockers count**: 4
**Report path**: /Users/mac/Desktop/TFTTACTICS FOR MACS/plans/reports/code-reviewer-260425-1831-data-pipeline-arch-security.md
