# Handoff — Phase 1 Wave 2: App Scaffold Execution

**From session**: 2026-04-24 eng review session (ID `b66f72ea`)
**To session**: new Claude Code session trong cùng thư mục
**Last commit on branch**: `8742c11` (docs: lock Phase 1 eng review decisions)

---

## Project & Branch

- **Repo**: `/Users/mac/Desktop/TFTTACTICS FOR MACS`
- **Branch**: `feat/v0.1-implementation` (11 commits, base=main, clean working tree)
- **Today**: 2026-04-24
- **Ship target**: 2026-05-11 (Phase 3 end)
- **Phase 1 ship target**: end of Weekend 1 (hôm nay + mai)

## Memory auto-loaded (7 files)

Located `~/.claude/projects/-Users-mac-Desktop-TFTTACTICS-FOR-MACS/memory/`:

- `user_communication_style.md` — plain language + TFT game examples
- `feedback_iterative_scoping.md` — anh prefers "ship minimal, phát triển thêm sau"
- `feedback_user_first_product.md` — decisions grounded in observed user behavior
- `feedback_plan_review_before_execute.md` — ALWAYS plan-eng-review BEFORE superpowers execute
- `feedback_questions_vietnamese_first.md` — AskUserQuestion Vietnamese-first, English term kèm gloss
- `feedback_handoff_as_file_not_prompt.md` — handoff = file + 1-line command, not prose dump
- `project_feature_2_pivot.md` — Feature 2 đổi Augment → BIS items per core
- `project_riot_api_set_17.md` — TFT ở Set 17, augments removed

## Required reading (đọc ngay, theo thứ tự)

1. `CLAUDE.md` — communication rules (Vietnamese-first + English gloss + concrete numerical examples)
2. `plans/reports/2026-04-24-implementation-plan-v0.1/phase-01-weekend-1-app-scaffold.md` — **plan đã lock**, đọc kỹ section "Eng Review Decisions" ở đầu
3. `docs/wireframe-v0.1-standard-card.md` — locked dimensions cho CompCard Task 1.9
4. `docs/product-spec-v0.1.md` — spec với BIS items pivot
5. `docs/pre-spike-xcuitest-menubar.md` — XCUITest viability findings (Task 1.10 reference)

## Status inherited

### Phase 0 gate 12/12 PASSED

- Pipeline bootstrap + 33/33 tests green
- Jaccard threshold locked 0.70 (via sensitivity analysis)
- Riot fixture locked `Pipeline/tests/fixtures/fetched-matches-kr-2026-04-24.json` (98 KR matches)
- XCUITest spike: launch metric 194ms viable, NSStatusItem UNREACHABLE on macOS 14+
- Wireframe v2 locked `docs/wireframes/popover-styleA-v2.png` + spec doc
- Riot Production key applied (pending review ~1-4 weeks)

### Phase 1 plan qua /plan-eng-review (commit 8742c11)

4 decisions locked:

1. **Scope reduced** — Task 1.4 (CacheStore) CUT. Task 1.5 DataManager = `loadBundledJSON()` only. Task 1.6 IconState = single `.default` case. Full cache + fallback chain defer Phase 2 Task 2.13 khi wire R2.
2. **MenuBarExtra** (SwiftUI macOS 13+) locked — KHÔNG dùng NSStatusItem manual.
3. **App Sandbox DISABLED** trong `.entitlements` + in-app Accessibility permission prompt với deep-link `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`.
4. **Task 1.10 rewrite** per pre-spike: Track A `XCTApplicationLaunchMetric()` (CI ≤500ms, baseline 194ms) + Track B `os_signpost` trong `togglePopover()` + manual stopwatch dogfood. KHÔNG xài `app.typeKey` (pre-spike proved broken trên macOS 14+).

### Additional locks

- **Task 1.1** thêm: test target `CODE_SIGN_IDENTITY='-'` + `CODE_SIGN_STYLE=Manual`. Tạo `TFTMac/Resources/Theme.swift` tokens từ wireframe (bgPopover #1E1E1E, bgCard #2C2C2E, accentGold #FFD700, accentSilver #C0C0C0, accentBronze #CD7F32, etc.).
- **Gap fill**: tạo `TFTMac/Generated/ItemCatalog.swift` (BIS items cần icon + display name resolve).
- **UI snapshot tests deferred** Phase 3 — Task 1.11 dogfood có visual verify checklist thay thế.

## Weekend 1 budget math

- Total estimated: ~18.5h (13.5h code + 5h dogfood buffer)
- Realistic weekend: 16-20h
- Fit với buffer → primary KPI "founder ≥5 TFT sessions" bảo vệ

## Current active task: EXECUTE Phase 1 Wave 2

Sequential implementation recommended (solo founder). Nếu dispatch subagents song song, dependency lanes:

- **Lane A sequential**: 1.1 → 1.2 → 1.3 → 1.5 → 1.8
- **Lane B parallel** (sau 1.1): 1.7 HotkeyRegistrar + 1.9 CompCard UI
- **Lane C** (sau 1.8): 1.10 perf instrumentation + 1.11 dogfood

## Critical gaps flagged (đừng quên khi implement)

- **HotkeyRegistrar system-level conflict** — nếu Alfred/Rectangle/Raycast đã bind Cmd+Shift+T, HotKey register sẽ fail silently. Không test tự động được. Mitigation: alert dialog fallback với message "Cmd+Shift+T có thể bị dùng bởi app khác — check Raycast/Alfred settings nếu hotkey không work".

## Phase 1 final gate (6 items)

- [ ] All Task 1.2, 1.3, 1.5, 1.7 tests green (XCTest) — 16 cases total (SchemaVersion 5 + TierList 5 + DataManager 2 + HotkeyRegistrar 4)
- [ ] XCTApplicationLaunchMetric Track A verify launch ≤500ms
- [ ] `os_signpost` Track B emit trong `togglePopover()`
- [ ] Hardcoded `sample-tier-list.json` render đúng 10 comps S/A/B tier
- [ ] No Dock icon (`defaults read asia.lab3.tftmac LSUIElement` = 1)
- [ ] Founder dogfood ≥5 TFT sessions + visual verify mỗi session ngang `docs/wireframes/popover-styleA-v2.png`

## Commit strategy

All commits on `feat/v0.1-implementation`. Conventional commits:
- `feat(app):` code implementation
- `test(app):` XCTest additions
- `docs:` plan/spec updates

KHÔNG có AI references trong commit messages.

## Next action

Invoke `/superpowers:subagent-driven-development` pointing tới `plans/reports/2026-04-24-implementation-plan-v0.1/phase-01-weekend-1-app-scaffold.md`. Start từ Task 1.1 bootstrap.

Hoặc nếu muốn execute solo sequential: `/superpowers:executing-plans` cùng plan path.

## Report format at end of session

```
Status: DONE | BLOCKED | NEEDS_CONTEXT
Summary: Phase 1 X/11 tasks complete, N commits on branch feat/v0.1-implementation
Next: Phase 2 Wave 1 (pipeline + R2) hoặc iterate Phase 1 nếu dogfood friction ≥3 blockers
```
