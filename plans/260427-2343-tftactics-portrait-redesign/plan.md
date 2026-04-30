# TFTactics-style Champion Portrait Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replicate TFTactics web champion portrait UI in TFT Hell Elo macOS app — cost-color border (always), 3-item overlay on carry portraits (bottom 30%), drop separate items text row.

**Architecture:** 5 phases. Phase 0 fixes a pipeline regression (Bug #008 — items[] empty due to Set 17 Riot API field rename `items`→`itemNames`) that blocks all UI work. Phases 1-3 build asset metadata, badge view, and integrate into portrait. Phase 4 cleans up legacy items row + syncs project docs.

**Tech Stack:** Swift 6 / SwiftUI, Python 3.11 (Pipeline aggregator), CommunityDragon CDN (asset host), pytest + xcodebuild for tests.

**Spec:** `docs/superpowers/specs/2026-04-27-tftactics-portrait-redesign-design.md` (commit `8ad4a35`)

**Branch:** `feat/v0.1-implementation` (current HEAD `8ad4a35`)

---

## Phase status

| # | Phase | File | Status | Estimate |
|---|---|---|---|---|
| 0 | Pipeline items fix (Bug #008) | [phase-00-pipeline-items-fix.md](phase-00-pipeline-items-fix.md) | ⏳ Pending | ~30 min |
| 1 | Asset metadata + URL builder | [phase-01-asset-metadata.md](phase-01-asset-metadata.md) | ⏳ Pending | ~40 min |
| 2 | ItemBadge view (TDD) | [phase-02-item-badge.md](phase-02-item-badge.md) | ⏳ Pending | ~30 min |
| 3 | ChampionPortrait integration | [phase-03-portrait-integration.md](phase-03-portrait-integration.md) | ⏳ Pending | ~30 min |
| 4 | Cleanup + docs sync | [phase-04-cleanup-and-docs.md](phase-04-cleanup-and-docs.md) | ⏳ Pending | ~20 min |

**Total estimate**: ~2.5 hours (initial spec said 2h; +30 min for Phase 0 surfaced during writing-plans self-review).

---

## Key dependencies

- Phase 0 is BLOCKING for Phase 1+ (no items data → no UI to test render).
- Phase 1 is BLOCKING for Phase 2+ (ItemBadge needs URL builder + catalog).
- Phases 2 → 3 → 4 are sequential.

## After completion

- Manual test: anh quit app, clear `~/Library/Caches/io.psychomafia.tfthellelo/`, relaunch. Visual compare vs TFTactics web reference screenshot.
- Phase Completion Protocol per CLAUDE.md: append `docs/project-changelog.md`, `docs/bugs-log.md` (#008 entry), update `docs/system-architecture.md`.
- Push tier-list.json to `main` after Phase 0 (one-off bypass — schedule still disabled until Phase 4 merge).
