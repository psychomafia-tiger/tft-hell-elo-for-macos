# Handoff — Phase 1 Wave 5: MAJOR PIVOT (overlay + UI redesign + rename)

**From session**: 2026-04-25 execute session (ID `3613b7ba`)
**To**: new Claude Code session trong cùng thư mục
**Last commit**: `c48aa59` (Wave 4 dogfood handoff)
**Trigger**: anh dogfood shortcut (Task 1.11 quick-test), flag 3 issues pivot v0.1 scope

---

## What happened

Anh build + launch app local, không chơi full 5 TFT sessions mà quick-test với 1 TFT demo round để verify overlay behavior + UI value. Kết quả test logged tại `docs/weekend-1-dogfood-notes.md`:

1. **Overlay blocker**: popover KHÔNG hiện trên TFT fullscreen + borderless mode. Chỉ work windowed.
2. **UI insufficient value**: wireframe v0.1 (4 placeholder portraits + items text row) thiếu quá nhiều so với TFTactics Windows reference (`docs/reference_image/tfttactics_windows.png`).
3. **Rename + owner correction**: app rename TFTMac → **TFT Hell Elo**, owner correction `asia.lab3` → **psychomafia**.

## Anh's decisions (chốt rồi, không phải đang cân nhắc)

### F1 — Overlay: KEEP menu bar UX + ADD fullscreen overlay
- Không pick 1 trong 3 options cũ (NSPanel-only pivot / windowed-only / hybrid)
- Anh thấy menu bar popover animation đẹp → giữ nguyên cho non-fullscreen
- Đồng thời NSPanel overlay activate được khi TFT fullscreen
- Research premise: có khả thi trên macOS không? Raycast/Alfred làm thế nào khi fullscreen game?

### F2 — UI: tất cả items critical, không có nice-to-have
Từ TFTactics Windows reference image, v0.1 phải show đủ:
- **7–8 real champion icons** (không phải 4 placeholder circles)
- **Star level** indicator (1/2/3 sao trên portrait)
- **Champion name** dưới portrait
- **Playstyle label** ("Fast 8" / "Slow Roll (5)") — nằm dưới comp name
- **Expanded view** per card: Early Comp + Traits + Carousel + Options (LV.9 alternatives) + Positioning hex board
- **Top filter bar**: Champions / Traits / Search

Consequence: wireframe v0.1 lock trong Weekend 0 cần **rewrite từ đầu**.

### F3 — Rename user-facing only + owner correction
- **Target name**: "TFT Hell Elo" (replace "TFT Mac")
- **Bundle ID**: `asia.lab3.tftmac` → cần đổi thành format có `psychomafia`, e.g. `io.psychomafia.tfthellelo` hoặc `com.psychomafia.tfthellelo` (anh chốt chính xác trong session mới)
- **Scope rename**:
  - ĐỔI: CFBundleDisplayName, CFBundleName, PRODUCT_BUNDLE_IDENTIFIER, HeaderBar text, README, wireframe docs
  - GIỮ: code target name `TFTMac`, folder `App/TFTMac/`, class name `TFTMacApp` (động quá nhiều file, risk regression)
- **MANDATORY**: note rõ rename decision + "code target name vẫn TFTMac" trong:
  - `CLAUDE.md` (top-level, để Claude sessions sau biết)
  - `docs/system-architecture.md` (nếu có) hoặc tạo `docs/naming-conventions.md`
  - Commit message explain decision

## Why `asia.lab3` was wrong

Claude hardcode sai từ đầu Wave 0 — user email trong system context là `norway@lab3.asia`, Claude infer thành business domain và set bundle ID `asia.lab3.tftmac`. Thực tế project này là **personal project của psychomafia-tiger**, không thuộc lab3.asia organization. Anh flag trong dogfood session này — cần fix trước ship.

## Current app state (chưa touch)

- 9/10 code tasks done, 21/21 unit tests pass, 242ms cold launch
- 5 commits trên branch `feat/v0.1-implementation` since wave 3 start
- App launch + popover render đúng wireframe v0.1 — chỉ không hiện trên fullscreen + UI thiếu value
- Xcode build (Debug + Release) green
- **Không rollback gì cả**. CompCard.swift + catalogs + XCUITest sẽ được **build on**, không vứt bỏ. UI redesign = extend + restructure, không rewrite from scratch.

## Recommended session-mới workflow

**CRITICAL**: theo feedback memory `feedback_plan_review_before_execute.md`, major pivot cần plan review trước execute. Đừng vội jump vào code.

