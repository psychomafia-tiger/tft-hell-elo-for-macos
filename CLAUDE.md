# TFT Mac Companion — Project Instructions

## Communication Language Rules

**IMPORTANT — apply to EVERY response trong project này**:

Khi viết responses cho user, mọi **English word/phrase/technical term** xuất hiện PHẢI được kèm theo **nghĩa tiếng Việt trong ngữ cảnh** ngay trong ngoặc đơn `()`.

**Mục đích**:
1. User hiểu trọn context (ngữ cảnh đầy đủ)
2. User rèn luyện phản xạ tiếng Anh trong khi build (xây) sản phẩm

**Format**: `English term (nghĩa tiếng Việt theo ngữ cảnh)`

**Examples**:
- "Ta sẽ ship (phát hành) v0.1 trong 2 weekends (cuối tuần)."
- "Retention (mức giữ chân user) là primary KPI (chỉ số ưu tiên), không phải revenue (doanh thu)."
- "Build (xây) menu bar popover (cửa sổ bật lên từ thanh menu) với SwiftUI (framework UI của Apple)."

**Scope**:
- Áp dụng cho mọi English technical term (thuật ngữ kỹ thuật tiếng Anh)
- Áp dụng cho mọi English common phrase (cụm từ thường gặp tiếng Anh) — examples: ship, weekend, retention, wedge, pain point, workaround, stakeholder, tradeoff, premise, etc.
- Không áp dụng cho file paths (đường dẫn file), code identifiers (tên biến/hàm trong code), hoặc product names (tên sản phẩm như TFTactics, SwiftUI, Riot).
- Giải thích lần đầu xuất hiện trong response; lần sau trong cùng response không cần lặp lại.

**Anti-pattern (cách làm sai)**:
- ❌ "Ship app trong 2 weekends"
- ❌ "Ship (send) app trong 2 weekends (week-ends)"  ← dịch word-for-word
- ✅ "Ship (phát hành) app trong 2 weekends (cuối tuần)"  ← nghĩa trong ngữ cảnh

## Plain-language Explanation Rule

**IMPORTANT — apply to EVERY response AND every skill output trong project này**:

Khi thảo luận về algorithm (thuật toán), technical design (thiết kế kỹ thuật), statistical logic (logic thống kê), API behavior (hành vi API), hoặc complex data flow (luồng dữ liệu phức tạp) — LUÔN kèm theo 1 câu/đoạn giải thích dễ hiểu với ví dụ cụ thể.

**Mục đích**: User dễ hình dung bản chất vấn đề mà không cần đọc kỹ code, công thức, hay API docs.

**Ưu tiên format (theo thứ tự)**:
1. **Ví dụ bằng số cụ thể** (concrete numerical example) — ưu tiên cao nhất
2. **Analogy trực quan** (so sánh với đời thực / game experience) — khi số khó minh họa
3. **Before/after minh họa** — khi explain behavior change (thay đổi hành vi)

**Examples cho TFT Mac Companion context**:

- ❌ "Dùng play_rate threshold để xác định tier S"
  ✅ "Aggregate (tổng hợp) 1000 Challenger matches, comp 'Storm Quickdraw' xuất hiện 127 lần → play_rate = 12.7%. Rule: tier S khi play_rate ≥10% AND avg_placement ≤4.0 → comp này qualify cho tier S"

- ❌ "Riot Dev key rate limit đủ cho v0.1"
  ✅ "Dev key = 100 req / 2 min = ~50 req/min. Fetch 1000 matches mỗi 12h cycle → cần ~20 phút sequential (tuần tự), hoặc 10 phút với 2 parallel workers (worker chạy song song) → safe trong budget"

- ❌ "App launch phải nhanh"
  ✅ "Target <500ms launch. Analogy: mắt người cảm nhận 100ms = 'instant' (tức thời), 500ms = 'snappy' (nhanh gọn), >1s = 'sluggish' (ì ạch). Electron apps ~2-3s (sluggish), SwiftUI native ~200-400ms (snappy) → target khả thi"

- ❌ "Cmd+Shift+T toggle popover"
  ✅ "Before: user alt-tab TFT → Chrome (3-5s, mất focus trong game). After: Cmd+Shift+T popover hiện ~200ms, user stay in-game → giữ decision window (cửa sổ quyết định) trong round 2-1 khi chọn augment"

- ❌ "Weighted average cho tier calculation"
  ✅ "Weighted average: data mới patch weight 1.0, data 3 days trước weight 0.5 (cũ thì giảm trọng số). Ví dụ: comp A có play_rate 15% hôm nay, 10% ba ngày trước → weighted = (15×1.0 + 10×0.5) / (1.0 + 0.5) = 13.3%. Kết quả: comp mới trending (đang lên) sẽ reflect nhanh hơn trong tier list"

