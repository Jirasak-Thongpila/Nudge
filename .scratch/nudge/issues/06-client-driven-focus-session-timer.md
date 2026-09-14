# 06: Client-Driven Focus Session Timer (10 Minutes)

**What to build:** Users can start a 10-minute Focus Session on a task directly from the recommendation card or task detail. The timer runs client-side on Flutter (ADR-0003), and upon completion logs a record to `focus_sessions` in the backend, followed by a decision dialog offering next steps (Continue working, Take a short break, Mark task completed).

**Blocked by:** 05: Priority Scoring & Dashboard Recommendation Hero

**Status:** ready-for-agent

- [ ] Database schema includes `focus_sessions` table (`id`, `task_id`, `started_at`, `duration_minutes`, `completed`)
- [ ] Backend endpoint `POST /tasks/:id/start` logs/initializes focus session event
- [ ] Backend endpoint `POST /focus/sessions` records completed or interrupted focus session with duration
- [ ] Flutter Focus Timer screen runs 10-minute countdown with smooth visual timer ring and pause/cancel controls
- [ ] Completion modal prompts user: "ทำต่ออีกนิด", "พักเบรกสั้นๆ", or "เสร็จงานนี้แล้ว"
- [ ] Tests verify timer ticker behavior, session logging, and task status transition if completed
