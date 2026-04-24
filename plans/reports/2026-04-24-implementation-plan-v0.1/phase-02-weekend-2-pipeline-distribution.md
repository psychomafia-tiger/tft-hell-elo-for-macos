# Phase 2 — Weekend 2: Pipeline + R2 + Distribution

**Status**: blocked by Phase 1
**Duration**: 2 days
**Gate**: Cron runs 2x successfully without fail, app fetches từ R2, install.sh installs .dmg end-to-end

## Context Links

- Spec §Operations Spec (Cron Pipeline, Riot API, R2 Setup)
- Eng review §1.3 (rate limit), §1.5 (lock file), §1.7 (LKG), §1.8 (failure table)
- Phase 0 outputs: `docs/pre-spike-api-verify.md`, `docs/pre-spike-algo-tuning.md` (locked threshold)

## File Structure (extend)

```
Pipeline/
├── src/tftmac_pipeline/
│   ├── riot_client.py                     # aiohttp + aiolimiter rate limiting
│   ├── pipeline.py                        # End-to-end orchestration
│   ├── fetch_ladder.py                    # 4 regions × Challenger ladder
│   ├── fetch_matches.py                   # PUUID → match IDs → match data
│   ├── validator.py                       # LKG promotion gate
│   ├── r2_uploader.py                     # boto3 S3-compat client
│   ├── error_reporter.py                  # Status file + osascript notification
│   └── lockfile.py                        # Prevent concurrent runs
├── tests/
│   ├── test_riot_client.py
│   ├── test_rate_limiter.py               # Token bucket burst + 429 retry
│   ├── test_validator.py                  # LKG gate (<10 comps rejected)
│   ├── test_r2_uploader.py                # boto3 stub + ETag + cache-control
│   ├── test_lockfile.py                   # Concurrent blocked, stale reclaimed
│   ├── test_error_reporter.py             # Flag + notification invoked
│   └── integration/
│       └── test_fetch_loop_mocked.py      # 100 fixture matches → snapshot
└── scripts/
    ├── run_pipeline.py                    # launchd entrypoint
    └── install_launchd.sh                 # Writes plist to ~/Library/LaunchAgents/

Distribution/
├── launchd/
│   └── com.tftmac.pipeline.plist          # Cron schedule 6am+6pm UTC
├── build-dmg.sh                           # Manual xcodebuild + hdiutil
└── README.md                              # Tester onboarding

~/.tftmac/env                              # Founder-local (gitignored, chmod 600)
~/TFTMac/config/comp-names.json            # Manual curated 30 archetypes
```

## Tasks Summary (TDD-ordered)

**Rescue action cross-reference** (CEO review F2.1): Every task implementing a codepath MUST re-read its row trong eng review §1.8 failure table TRƯỚC khi viết rescue logic. Summary table (copy from eng review §1.8):

| Codepath | Failure scenario | Rescue action | User-visible |
|---|---|---|---|
| `fetch_challenger_ladder` | Riot 503 | Retry 3x exponential | Silent (log only) |
| `fetch_puuid_batch` | 1-2 PUUIDs 404 (deleted accts) | Skip + continue | Silent (log only) |
| `fetch_match_batch` | >20% match fetches fail | Abort run, no R2 upload | Stale banner after 24h |
| `detect_comps` | Threshold mis-tune → 50 groups | **Validator gate catches** (Task 2.2) | LKG kept, no regression |
| `upload_r2` | R2 transient 5xx | Retry 3x exponential | Stale banner after 24h |
| `upload_r2` | 403 Permission Denied | `report_critical_error` + abort, NO retry | osascript notification |
| `DataFetcher.fetchFromR2` (app) | Network timeout >10s | Cache fallback | Graceful banner |
| `validateSchema` | Major version bump | Reject + cache fallback | "App needs update" banner |
| `cacheRead` | Disk corruption mid-read | Reject + refetch | Brief loading spinner |
| `GlobalHotkey` register | Cmd+Shift+T bound elsewhere | Warning dialog on launch | Warn + allow rebind v0.1.1 |

### Task 2.1: Rate limiter + retry (Eng review §1.3)
- `test_rate_limiter.py`: Token bucket 100/120s, burst 20, refill correct
- `test_rate_limiter.py`: 429 response → respect `Retry-After` header
- Impl: wrap `aiolimiter.AsyncLimiter` + retry decorator
- Commit

### Task 2.2: TDD validator (LKG promotion gate, Eng review §1.7)
**Test cases**:
- ≥10 comps + ≥8 S/A + ≥10 with sample≥200 → PROMOTE (return True)
- 5 comps → REJECT (insufficient variety)
- 10 comps but only 3 S/A → REJECT (tier imbalance)
- 10 comps, 8 S/A, 7 with sample≥200 → REJECT (low sample)

