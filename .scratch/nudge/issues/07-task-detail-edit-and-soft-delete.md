# 07: Task Detail, Editing & Soft Delete

**What to build:** Users can view detailed information for any task, edit parameters (title, deadline, importance, duration), and delete a task. Deletion executes a Soft Delete (ADR-0004) marking `deleted_at`, preserving the task's historical sessions and postponement patterns.

**Blocked by:** 03: Dynamic Days Remaining & Task Completion

**Status:** ready-for-agent

- [ ] Database schema includes `deleted_at` timestamp column on `tasks` table (ADR-0004)
- [ ] Backend endpoint `PATCH /tasks/:id` allows updating task fields (title, deadline, importance, estimated_minutes)
- [ ] Backend endpoint `DELETE /tasks/:id` sets `deleted_at = now()` instead of deleting the row
- [ ] All task fetch queries (`GET /tasks`, `/tasks/recommended`, `/dashboard`) filter out soft-deleted tasks (`deleted_at IS NULL`)
- [ ] Flutter Task Detail screen with editing form, explicit postpone button, focus starter, and delete button with confirmation
- [ ] Automated tests verify soft deletion preserves records in DB while excluding them from active API responses
