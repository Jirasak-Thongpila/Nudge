# 02: Task Creation & Task List

**What to build:** Users can create a new Task with a title, deadline, importance rating (1–5), and estimated duration (minutes), and view all their active tasks in a task list ordered by deadline.

**Blocked by:** 01: Walking Skeleton & Anonymous Device UUID Auth

**Status:** ready-for-agent

- [ ] Database schema includes `tasks` table (`id`, `user_id`, `title`, `deadline`, `importance`, `estimated_minutes`, `status`, `postpone_count`, `created_at`)
- [ ] Backend endpoint `POST /tasks` validates payload, respects current user from `x-device-uuid`, and creates task with `status: 'NOT_STARTED'` and `postpone_count: 0`
- [ ] Backend endpoint `GET /tasks` returns tasks belonging exclusively to authenticated user
- [ ] Flutter Add Task screen with title input, deadline date/time picker, importance selector (1–5), and duration input
- [ ] Flutter Task List screen displaying user's tasks
- [ ] Tests verify task creation validation, authorization isolation, and listing
