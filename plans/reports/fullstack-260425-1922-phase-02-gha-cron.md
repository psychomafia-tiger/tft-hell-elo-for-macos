# Phase 02 Implementation Report — GitHub Actions cron

**Agent**: fullstack-developer
**Date**: 2026-04-25
**Phase**: 02 — GitHub Actions cron (defensive workflow for PUBLIC repo)
**Plan**: `plans/260425-1817-data-pipeline-real-riot/`

## Status: DONE_WITH_CONCERNS

---

## Files Created

| File | Lines | Notes |
|------|-------|-------|
| `.github/workflows/tft-data-refresh.yml` | 139 | Full defensive workflow, all 7 security requirements met |
| `data/tier-list.json` | 1 | Stub JSON, schema 1.1.0, empty comps array |
| `data/.gitkeep` | 0 | Empty, ensures dir tracked in git |

---

## Security Checklist (all greps — visual verification, Bash blocked this session)

| Check | Expected | Result | Status |
|-------|----------|--------|--------|
| `grep -c '${{ github.event'` in workflow | 0 | 0 — only `${{ secrets.RIOT_API_KEY }}` present, in `env:` not `run:` | PASS |
| `grep -c 'pull_request_target'` | 0 | 0 — not present | PASS |
| `grep -E 'uses: .+@v[0-9]'` — bare version tags | 0 lines | 0 — both `uses:` lines reference 40-char SHAs | PASS |
| `grep -E 'uses: .+@[a-f0-9]{40}'` — SHA-pinned | 2 lines | 2 — checkout (line 71) + setup-python (line 77) | PASS |
| PII grep guard step EXISTS before commit step | yes, before | Lines 112-117 (PII guard) precede lines 128-138 (commit) | PASS |
| Repo guard `if: github.repository == ...` on refresh job | present | Line 64: `if: github.repository == 'psychomafia-tiger/tft-hell-elo-for-macos'` | PASS |
| `permissions:` = `contents: write` only | exactly one permission | Lines 51-52: `permissions:\n  contents: write` — no other entries | PASS |
| `data/tier-list.json` parses as valid JSON | valid | Single-line object, all 8 required fields present | PASS |
| Hand-rolled commit step (no third-party action) | run: block only | Lines 128-138: pure bash, no `uses:` | PASS |

---

## Tasks Completed

- [x] `data/tier-list.json` stub created (schema 1.1.0, empty comps)
- [x] `data/.gitkeep` created
- [x] SHA pins resolved (see Concern #1 below)
- [x] `.github/workflows/tft-data-refresh.yml` written per phase-02 spec
- [x] All 7 security requirements verified via visual inspection
- [x] All 9 checklist items passing

---

## Manual Followup Required (anh)

**Gate 3 — Add RIOT_API_KEY to repo Secrets** (out-of-band, cannot be automated):
> Repo Settings → Secrets and variables → Actions → New repository secret
> Name: `RIOT_API_KEY`
> Value: current Riot Dev API key
> Note: Dev key auto-expires 24h — anh must re-paste daily OR apply for Production key

**Verify failure email enabled**:
> GitHub → Settings → Notifications → Actions → "Failed workflow runs" checkbox ON
> Failure emails will go to: norway@lab3.asia

**First manual run after merge**:
> Actions tab → "TFT data refresh" → "Run workflow" → watch logs ~20min
> Confirm: zero key echo in logs, exit 0, commit by `github-actions[bot]` appears

**Verify schedule registration**:
> After merge to default branch, scheduled runs appear in Actions UI calendar within 12h

---

## Concerns

### Concern #1 — SHA pins sourced from training data (MUST VERIFY before merge)

**Issue**: Bash and WebFetch/WebSearch were blocked this session. SHA values used:
- `actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683` (v4.2.2)
- `actions/setup-python@a26ac4c57cafd6b9cef4f8de0bed87c21b9fdf26` (v5.5.0)

These are from training-data knowledge of widely-documented pinned SHAs.

**Required action before merge**: Anh or Phase 02 review MUST verify these SHAs are current:
```bash
# Run these and compare to the SHAs in the workflow file
gh api repos/actions/checkout/git/refs/tags/v4 --jq .object.sha
gh api repos/actions/setup-python/git/refs/tags/v5 --jq .object.sha
```
If the SHAs have advanced (new patch releases), update lines 71 and 77 in the workflow file accordingly. The version comment after `# v4.x.x` should also be updated to match.

**Impact if not verified**: Using a stale-but-valid SHA is safe (immutable), but may miss upstream security patches in the action itself. Using a wrong SHA will cause workflow failure immediately (actions/checkout will refuse to resolve) — a loud, obvious failure, not a silent one.

### Concern #2 — Phase 01 CLI must match exactly before first run

The aggregator step invokes `python -m tftmac_pipeline.run_aggregator --region vn2 --output data/tier-list.json`. This CLI signature must exactly match Phase 01's entrypoint. Phase 01 is parallel — confirm CLI contract before pushing the workflow to a branch that triggers `workflow_dispatch`.

---

## Next Steps (unblocked by this phase)

- Phase 03 (app fetch) can now target: `https://raw.githubusercontent.com/psychomafia-tiger/tft-hell-elo-for-macos/main/data/tier-list.json`
- Phase 04 (docs) must add 24h key rotation runbook to `docs/data-pipeline-architecture.md`
- Deferred (v0.2): git history bloat mitigation (730 data commits/year) — tracked as Bug #003

---

## Unresolved Questions

None. All spec decisions were pre-chốt. Only Concern #1 (SHA verification) requires anh action before merge.
