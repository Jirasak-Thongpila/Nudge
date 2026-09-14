# 03: Dynamic Days Remaining & Task Completion

**What to build:** The backend dynamically calculates Days Remaining (`deadline - current_time`) at runtime without storing it in the database. The frontend renders clear indicators ("เหลืออีก X วัน" or "เกินกำหนด X วัน") on task cards and allows users to mark tasks as `COMPLETED` or `IN_PROGRESS`.

**Blocked by:** 02: Task Creation & Task List

**Status:** completed

- [x] Backend calculation service computes `days_remaining` dynamically from UTC timestamps (ADR-0002)
- [x] Backend endpoint `PATCH /tasks/:id` allows status transitions (`NOT_STARTED` -> `IN_PROGRESS` -> `COMPLETED`)
- [x] Overdue detection returns negative days remaining without classifying task as avoided
- [x] Flutter Task Card renders "เหลืออีก X วัน" (or "เกินกำหนด X วัน") with visual urgency cues
- [x] Quick completion action on Flutter Task Card marks task as completed
- [x] Unit tests for days remaining calculation covering edge cases (same day, future dates, past dates)
