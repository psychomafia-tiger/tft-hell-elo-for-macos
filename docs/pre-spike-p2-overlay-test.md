# Pre-Spike P2 Overlay Test — SKIPPED for v0.1

**Status**: SKIPPED (không thực hiện) — data collection (thu thập dữ liệu) deferred (hoãn) đến v0.2
**Date**: 2026-04-24
**Owner**: Founder

## Why skipped

P2 overlay test (kiểm tra hiển thị popover trên TFT fullscreen) nhằm verify (xác thực) whether (liệu) menu bar popover render được trên top của TFT fullscreen exclusive mode.

**Decision**: skip cho v0.1 vì:

1. **Not a blocker** (không phải rào cản) — phase-00 plan đã note rõ "NOT v0.1 blocker — data cho v0.2"
2. **v0.1 UX assumes windowed/borderless mode** — user alt-tab hoặc press Cmd+Shift+T khi TFT NOT ở exclusive fullscreen. Documented trong spec như known limitation (giới hạn đã biết).
3. **Effort-to-value ratio thấp** — 15 min test chỉ produce (sinh ra) screenshots, không ảnh hưởng code path nào trong v0.1.
4. **Reduce Phase 0 scope creep** (thu hẹp phạm vi Phase 0) — 10/12 gate items đã done, ưu tiên F6 wireframe (hard gate cho Phase 1 Task 1.9).

## Plain-language example

Nghĩ như thợ xây nhà — nhà chưa xong cần sơn tường (F6 wireframe), không cần test đèn rọi từ ngoài sân (P2 overlay). Ưu tiên cái nào unlock (mở khoá) bước tiếp. Overlay test sẽ deferred đến khi user feedback confirm họ thực sự cần.

## Follow-up trigger (điều kiện kích hoạt lại)

Re-open test (mở lại kiểm tra) nếu:
- 3+ beta testers report (báo cáo) không thấy popover khi TFT fullscreen exclusive
- v0.2 scope add live match tracking (theo dõi trận sống) — lúc đó overlay behavior critical (quan trọng)

## Reference

- Original plan: `plans/reports/2026-04-24-implementation-plan-v0.1/phase-00-weekend-0-pre-spike.md` § Action #5
- Future test spec (nếu reactivate): same file, Action #5 bullet list