**Scope áp dụng cho các technical domain sau**:
- Data pipeline logic (tier calculation, sample size, statistical confidence)
- Riot API interaction (rate limits, batching strategy, retry logic, PUUID lookup)
- SwiftUI/AppKit behavior (NSWindow levels, popover lifecycle, NSStatusItem, global hotkey handling)
- Performance budgets (launch time, memory ceiling, bundle size, network timeout)
- Cron cadence decisions (12h vs 6h refresh, stale data threshold)
- Distribution mechanics (Gatekeeper quarantine, xattr workaround, notarization)
- Analytics event schema (PostHog event properties, consent flow)

**Skill enforcement (áp dụng cho gstack skills)**:
Khi invoke (gọi) office-hours, plan-ceo-review, plan-eng-review, design-consultation, hoặc bất kỳ gstack skill nào produce technical discussion — Claude phải:
1. Include (đính kèm) rule này vào skill prompt/args khi invoke
2. Post-process (xử lý sau) skill output: nếu skill output thảo luận technical topic mà không có ví dụ số cụ thể / analogy / before-after, Claude reformat và thêm minh họa trước khi trả response cho user

**Anti-pattern**:
- ❌ "Dùng weighted average để calculate tier" (không ví dụ)
- ❌ "Weighted average: sum(x_i × w_i) / sum(w_i)" (formula không kèm số thực)
- ✅ Xem example "Weighted average" ở trên — có số + kết quả + implication (hệ quả)

## Project Context

- **Product**: TFT Mac Companion — native macOS menu bar app (ứng dụng thanh menu native cho macOS) hiển thị TFT tier list + augment cheat sheet
- **Current status**: Design doc APPROVED (được duyệt), v0.1 scope locked (phạm vi đã chốt)
- **Active design doc**: `./docs/design-v0.1-menu-bar-popover.md` (bản copy trong project) + `/Users/mac/.gstack/projects/TFTTACTICSFORMACS/mac-main-design-20260423-181953.md` (gstack canonical, cho skill discovery)
- **Research reports**: `./docs/research-macos-tft-overlay-landscape.md`, `./docs/research-tftactics-mechanism-deepdive.md`
- **Current phase**: Pre-implementation (chuẩn bị trước khi code) — đang ở The Assignment stage (giai đoạn làm bài tập verify trước khi code)

## Stack Decisions (đã chốt)

- **Language/Framework**: SwiftUI native
- **Data pipeline**: Riot Match-v5 API + GitHub Actions cron job
- **Analytics**: PostHog free tier, opt-in consent (đồng ý tham gia)
- **Distribution**: Direct .dmg unsigned trên GitHub Releases (v0.1)
- **Hotkey**: Cmd+Shift+T

## Primary KPI

10 người thật (founder + 9 testers) mở app ≥3 lần/tuần × 4 tuần liền. Retention (mức giữ chân) trước, revenue (doanh thu) sau.

## Naming

- **User-facing name**: `TFT Hell Elo` (display name, menu bar label, Finder/Dock)
- **Bundle ID**: `io.psychomafia.tfthellelo` (owner `psychomafia-tiger`, indie prefix)
- **Code target retained**: Xcode target `TFTMac`, `@main struct TFTMacApp`, scheme `TFTMac` — rename tầng code (đổi tên tầng code) sẽ break XCUITest hardcoded references + `@testable import TFTMac` trong 5+ test files, không đáng (not worth). Chỉ rename user-facing layer.
- Rule: user-facing strings = "TFT Hell Elo"; code identifiers = "TFTMac" (legacy retained).
- Details: `docs/naming-conventions.md` (migration note cho 10 existing testers).

## Phase Completion Protocol (BẮT BUỘC)

Sau mỗi phase complete, agent PHẢI update 4 files trong `docs/` (append-only cho changelog/bugs-log, không replace):

1. **`docs/system-architecture.md`** — sync overall diagram nếu phase đổi cấu trúc cấp cao (high-level structure changes only)
2. **`docs/{phase-name}-architecture.md`** — phase-specific deep-dive (Mermaid diagram + flow + design decisions). Example: `docs/data-pipeline-architecture.md`
3. **`docs/project-changelog.md`** — APPEND entry với format `## [version-slug] — YYYY-MM-DD` + sections `### Added` / `### Changed` / `### Fixed` / `### Architecture impact`. NEVER replace previous entries.
4. **`docs/bugs-log.md`** — APPEND bugs phát hiện trong phase với status `✅ Fixed` / `⏳ Deferred` / `❌ Unfixed`. Format: Bug #NNN — title, Status, Phase, Symptom, Root cause, Fix/Workaround, Lesson.

**Verification trước commit**: `grep -c "^## " docs/project-changelog.md` phải tăng ≥1 so với HEAD~1.

**Why**: mọi agent (bao gồm anh "ngày mai" sau context reset) đều cần ground truth (nguồn sự thật) để continue (tiếp tục) phase mà không reverse-engineer (ngược-kỹ thuật) từ git log. Bugs-log đặc biệt quan trọng — Wave 5d TCC cdhash bug mất 4 hours diagnose vì không có precedent log.

**Scope**: rule này áp dụng cho tất cả implementation phases từ data-pipeline-real-riot trở đi. Skip cho hotfix nhỏ <5 LOC change (không tính là "phase").