### Task 2.3: TDD tier calculator (spec §Tier Calculation Rules)
**Test cases** — concrete spec formula:
- `play_rate=0.127, avg_place=3.82, sample=1884` → "S"
- `play_rate=0.062, avg_place=4.15, sample=920` → "A"
- `play_rate=0.031, avg_place=4.55, sample=460` → "B"
- `play_rate=0.02, avg_place=4.7, sample=75` → excluded (sample <100)
- `play_rate=0.005, avg_place=4.0, sample=200` → excluded (play_rate <0.01)

### Task 2.4: TDD carry detector + REGRESSION test (Eng review §3.3)
**Test cases**:
- Heuristic: cost≥3 AND items≥2 → is_carry=True
- Filler unit (cost=1, items=1) → False
- Non-carry 3-cost (cost=3, items=0) → False
- **★ REGRESSION**: 2-cost 3-star Ezreal reroll với manual override → is_carry=True
- Override trumps heuristic (if `comp-names.json` has `manual_carry_override`)

### Task 2.5: TDD augment aggregator (spec §Suggested Augments)
**Test cases**:
- 1884 matches, 4 augments with sample ≥30 → top 3 by avg_place
- Tied avg_place → deterministic secondary sort (alphabetical)
- All augments sample <30 → empty result
- Augment avg_place WORSE than comp baseline → excluded

### Task 2.6: TDD lockfile (Eng review §1.5)
**Test cases**:
- No existing lock → acquire succeeds, file exists
- Active lock <5h → acquire fails, exit 0 (log-only)
- Stale lock >5h → reclaim succeeds
- Lock released on release() even if exception raised mid-pipeline (finally-block)

### Task 2.7: TDD error reporter (Eng review §2.3)
**Test cases**:
- `report_critical_error("key-expired", ...)` writes `status/key-expired.flag`
- Timestamp + message in flag JSON
- osascript invoked when `notify_user=True`
- Notification failure (e.g. stdout captured) does not raise

### Task 2.8: Riot API client (aiohttp integration)
- `fetch_challenger_ladder(region)` — 1 request per region, 4 regions
- `fetch_puuid_batch(summoner_ids)` — sequential via rate limiter
- `fetch_match_ids_by_puuid(puuid, count)` — with limit
- `fetch_match(match_id)` — with 429 retry
- Mock aiohttp with fixtures from Phase 0 Action #3

### Task 2.9: Integration test — end-to-end fetch loop
- `test_fetch_loop_mocked.py`: 100 fixture matches → full pipeline → tier-list.json snapshot
- Compare vs `tests/fixtures/expected-output.json` (hand-verified)
- Locks behavior contract across refactors

### Task 2.10: R2 uploader
**Test cases** (mocked boto3):
- Upload with `cache-control: public, max-age=300` header
- ETag returned on success
- Transient 5xx → retry 3x exponential
- Permission denied (403) → report_critical_error + no retry
- LKG promote only if validator.validation_gate returns True

### Task 2.11: launchd plist + install script (CEO review F1.2 patched)

**Problem**: launchd plist không expand env vars. Hardcoded path với spaces (`/Users/mac/Desktop/TFTTACTICS FOR MACS/...`) = fragile. Nếu founder move repo → plist breaks silently.

**Fix**: Template + install-time substitution. Install script resolves real path và generates final plist.

- `Distribution/launchd/com.tftmac.pipeline.plist.template`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "...">
<plist version="1.0">
<dict>
    <key>Label</key><string>com.tftmac.pipeline</string>
    <key>ProgramArguments</key>
    <array>
        <string>__PROJECT_ROOT__/Pipeline/.venv/bin/python</string>
        <string>__PROJECT_ROOT__/Pipeline/scripts/run_pipeline.py</string>
    </array>
    <key>StartCalendarInterval</key>
    <array>
        <dict><key>Hour</key><integer>6</integer><key>Minute</key><integer>0</integer></dict>
        <dict><key>Hour</key><integer>18</integer><key>Minute</key><integer>0</integer></dict>
    </array>
    <key>StandardOutPath</key><string>__HOME__/TFTMac/logs/pipeline.log</string>
    <key>StandardErrorPath</key><string>__HOME__/TFTMac/logs/pipeline.err</string>
    <key>RunAtLoad</key><false/>
</dict>
</plist>
```
- `Pipeline/scripts/install_launchd.sh`:
```bash
#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT=~/Library/LaunchAgents/com.tftmac.pipeline.plist
mkdir -p ~/TFTMac/logs ~/Library/LaunchAgents
sed -e "s|__PROJECT_ROOT__|${PROJECT_ROOT}|g" \
    -e "s|__HOME__|${HOME}|g" \
    "${PROJECT_ROOT}/Distribution/launchd/com.tftmac.pipeline.plist.template" > "$OUT"
