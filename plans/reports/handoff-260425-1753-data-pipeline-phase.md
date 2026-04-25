# Handoff — Phase: wire real Riot data (founder dogfood)

**Date**: 2026-04-25 17:53 ICT
**Branch**: `feat/v0.1-implementation` (HEAD: `a19b7d5`)
**Predecessor**: `handoff-260425-1724-post-wave5d-state.md` — superseded direction (anh chốt founder dogfood trước, không ship tester)

## Phase scope

Wire **real Riot Match-v5 API data** thay bundled JSON Set 17 sample. Anh dùng app trong session thật → feedback thật → refine. **Tester sau**.

Plain-language: hiện app như cuốn sách in cứng (bundled JSON). Phase này = thay bằng RSS feed live, anh mở app luôn thấy meta Set 17 mới nhất từ Challenger VN2 ladder.

## Architecture sketch (chốt — plan-eng-review xem chi tiết khi resume)

```
┌─ Riot API (anh's Dev key, vn2/sea routing) ─────────────────────────┐
│   1. fetch top-100 Challenger PUUIDs (League-v4)                    │
│   2. for each PUUID: get last 20 match IDs (Match-v5)               │
│   3. dedupe → ~1000-1500 unique TFT Set 17 matches                  │
│   4. fetch full match data per ID                                   │
└─────────────────────────────────────────────────────────────────────┘
                              ↓
┌─ Aggregator script (Python preferred, anh chọn lại nếu khác) ────────┐
│   - parse units + traits (comps), items, anomalies (Set 17 mechanic) │
│   - tier calc: play_rate, avg_placement, recency-weighted (12h)      │
│   - emit: data/tier-list.json (schema khớp App TierList model)       │
└──────────────────────────────────────────────────────────────────────┘
                              ↓
┌─ GitHub Actions cron ─ 12h cadence ─────────────────────────────────┐
│   .github/workflows/tft-data-refresh.yml                            │
│   - secrets.RIOT_API_KEY (anh add manual vào repo settings)         │
│   - run aggregator → git commit data/tier-list.json → push          │
└─────────────────────────────────────────────────────────────────────┘
                              ↓
┌─ App-side (TFTMac/Services/DataManager.swift) ──────────────────────┐
│   - URLSession fetch raw GitHub URL hoặc CDN                        │
│   - decode → replace bundled snapshot                                │
│   - fallback to bundled JSON nếu network fail (already built)       │
│   - refresh on launch + every 12h while running                     │
└─────────────────────────────────────────────────────────────────────┘
```

## Decisions chốt (anh đã trả lời)

| # | Decision | Value |
|---|---|---|
| 1 | Riot Dev API key | Anh đã có. File: `.env` ở root (gitignored, anh paste manual) + repo Secrets cho GitHub Actions |
| 2 | Schema | Set 17 reality (memory): comps + traits + items + Anomaly. NO augments. |
| 3 | Storage | GitHub raw URL — push JSON trực tiếp vào repo `data/tier-list.json` |
| 4 | Cadence | 12h cron (design doc default) |

## Setup state

- ✅ `.env.example` template committed (RIOT_API_KEY, RIOT_REGION=vn2, RIOT_ROUTING=sea)
- ✅ `.env` already in `.gitignore` line 42
- ✅ Anh đã tạo `.env` local + paste RIOT_API_KEY (verified gitignored)
- ⏳ Anh chưa add `RIOT_API_KEY` vào GitHub repo Secrets — defer đến khi deploy cron Actions

## Security context (CRITICAL — repo public)

Repo `psychomafia-tiger/tft-hell-elo-for-macos` là **PUBLIC**. Khi deploy cron Actions, fresh session phải design workflow defensive vì:

**Baseline an toàn của GitHub Secrets**:
- Encrypted at rest, không readable cho ai (kể cả anh) sau set
- Auto-redact trong logs — value xuất hiện thành `***`
- Forks PR KHÔNG nhận secrets

**Rủi ro public repo cần mitigate trong workflow**:
| Risk | Required mitigation in `.github/workflows/tft-data-refresh.yml` |
|---|---|
| Workflow injection (PR title/body shell escape) | KHÔNG dùng `${{ github.event.* }}` trong `run:` commands |
| `pull_request_target` trên fork PR | Dùng `pull_request` thường + `if: github.repository == 'psychomafia-tiger/tft-hell-elo-for-macos'` guard |
| Third-party action compromised | Pin actions bằng SHA hash, không version tag (e.g. `actions/checkout@b4ffde65f...` not `@v4`) |
| Schedule trigger từ fork | Schedule chỉ run trên default branch của base repo — không cần guard thêm |

**Built-in safety net**: Riot Dev key auto-expire 24h. Steal max 24h damage window — đáng kể giảm stake.

**3 options cho cron deployment** (anh chốt khi plan-eng-review):
1. **Public repo + Secrets + defensive workflow** (recommended với 24h key rotation safety)
2. **Toggle repo private đến v0.1 ship** (zero risk, 1 click trong Settings)
3. **Cron local trên máy anh** (key không leave machine, cần máy awake 12h)

## Pre-implementation gate (CRITICAL — per memory rule)

**Trước khi code, fresh session PHẢI**:
1. Run `/ck:plan` hoặc spawn `planner` subagent → research + design implementation plan
2. Sau plan → plan-eng-review (gstack) hoặc `code-reviewer` agent review architecture
3. Anh chốt approval → mới execute

Lý do: data pipeline có 4 layers (Riot API + aggregator + Actions + app fetch) — nếu skip plan, dễ rơi vào "thử random" như Wave 5d.

## Open architecture questions cho plan-eng-review

1. **Aggregator language**: Python (numpy/pandas tier calc dễ) vs Node (cùng ecosystem JS với app metadata)?
2. **Match-v5 rate limit budget**: 100 req/2min Dev tier — fetch 1000 matches sequential = ~20 phút. OK trong 12h cron, nhưng có timeout risk trên Actions. Cần parallel workers?
3. **Anomaly schema**: TFT Set 17 Anomaly mechanic — data structure thế nào? Per-comp Anomaly recommendation, hay separate Anomaly tier? (memory says Feature 2 pivot to item builds, nhưng chưa rõ Anomaly UI scope)
4. **App refresh strategy**: fetch on launch only, hay also background refresh every 12h while running? Battery/network tradeoff.
5. **JSON schema versioning**: nếu future schema đổi (Set 18), app cũ pin Set 17 schema crash hay graceful degrade?

## Files anticipated (fresh session sẽ touch)

```
.env                                # anh tạo, gitignored
.github/workflows/tft-data-refresh.yml   # NEW — cron pipeline
scripts/aggregator/                  # NEW — Python (or Node) aggregator
data/tier-list.json                  # NEW — committed live data
App/TFTMac/Services/DataManager.swift  # MODIFY — add network fetch path
App/TFTMac/Models/TierList.swift     # MAY MODIFY — schema for Set 17 (anomalies)
docs/data-pipeline-architecture.md  # NEW — architecture doc per design rules
```

## Resume command

```bash
cd "/Users/mac/Desktop/TFTTACTICS FOR MACS" && cat plans/reports/handoff-260425-1753-data-pipeline-phase.md
```

## Unresolved (anh chốt khi resume hoặc trong plan-eng-review)

1. Aggregator language: Python vs Node (đề nghị Python — pandas + datacls clean)
2. App refresh strategy: launch-only vs background poll
3. JSON schema versioning approach
4. Anomaly UI scope (data có, nhưng render thế nào trong CompCard hay separate view)