### Step 1 — Research phase (first priority)
Research NSPanel + MenuBarExtra coexistence feasibility:
- Câu hỏi 1: NSPanel với `.screenSaver` level + `.fullScreenAuxiliary` collection behavior có render trên exclusive fullscreen game không?
- Câu hỏi 2: Raycast/Alfred/Spotlight làm thế nào khi fullscreen game — họ có cheat trick nào không?
- Câu hỏi 3: Apple WWDC sessions về window levels + collection behaviors (2023/2024)?
- Câu hỏi 4: Open source reference projects: sindresorhus/got, `DragonUI`, `AltTab`, `Rectangle`, `Karabiner-Elements` — nào overlay được fullscreen?
- Câu hỏi 5: Alternative approach — Screen Recording TCC permission + composite overlay (heavy) vs NSPanel?

Dùng skills: `docs-seeker` (latest Apple docs), `researcher` agent, WebSearch + WebFetch.

### Step 2 — UI redesign spec rewrite
- Read `docs/reference_image/tfttactics_windows.png` kỹ
- Rewrite `docs/wireframe-v0.1-standard-card.md` với full TFTactics format
- Consider: popover width có đủ cho 7-8 portraits + names + stars? Có thể cần 520px thay 440px
- Consider: expanded view = click-to-expand trong card hay separate detail popover?
- Lock wireframe TRƯỚC khi touch CompCard.swift

### Step 3 — Plan review (blocking gate)
Dùng 1 trong:
- `/plan-eng-review` — engineering manager mode, lock execution plan
- `/plan-ceo-review` — CEO mode, rethink premise (đã pivot rồi, có thể skip nếu eng-review đủ)

Session mới KHÔNG được skip gate này, per anh's feedback memory.

### Step 4 — Execute (only after plan approved)
Wave order suggestion:
- Wave 5a: Rename (F3) — mechanical, 30 min, safe first step
- Wave 5b: NSPanel fullscreen overlay (F1) — build + verify trong TFT fullscreen BEFORE touching UI
- Wave 5c: UI redesign (F2) — only after overlay confirmed working, build CompCard v2 from wireframe v2

### Step 5 — Re-dogfood
Anh test lại full 5 TFT sessions sau khi all 3 fixes land.

## Deferred items from Wave 3 reviews (vẫn stand)

- **CompCard a11y I1+I2** (accessibility) — batch sau UI redesign vì CompCard sẽ rewrite
- **Task 1.10 test method rename** — optional, can defer indefinitely
- **Task 1.10 README file-path polish** — nit

## Files to look at first (in new session)

Theo thứ tự:
1. `docs/weekend-1-dogfood-notes.md` — anh's actual test findings
2. `docs/reference_image/tfttactics_windows.png` — UI redesign target (view via `Read` tool, Claude multimodal OK)
3. `docs/wireframe-v0.1-standard-card.md` — wireframe hiện tại (sẽ rewrite)
4. `plans/reports/2026-04-24-implementation-plan-v0.1/phase-01-weekend-1-app-scaffold.md` — original Phase 1 plan (reference)
5. This handoff file
6. `App/project.yml` — rename targets
7. Memory: `project_v0_1_pivot_20260425.md` (auto-loaded)

## Quick commands

```bash
# Launch current app build (để re-verify starting state nếu cần)
cd "/Users/mac/Desktop/TFTTACTICS FOR MACS/App" && xcodebuild -project TFTMac.xcodeproj -scheme TFTMac -configuration Debug build && open /Users/mac/Library/Developer/Xcode/DerivedData/TFTMac-*/Build/Products/Debug/TFTMac.app

# Kill running instance trước khi rebuild
pkill -x TFTMac

# Full test suite
cd "/Users/mac/Desktop/TFTTACTICS FOR MACS/App" && xcodebuild -project TFTMac.xcodeproj -scheme TFTMac -configuration Debug test -only-testing:TFTMacTests

# Regen project sau khi thêm/xoá .swift files
cd "/Users/mac/Desktop/TFTTACTICS FOR MACS/App" && xcodegen generate
```

## Report format at end of new session

```
Status: DONE | BLOCKED | NEEDS_DECISION
Waves landed: 5a (rename) | 5b (overlay) | 5c (UI redesign) — check each
Wireframe v2 locked: YES/NO (path to updated doc)
Fullscreen overlay verified: YES/NO (anh tự test trong TFT demo)
UI re-dogfood scheduled: YES/NO
Next: Phase 2 Wave 1 (pipeline + R2) | Wave 5 extended
```
