# Phase 02 — GitHub Actions cron (defensive workflow for PUBLIC repo)

## Context Links

- Handoff security section: `plans/reports/handoff-260425-1753-data-pipeline-phase.md` (lines 60-81)
- Phase 01 (CLI signature contract): `plan.md` + `phase-01-python-aggregator.md`
- Repo public state: `psychomafia-tiger/tft-hell-elo-for-macos`

## Overview

- **Priority**: P1 (blocks data freshness; Phase 03 fetches output)
- **Status**: pending
- **Effort**: 2h
- **Description**: GitHub Actions workflow that runs `python -m tftmac_pipeline` every 12h on cron, commits updated `data/tier-list.json` to repo. Workflow MUST defend against public-repo attack surface.

## Key Insights

1. **Public repo = attacker surface real but capped**:
   - Forks can submit PRs with malicious workflow changes — but `pull_request` (not `pull_request_target`) ensures secrets are NEVER passed to fork PR runs.
   - Workflow injection via PR title/body shell-escape — only an issue if we use `${{ github.event.* }}` interpolation in `run:` blocks. Spec forbids.
   - 24h Dev key auto-rotation = damage cap (worst-case 24h leak window before key dies).

2. **Pin actions by SHA, not tag**:
   - `actions/checkout@v4` resolves to whatever SHA the tag points to RIGHT NOW. If a third-party action is compromised, the tag silently moves and steals our secrets.
   - `actions/checkout@b4ffde65f...` (full 40-char SHA) is immutable. Compromise still possible upstream but requires deliberate code review to upgrade.
   - Concrete example: in 2024 `tj-actions/changed-files@v44` was compromised; repos using `@v44` got malware overnight, repos using SHA pin were unaffected.

3. **Cron cadence math (concrete numbers)**:
   - 12h cadence × 365 days = 730 runs/year.
   - Each run ~15-20 min = ~250 hours/year compute.
   - Free tier limit = 2000 min/month = ~24 hours/month. Public repo = unlimited free Actions minutes.
   - Conclusion: well within free tier; no cost concern.

4. **`schedule:` trigger only fires on default branch base repo**. Forks can't schedule a workflow run against the parent repo. So `schedule:` is inherently safe (no fork bypass).

## Requirements

### Functional
- [F1] Workflow triggers on cron `0 */12 * * *` (00:00 + 12:00 UTC daily) AND on `workflow_dispatch` (manual trigger for anh).
- [F2] Workflow checks out repo, sets up Python 3.11.
- [F3] Workflow installs Pipeline package: `pip install -e Pipeline/`.
- [F4] Workflow runs aggregator: `python -m tftmac_pipeline.run_aggregator --region vn2 --output data/tier-list.json`.
- [F5] Workflow uses `secrets.RIOT_API_KEY` (env var, never echoed).
- [F6] If aggregator exit !=0 → workflow fails, NO commit. Previous good `data/tier-list.json` preserved.
- [F7] If `data/tier-list.json` unchanged byte-wise (rare — same data window snapshot) → skip commit (no-op git).
- [F8] If changed → commit with message `data: refresh tier-list.json [skip ci]` and push to default branch.
- [F9] On failure: leave failed-run record visible in Actions UI for anh to inspect.

### Non-functional
- [NF1] Workflow runs <30 min wall time (Pipeline ~20min + checkout/install ~3min + commit ~1min = ~25min).
- [NF2] Zero `${{ github.event.* }}` references in any `run:` block (workflow injection class).
- [NF3] All third-party actions pinned by full 40-char SHA, not tag.
- [NF4] Repository guard: `if: github.repository == 'psychomafia-tiger/tft-hell-elo-for-macos'` on every job (defends fork-cloned-and-renabled attack).
- [NF5] No artifacts uploaded (output committed to git, no separate artifact retention).

## Architecture

### Workflow file structure

```
.github/workflows/tft-data-refresh.yml
├── name: TFT data refresh
├── on:
│   ├── schedule: cron 0 */12 * * *
│   └── workflow_dispatch: (manual)
├── permissions:
│   └── contents: write  (only contents — no actions/packages/etc)
├── jobs:
│   └── refresh:
│       ├── runs-on: ubuntu-latest
│       ├── if: github.repository == 'psychomafia-tiger/tft-hell-elo-for-macos'
│       └── steps:
│           ├── checkout (SHA-pinned)
│           ├── setup-python 3.11 (SHA-pinned)
│           ├── install Pipeline (-e .)
│           ├── run aggregator (env: RIOT_API_KEY=secrets.RIOT_API_KEY)
│           ├── commit & push if changed (uses git CLI, not third-party action)
```

### Defensive design checklist (each row mapped to mitigation)