launchctl unload "$OUT" 2>/dev/null || true
launchctl load "$OUT"
echo "✓ Loaded. Verify: launchctl list | grep tftmac.pipeline"
```
- Manual test: `launchctl list | grep tftmac.pipeline` shows loaded + PID 0 (idle awaiting cron)

**Eng review §1.8 Rescue cross-ref for Task 2.11 codepaths**:
- `fetch_challenger_ladder` 503 → retry 3x exponential (eng review row 1)
- `fetch_match_batch` >20% fail → abort run, no R2 upload (eng review row 3)

### Task 2.12: Cloudflare R2 setup (founder-manual, 20 min)
- Spec §Cloudflare R2 Setup steps 1-6
- Output `~/.tftmac/env` với R2 credentials (chmod 600, gitignored)
- Test upload via `aws s3 cp --endpoint-url=...` manual check
- Copy public URL to app `DataManager.R2_URL` constant

### Task 2.12a: Secret leak prevention (CEO review F3.1)

**Why**: Solo founder, no reviewer catches accidental `git add` của `.env` file. Riot Production key + R2 write credentials leak = manual rotation + possible Riot account suspension.

- [ ] **Step 1: Defense in depth - 3 layers**

**Layer 1 — .gitignore entries**:
```
# /Users/mac/Desktop/TFTTACTICS FOR MACS/.gitignore
.tftmac/
.env
*.env
.env.*
~/.tftmac/
```

**Layer 2 — pre-commit hook via `detect-secrets`**:
```bash
# Install (one-time)
pip install --user detect-secrets

# Create baseline
cd "/Users/mac/Desktop/TFTTACTICS FOR MACS"
detect-secrets scan > .secrets.baseline

# Add git hook
cat > .git/hooks/pre-commit <<'EOF'
#!/bin/bash
detect-secrets-hook --baseline .secrets.baseline $(git diff --cached --name-only)
EOF
chmod +x .git/hooks/pre-commit
```

**Layer 3 — Home-outside-repo rule**:
`~/.tftmac/env` lives OUTSIDE repo root → `git add .` không bao giờ reach nó. Rule enforced naturally bởi paths.

- [ ] **Step 2: Test leak detection**
```bash
echo "RIOT_API_KEY=RGAPI-test-fake-should-trigger" > ~/.tftmac/env
cd "/Users/mac/Desktop/TFTTACTICS FOR MACS"
git add -A && git status  # Expect: .tftmac/env NOT listed
# Paste fake key into a source file for hook test:
echo "api_key='RGAPI-test-fake-1234'" > /tmp/leak-test.py
cp /tmp/leak-test.py Pipeline/src/
git add Pipeline/src/leak-test.py
git commit -m "test leak"  # Expect: pre-commit hook blocks với "Potential secret found"
rm Pipeline/src/leak-test.py
```

- [ ] **Step 3: Rotation runbook** (docs/riot-key-rotation.md):
  - Compromise detected → Riot Developer Portal → Regenerate key immediately
  - Update `~/.tftmac/env` with new key
  - `launchctl unload + load` plist để pickup env
  - Run `git log -S 'RGAPI-' --all` to audit historical exposure
  - Nếu historical leak → `git filter-repo` rewrite (destructive) + force-push

### Task 2.13: App fetch integration (wire Phase 1 → R2)
- Replace `DataManager.loadHardcoded()` với `DataManager.fetchFromR2()`
- ETag cache: store `If-None-Match` header → 304 skip re-decode
- Fallback chain per eng review §1.7 (tier-list → cache <24h → LKG → cache any age → empty)
- XCTest updates: mock URLProtocol for HTTP stubs

### Task 2.14: Build .dmg manually
- `Distribution/build-dmg.sh`:
```bash
#!/bin/bash
set -euo pipefail
xcodebuild -scheme TFTMac -configuration Release -derivedDataPath build/
create-dmg --volname "TFTMac" --window-size 500 300 \
  build/TFTMac.dmg build/Build/Products/Release/TFTMac.app
```
- Pre-req: `brew install create-dmg`
- Manual verification: install .dmg trên founder Mac via install.sh

### Task 2.15: First cron dry run + observe
- Trigger manual: `.venv/bin/python scripts/run_pipeline.py`
- Expected: ~4h runtime với Dev key (eng review §1.3 math)
- Inspect `~/TFTMac/logs/pipeline.log` for errors
- Verify `tier-list.json` uploaded to R2
- Verify app fetches new data on next launch

## Success Criteria (Phase 2 gate)

- [ ] All Task 2.x pytest tests green (~30 unit + 2 integration)
- [ ] launchd cron loaded + 2 consecutive runs without fail (24h observation)
- [ ] R2 `tier-list.json` + `tier-list-lkg.json` both present
- [ ] App fetches R2 on launch, falls back to cache correctly (manual disconnect test)
- [ ] .dmg builds + install.sh installs end-to-end on clean Mac (founder's secondary Mac if available, else test în VM)
- [ ] Pipeline runtime ≤5h với Dev key (buffer vs 12h cadence)

## Next Phase

→ `phase-03-testing-ship-v0.1.md` — full QA + tester recruitment + ship.
