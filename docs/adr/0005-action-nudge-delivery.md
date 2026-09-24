# ADR-0005: Action Nudge Delivery

## Status

Accepted

## Context

The spec calls for an external nudge (§13) and the MVP definition of success includes
"Receive a Nudge" (§30), while §23 explicitly rules out a "Complex notification engine".
`CONTEXT.md` also fixes the vocabulary: this is an **Action Nudge**, not a Reminder,
Alert, Notification, or Warning. So the system must deliver a nudge that is tied to a
task the user is actually avoiding — not run a general-purpose reminder engine.

Before this decision the backend could only send a nudge when a human called
`POST /line/nudge/:taskId`. There was no scheduler, no per-user delivery state, no time
zone, and nothing preventing the same task from being pushed every day.

## Decision

1. **Scope** — one thing is built: delivery of the Action Nudge outside the app. No
   in-app notification center, no read/unread state, no separate notifications table.
   Delivery state lives on the rows it describes (`users.last_nudge_at`,
   `tasks.last_nudged_at`, `tasks.nudge_count`).
2. **Channel** — LINE OA push only, reusing the existing Flex card and LIFF deep link.
   The app runs inside LIFF, where OS-level local notifications are not available, so a
   second channel would not be a second path to the user.
3. **Trigger** — the backend stays stateless: an external scheduler (cron / hosting cron
   job) calls `POST /nudges/dispatch` with a shared secret (`x-nudge-dispatch-key`).
   `GET /nudges/preview` shows what would be sent, without sending.
4. **Worth interrupting?** — a nudge is only sent for a task that is overdue, potentially
   avoided, or due within two days while important. Waiting seven days on a fresh task
   stays silent (spec Scenario A).
5. **Frequency and quiet hours** — at most one nudge per user per local day; nothing
   between 21:00 and 08:00 in the user's own timezone (`users.timezone`, default
   `Asia/Bangkok`). A task is never nudged twice within 24 hours, and after three
   unanswered nudges it drops to every other day. Any movement on the task (postpone,
   edit, status change) resets that back-off.
6. **Answerable in the chat** — the nudge card carries quick replies, so the user can act
   without opening the app: start 10 minutes (deep link), `เลื่อนไปก่อน`
   (explicit postpone), `ทำเสร็จแล้ว` (complete). The postpone reply is the
   deliberate-postpone signal that feeds avoidance detection.

## Consequences

- Tests do not need a clock or LINE: the rules live in `src/lib/nudge.ts` as pure
  functions (`isWithinNudgeWindow`, `isSameLocalDay`, `getNudgeReason`,
  `isEligibleForNudge`, `selectDailyNudge`), and the service is constructor-injected.
- Applying the schema change is a required manual step for existing databases:
  `psql "$DATABASE_URL" -f drizzle/0001_action_nudge_delivery.sql`.
- Skipping is the normal outcome. A user with nothing urgent hears nothing, which is the
  point: the nudge stays meaningful.
- LINE OA push messages count against the account's monthly message quota, so the
  one-per-day cap also keeps the integration cheap.

## Deferred (not decided here)

- What happens when a user ignores a nudge (escalate, change channel, stay quiet).
- Deduplicating or merging duplicate tasks, and an in-app notification center.
- Measurable "does it look good" metrics (open rate, start-10-minutes rate).