| Threat | Mitigation in workflow |
|--------|------------------------|
| PR title shell injection | No `${{ github.event.* }}` in any `run:` |
| Fork PR exfiltrates secrets | Use `on: schedule + workflow_dispatch` ONLY (no `pull_request`/`pull_request_target`); secrets never available to PR runs |
| Forked repo runs scheduled workflow | `if: github.repository == 'psychomafia-tiger/tft-hell-elo-for-macos'` guard |
| Compromised third-party action | Pin actions by 40-char SHA; only use first-party `actions/checkout` + `actions/setup-python` |
| Secrets leaked in logs | Don't echo env; aggregator code already log-redacts key (Phase 01 NF1) |
| Token over-permission | `permissions: contents: write` (only) — no `id-token`, no `packages`, no `actions` |
| Force-push or branch protection bypass | Default branch protection enabled (anh enables in repo settings; workflow uses regular `git push`) |

### PII grep guard sub-step (before commit) — C3 fix from code-reviewer audit

```yaml
- name: PII grep guard
  run: |
    if grep -qE '"puuid"|"riotIdGameName"|RGAPI-' data/tier-list.json; then
      echo "::error::PII or key fragment detected in JSON output — refusing to commit"
      exit 1
    fi
```

Rationale: catches aggregator bugs leaking PUUIDs / Riot API key fragments BEFORE they hit public repo. Defense-in-depth on top of 24h key auto-rotation (damage cap, not prevention). Place this step IMMEDIATELY before the commit step below.

### Commit & push sub-step (no third-party action)

```yaml
- name: Commit refreshed tier-list
  run: |
    if git diff --quiet data/tier-list.json; then
      echo "No changes to tier-list.json"
      exit 0
    fi
    git config user.name "github-actions[bot]"
    git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
    git add data/tier-list.json
    git commit -m "data: refresh tier-list.json [skip ci]"
    git push
```

Why hand-rolled instead of `stefanzweifel/git-auto-commit-action`: avoids third-party action supply-chain risk for a 6-line bash equivalent. KISS + defensive.

`[skip ci]` in commit message prevents the data refresh commit from triggering other workflows (e.g. test workflow if added later).

### Pinned action SHAs

To be resolved at workflow write time. Reference current upstream SHAs (verify before merge):
- `actions/checkout` — pin to current `v4` SHA at write time, comment with version
- `actions/setup-python` — pin to current `v5` SHA at write time, comment with version

Format:
```yaml
- uses: actions/checkout@<40-char-sha>  # v4.x.x
- uses: actions/setup-python@<40-char-sha>  # v5.x.x
```

### Action SHA-pin policy (C4 fix from code-reviewer audit)

- **Format**: full 40-char SHA, version comment AFTER the SHA for human readability (`@<sha>  # v4.x.x`)
- **Manual bump policy** (no Renovate for v0.1): review SHA changes monthly via `gh api repos/actions/checkout/git/refs/tags/v4 --jq .object.sha` or manual PR
- **No automation tools**: KISS — adding Renovate/Dependabot = extra config + PR noise. Re-evaluate when shipping 9 testers.
- **Compromise response**: if upstream action SHA changes detected unexpectedly between bump cycles, audit upstream commits before merging.

## Related Code Files

### Create
- `.github/workflows/tft-data-refresh.yml` (~55 LOC)
- `data/tier-list.json` — initial empty stub (committed before first workflow run so commit step has a file to diff)
- `data/.gitkeep` — ensure dir exists if JSON regenerated/deleted

### Modify
- None.

### Delete
- None.

## Implementation Steps

1. **Create `data/` dir** with stub JSON:
   - Write minimal valid JSON: `{"schema_version":"1.1.0","patch_version":"unknown","last_updated":"2026-01-01T00:00:00Z","data_window_hours":12,"elo_bracket":"CHALLENGER","region":"VN2","total_matches_sampled":0,"comps":[]}`.
   - This ensures app fetch on first deploy doesn't 404; gets replaced on first cron run.

2. **Resolve action SHAs**:
   - `gh api repos/actions/checkout/git/refs/tags/v4 --jq .object.sha` (or check GitHub UI). Capture exact SHA + version comment.
   - Same for `actions/setup-python/v5`.

