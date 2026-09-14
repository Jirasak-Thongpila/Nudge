# 04: Explicit Postpone & Avoidance Detection

**What to build:** Users can deliberately trigger an Explicit Postpone ("เลื่อนไปก่อน") on a task, which increments `postpone_count`. The backend evaluates behavioral avoidance patterns without shaming the user, returning `isPotentiallyAvoided: true` and an Avoidance Score. The frontend displays the empathetic badge "⚠️ งานนี้อาจกำลังถูกเลื่อนซ้ำ".

**Blocked by:** 03: Dynamic Days Remaining & Task Completion

**Status:** completed

- [x] Backend endpoint `POST /tasks/:id/postpone` atomically increments `postpone_count`
- [x] Expiration of deadline does NOT increment `postpone_count` (distinction between explicit postpone and passive expiration)
- [x] Avoidance detection evaluates signals (`postpone_count`, `days_remaining`, `importance`, `status`) to set `isPotentiallyAvoided`
- [x] `avoidance_score` computed as `min(postpone_count * 2, 10)`
- [x] Flutter UI provides explicit "เลื่อนไปก่อน" button with empathetic confirmation
- [x] Flutter UI renders "⚠️ งานนี้อาจกำลังถูกเลื่อนซ้ำ" badge when `isPotentiallyAvoided` is true
- [x] Tests verify postpone counter increment and avoidance detection rules
