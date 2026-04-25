# Handoff — data pipeline DONE, Gate 4 blocked on TCC permission

**Date**: 2026-04-25 23:35 ICT
**Branch**: `feat/v0.1-implementation` (uncommitted work staged for handoff commit)
**Predecessor**: `handoff-260425-1753-data-pipeline-phase.md`

## Phase status

| Phase | Status | Notes |
|---|---|---|
| 01 Python aggregator | ✅ DONE | 134 pytest pass, golden fixture generated, CLI `tft-aggregate` works |
| 02 GHA workflow | ✅ DONE | 9/9 security checks, SHA pins verified via `gh api` |
| 03 App network fetch | ✅ DONE | Build success, 80 unit + 1 UI test pass (after 5 fixes — see commit) |
| 04 Docs sync | ✅ DONE | 4 docs updated, 4 Mermaid diagrams |

## Test Gate 4 status (anh manual)

| Test | Status | Notes |
|---|---|---|
| 1 Bundled fallback | ✅ PASS | Banner cam, 10 comps render, S/A/B/C tier sorted |
| 2 Anomaly empty row | ✅ PASS | Empty chips correctly (bundled v1.0.0 has no anomalies, C2 fix) |
| **3 Cmd+Shift+T hotkey** | **❌ BLOCKED** | Silent fail — Bug #001 TCC cdhash invalidation reproduced |
| 4 Schema mismatch overlay | ⏳ NOT TESTED | Pending Test 3 unblock |
| 5 Stale cache banner | ⏳ NOT TESTED | Optional |

## Test 3 root cause + fix needed

**Symptom**: anh re-launched app via Xcode (Cmd+R), pressed Cmd+Shift+T → silent (no popover toggle).

**Root cause**: Per memory `project_tcc_cdhash_invalidation.md` — macOS Tahoe TCC re-validates Accessibility permission by cdhash. Xcode rebuild = new cdhash → previously granted permission auto-revoked. Same Bug #001 in `docs/bugs-log.md`.

**Anh's status**: tried System Settings workaround, still no toggle (gave up after 2 attempts; assumed fixed by trying but session got confused).

**Next session ACTION (do this first, no asking)**:

1. Diagnose: check if TFTMac currently in System Settings → Privacy & Security → Accessibility list. Use `tccutil` or sqlite query of `~/Library/Application Support/com.apple.TCC/TCC.db`:
   ```bash
   sudo sqlite3 /Library/Application\ Support/com.apple.TCC/TCC.db \
     "SELECT client, auth_value FROM access WHERE service='kTCCServiceAccessibility' AND client LIKE '%TFTMac%' OR client LIKE '%tfthellelo%'" 2>&1
   ```
   (Read-only query, no sudo write.)

2. Likely fix paths (try in order):
   - **Reset TCC for the bundle**: `tccutil reset Accessibility io.psychomafia.tfthellelo` then re-launch app → triggers fresh permission prompt.
   - **Add binary path manually**: System Settings → Accessibility → click "+" → navigate to DerivedData. Find via `find ~/Library/Developer/Xcode/DerivedData -name TFTMac.app -type d 2>/dev/null | head -3`.
   - **Permanent fix**: Developer ID signing (deferred Phase 2 — out of scope v0.1 dogfood).

3. After permission re-granted: re-test Cmd+Shift+T. Expect toggle <200ms.

4. Then run Test 4 (schema mismatch) — instructions in prior handoff or `phase-03-app-network-fetch.md` Step 11.

## Phase 03 fixes I applied (post agent DONE_WITH_CONCERNS)

Agent's Bash was blocked → I verified via xcodebuild:

1. Added 8 new .swift files to `App/TFTMac.xcodeproj` via Ruby xcodeproj gem (Python pbxproj broken for objectVersion=77 — see memory `project_xcode_pbxproj_sync.md`)
2. `SchemaCompatibilityGate.swift:44` — fixed `Self.appSchema` instance access
3. `DataManager.swift:86` — inlined deinit cleanup (was calling @MainActor `stop()` from nonisolated context)
4. `DataManagerTests.swift` — marked 3 test methods `@MainActor`
5. Removed 2 duplicate file refs in TFTMacTests target (pbxproj CLI failed-but-partial-add)

## Outstanding manual TODOs cho anh

| # | Task | Where | Block? |
|---|---|---|---|
| 1 | Add `RIOT_API_KEY` Secret | https://github.com/psychomafia-tiger/tft-hell-elo-for-macos/settings/secrets/actions | Block first cron run |
| 2 | Enable workflow failure email | GitHub Settings → Notifications → Actions | Optional |
| 3 | Push commit to GitHub | `git push` after handoff commit | Block remote workflow |

## Architecture state

- 4-layer pipeline complete: Riot API → Python aggregator → GHA cron → App fetch chain
- Schema: bundled stays at 1.0.0 (forward-compat decoder), remote at 1.1.0 (cron output)
- App: `enum DataManager` → `@MainActor ObservableObject` (6-file refactor cascaded)
- Security: SHA-pinned actions, repo guard, PII grep, hand-rolled commit (public repo defensive)

## Resume command

```bash
cd "/Users/mac/Desktop/TFTTACTICS FOR MACS" && cat plans/reports/handoff-260425-2335-data-pipeline-tcc-block.md
```

## Unresolved

1. Test 3 TCC permission — fresh session must diagnose + fix without asking anh redundant yes/no questions
2. Test 4-5 deferred
3. RIOT_API_KEY Secret + first cron run (anh manual, then verify workflow runs end-to-end)