3. **Write workflow file** per architecture spec above. Include comments explaining each defensive measure (so future maintainer doesn't "simplify" them away).

4. **Anh adds `RIOT_API_KEY` to repo Secrets**:
   - Repo Settings → Secrets and variables → Actions → New repository secret.
   - Name: `RIOT_API_KEY`, value: current dev key.
   - Anh notes: must rotate every 24h via dev portal + re-paste here. (Or: switch to Production key when approved — out of scope for v0.1.)

5. **Manual trigger first run**:
   - Push branch with workflow + commit.
   - Go to Actions tab → "TFT data refresh" → "Run workflow".
   - Watch logs; expect ~20min run, commit on success.

6. **Verify schedule registration**:
   - After merge to default branch, scheduled run appears in Actions UI within 12h. Anh confirms first auto-run ran on time.

7. **Document key rotation runbook**:
   - In `docs/data-pipeline-architecture.md` (Phase 04 deliverable), add "Daily key rotation" section: visit dev portal → regenerate key → update GitHub secret. Estimated 2 min/day.

## Todo List

- [ ] Create `data/tier-list.json` stub with schema 1.1.0 and empty comps
- [ ] Resolve current SHA pins for `actions/checkout@v4` and `actions/setup-python@v5`
- [ ] Write `.github/workflows/tft-data-refresh.yml` per architecture spec
- [ ] Anh adds `RIOT_API_KEY` to repo Secrets (manual, out-of-band)
- [ ] Push branch, manually trigger workflow via `workflow_dispatch`
- [ ] Inspect run logs for: zero key echo, exit 0, commit pushed
- [ ] Verify schedule trigger registered (visible in Actions UI calendar)
- [ ] Add 24h key rotation note to `docs/data-pipeline-architecture.md` (Phase 04)

## Success Criteria

- [ ] `workflow_dispatch` manual trigger succeeds end-to-end (Riot fetch → JSON commit)
- [ ] `data/tier-list.json` updated with non-empty comps, schema 1.1.0, recent timestamp
- [ ] `git log data/tier-list.json` shows commit by `github-actions[bot]`
- [ ] Workflow file passes `actionlint` (if installed locally; otherwise visual review)
- [ ] All third-party action references SHA-pinned (grep `@[a-f0-9]{40}` should match every `uses:` line for non-first-party actions; `actions/*` allowed `@v[0-9]` but spec-forbids)
- [ ] No `${{ github.event.* }}` references in workflow (`grep -c 'github.event' .github/workflows/*.yml` returns 0)
- [ ] Repository guard `if: github.repository ==` present on `refresh` job

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| RIOT_API_KEY leaked via fork PR | Very Low | Medium (24h cap) | No `pull_request_target`; secrets unavailable to fork PRs by design |
| Workflow injection via commit message | Low | High | No `${{ github.event.* }}` references — already in NF check |
| Third-party action compromised | Low | High | SHA pins; only 2 first-party actions used |
| Anh forgets to rotate 24h key → silent failure | High | Low | Workflow exits non-zero on 401; anh sees red X in Actions UI; runbook in docs |
| Cron drift / runner queue delay | Med | Low | 12h cadence is loose; ±30min drift OK |
| Free tier minute exhaustion | Very Low | Low | Public repo = unlimited; private = 24h/month consumption fine |
| Branch protection blocks bot push | Low | Medium | Protection rule must allow `github-actions[bot]` OR exempt this path; anh tests in setup |
| `git push` race with concurrent commit | Very Low | Low | Workflow uses simple push; on conflict next cron run will succeed |
| Empty/error JSON committed | Low | High (app fetches garbage) | Aggregator exit !=0 → workflow fails BEFORE commit step (Phase 01 NF design) |

## Security Considerations

- **Secrets handling**: `RIOT_API_KEY` exposed only as env var to aggregator step; Actions auto-redacts in logs. Phase 01 aggregator code never logs full key.
- **Repository guard**: Even if attacker forks repo + enables Actions, the `if: github.repository == ...` check prevents the fork's runs from accessing OUR Secrets (forks already can't anyway, but defense-in-depth).
- **Permissions scope**: `contents: write` only. No `id-token` (no OIDC needed). No `packages`, no `actions`. Principle of least privilege.
- **Bot identity**: `github-actions[bot]` commits, no PAT (Personal Access Token) needed. GitHub-issued GITHUB_TOKEN scoped per workflow run.
- **Anh's runbook**: 24h key rotation is the only manual security task. If anh travels / sick / etc, workflow silently fails until rotated. Document graceful-degrade: app falls back to last good `data/tier-list.json` (committed) until next successful run.

## Failure notification (Q5 anh chốt 2026-04-25)

- **Mechanism**: GitHub default email notification on workflow failure (built-in, zero extra config)
- **Anh's notification email**: norway@lab3.asia (GitHub account email)
- **Failure scenario**: anh travels for 7 days → Riot Dev key 24h expires → cron fails on day 2 → GitHub auto-emails anh → anh regenerates key on return → next cron run succeeds. App users see stale tier list during gap (graceful degrade).
- **No additional alerting** for v0.1 (no Slack webhook, no ntfy, no Discord) — KISS. Re-evaluate when shipping 9 testers (silent stale data = bad UX for them).
- **Verify enabled**: GitHub → Settings → Notifications → "Actions" section → "Failed workflow runs" checkbox ON.

## Next Steps

After Phase 02 done:
- Phase 03 (app fetch) can target the live `https://raw.githubusercontent.com/psychomafia-tiger/tft-hell-elo-for-macos/main/data/tier-list.json` URL.
- Phase 04 documents pipeline + adds key rotation runbook.

## Backwards Compatibility

- New file only (`.github/workflows/tft-data-refresh.yml`); no existing CI affected.
- `data/` directory new; no path collisions.
- Workflow can be disabled in 1 click (Settings → Actions → Disable workflow) with zero rollback risk; app falls back to bundled JSON.

## Rollback

- **Disable workflow**: Settings → Actions → "TFT data refresh" → ⋯ → Disable workflow. Last good `data/tier-list.json` remains; app continues to fetch it (now stale).
- **Delete workflow file**: revert commit. Same effect.
- **Toggle repo private**: Settings → General → Change visibility → Private. Workflow continues to run; only difference is repo invisible to public + free tier minutes capped.
