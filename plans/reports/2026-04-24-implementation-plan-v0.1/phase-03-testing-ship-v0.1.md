# Phase 3 — Week 2: Testing + Ship v0.1.0

**Status**: blocked by Phase 2
**Duration**: 2-3 days
**Gate**: v0.1 shipped to founder + 3 initial testers, 0 crash first week

## Context Links

- Spec §Launch Gate
- Eng review §3.2 (test plan), §1.1 (distribution), §4 (performance gates)
- Phase 1 dogfood notes: `docs/weekend-1-dogfood-notes.md`

## Tasks Summary

### Task 3.1: Performance gate — scroll 60fps
- Xcode Instruments "Time Profiler" template
- 1000 scroll events via XCUITest `swipeUp` loop
- `XCTMeasure(metrics: [XCTClockMetric(), XCTMemoryMetric()])`
- **Gate**: 0 frame drops, memory stable ±10MB
- Fix regression if detected (likely culprit: non-lazy LazyVStack, blocking image decode)

### Task 3.2: Performance gate — launch ≤500ms
- XCUITest `measure(metrics: [XCTApplicationLaunchMetric()])`
- Polls menu bar icon existence
- **Gate**: p95 ≤500ms over 10 runs

### Task 3.3: Full test matrix (Eng review §3.2 Section 3 table)
Run all tests across 4 targets:
- `pytest Pipeline/tests/` — ~30 tests
- `xcodebuild test -scheme TFTMac -destination 'platform=macOS'` — ~15 XCTest + 4 XCUITest
- `bats Distribution/tests/` — 5 tests
- `shellcheck Distribution/install.sh` — clean

All must green. CI defer (Phase 2 launch-only local).

### Task 3.4: Edge case smoke (spec §Edge Cases table)
Manually exercise each of 10 scenarios:
- First launch no network → empty state banner
- Cache >24h → stale banner
- Cache >7 days → reject + empty
- Rate limited → pipeline graceful skip
- R2 upload fail → local stale after 24h
- Cmd+Shift+T conflict (test by installing Amphetamine with same hotkey first)
- Schema v2.0 mismatch (hand-edit local cache để force reject)
- Gatekeeper blocked .dmg → install.sh recovers

Log results to `docs/phase-3-edge-case-smoke.md`.

### Task 3.5: Founder Mac pmset wake schedule
```bash
# Spec §Mac sleep handling
sudo pmset repeat wake MTWRFSU 05:55:00
sudo pmset -a tcpkeepalive 1
sudo pmset -a standby 0   # Disable deep sleep cho reliable cron
```
Verify with `pmset -g sched` and `pmset -g`.

### Task 3.6: comp-names.json seed (30 archetypes)
- Founder manually curates 30 top comps từ TFTactics.gg Set 14
- Schema per eng review §2.2
- Commit `~/TFTMac/config/comp-names.json`

### Task 3.7: README + onboarding doc
Create `/Users/mac/Desktop/TFTTACTICS FOR MACS/README.md`:
- Project overview (1 paragraph)
- Install link: `curl -L .../install.sh | bash`
- Troubleshoot section: Gatekeeper workaround nếu install.sh fails
- Feedback channel: DM founder (Zalo/Messenger/Discord)
- Privacy: zero data collection, R2 public bucket is one-way pull

### Task 3.8: GitHub Release v0.1.0
- Tag: `git tag -a v0.1.0 -m "v0.1.0 initial private release"`
- Push tag: `git push origin v0.1.0`
- Create Release via `gh release create v0.1.0 --prerelease --draft`
- Attach: `build/TFTMac.dmg`, `Distribution/install.sh`
- Release notes: link to spec + launch gate criteria + tester contact

### Task 3.9: Ship to 3 initial testers
- Phase 0 Assignment outputs 3 committed testers (from design doc §The Assignment)
- DM each individually với install.sh URL + 2-line pitch
- Pair onboarding call 30 min với first tester (screen share install flow — catch UX bugs)
- Iterate install.sh if friction detected ≥2 testers

### Task 3.10: First-week monitor + bug triage
- Daily check `~/TFTMac/logs/pipeline.log` (no fail 2x consecutive)
- Daily `gh release view v0.1.0` (asset downloads = install count proxy)
- Weekly Sunday DM retention survey (spec §Retention Tracking)
- Bug triage: log to `docs/feedback-log.md`, fix critical in v0.1.0.patch bump

### Task 3.11: Retention tracking spreadsheet
- Create `~/TFTMac/retention.csv`:
```csv
week,tester_name,open_count,feedback_notes
2026-W17,founder,12,"dogfood baseline"
2026-W17,tester1,0,"not started"
```
- Populate weekly from DM survey responses (spec §Weekly ritual template)

## Success Criteria (v0.1 LAUNCH gate — spec §Launch Gate)

- [ ] App .dmg ship đến founder + 3 initial testers
- [ ] 0 crash trong tuần đầu tiên (monitor via `Console.app` + tester DM reports)
- [ ] Pipeline cron chạy mỗi 12h không fail 2 lần liên tiếp (48h observation window)
- [ ] Founder dogfood ≥5 TFT sessions thay thế alt-tab Chrome

## Post-ship (Week 3-4 expansion milestone)

- [ ] Recruit 6 more testers → total 10 active
- [ ] No retention regression early 3 testers
- [ ] Founder + tester DM loop tight (<24h response time)

## Post-ship (Week 4-8 retention validation — PRIMARY KPI)

- [ ] 10 testers × ≥3 opens/tuần × 4 tuần liên tiếp
- [ ] Informal survey ≥7/10 từ ≥5 testers

## Decision Gate (Month 3)

- **Retention HIT** → Phase 4 sidebar (Approach B) planning
- **Retention MISS** → Diagnose UX / feature / audience fit. DO NOT add features blindly.

---

**End of plan**. Return to overview: [plan.md](./plan.md)
