# Pre-spike Action #3 — Riot API Data Structure Verification

**Status**: TODO (founder fills Day 1-2 of Weekend 0 Assignment, ~2h)
**Owner**: founder
**Blocker for**: Phase 2 pipeline code

## Purpose

Confirm (xác nhận) schema của Riot Match-v5 `participant.units[]` + `participant.augments[]` thực tế khớp với spec assumption. Mismatch sẽ break comp detection algorithm.

## Steps (founder runs)

1. Apply Dev key at `https://developer.riotgames.com/`
2. Save to `~/.tftmac/env`: `RIOT_API_KEY_DEV=RGAPI-xxx` (chmod 600)
3. Fetch Challenger ladder (pick 1 region, e.g. KR):
   ```bash
   curl -H "X-Riot-Token: $RIOT_API_KEY_DEV" \
     "https://kr.api.riotgames.com/tft/league/v1/challenger" \
     | jq '.entries[0:20] | .[] | .summonerId' > /tmp/summonerIds.txt
   ```
4. Fetch PUUID per summonerId (20 calls sequential, ~30s):
   ```bash
   for id in $(cat /tmp/summonerIds.txt); do
     curl -s -H "X-Riot-Token: $RIOT_API_KEY_DEV" \
       "https://kr.api.riotgames.com/tft/summoner/v1/summoners/$id" \
       | jq -r '.puuid'
     sleep 1.5  # rate limit courtesy
   done > /tmp/puuids.txt
   ```
5. For 1 PUUID: fetch 5 match IDs + 1 match detail
   ```bash
   PUUID=$(head -1 /tmp/puuids.txt)
   curl -H "X-Riot-Token: $RIOT_API_KEY_DEV" \
     "https://asia.api.riotgames.com/tft/match/v1/matches/by-puuid/$PUUID/ids?count=5" \
     | jq . > /tmp/match-ids.json

   MATCH_ID=$(jq -r '.[0]' /tmp/match-ids.json)
   curl -H "X-Riot-Token: $RIOT_API_KEY_DEV" \
     "https://asia.api.riotgames.com/tft/match/v1/matches/$MATCH_ID" \
     | jq '.info.participants[0]' > /tmp/sample-participant.json
   ```
6. Inspect `/tmp/sample-participant.json` — fill checklist below.

## Checklist — schema verification

Fill after inspection:

- [ ] `units[]` exists with `character_id` field (e.g. `"TFT14_Sivir"`)
- [ ] `units[].tier` exists (star level 1/2/3)
- [ ] `units[].itemNames[]` exists (3-item max, Riot Item IDs)
- [ ] `units[].rarity` exists OR cost derivable từ character_id lookup
- [ ] `augments[]` exists (3 augment IDs format `TFT14_Augment_*`)
- [ ] `placement` field (integer 1-8)
- [ ] `traits[]` exists nếu we want trait-based detection fallback

## Findings

_(Founder fills after inspection)_

- Schema matches spec assumption: [YES / NO — explain]
- Sample participant JSON: attach `/tmp/sample-participant.json`
- Notable deviations: [none / describe]
- Unit cost inference method: [field `rarity` (preferred) / character_id lookup]
- Decision: proceed with spec algorithm / adjust [describe]

## Output artifact

Commit `/tmp/sample-participant.json` to `docs/fixtures/sample-participant.json` so
Pipeline tests có fixture thật dùng.

---
**Next**: Phase 0 Action #4 (comp algorithm tuning) consumes this data.
