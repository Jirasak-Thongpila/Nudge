-- Action Nudge Delivery (see src/lib/nudge.ts for the delivery rules)
--
-- Apply this to the Nudge database before running the nudge scheduler:
--   psql "$DATABASE_URL" -f drizzle/0001_action_nudge_delivery.sql
-- (every statement is idempotent, so re-running it is safe)

-- Each user has a timezone so a nudge can be delivered at a sensible local hour,
-- and the last delivery time caps nudges to one per local day.
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS timezone varchar(64) NOT NULL DEFAULT 'Asia/Bangkok';

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS last_nudge_at timestamptz;

-- Per-task nudge history: never nudge the same task twice in a day, and back off
-- to every other day after three nudges the user has not acted on.
ALTER TABLE tasks
  ADD COLUMN IF NOT EXISTS last_nudged_at timestamptz;

ALTER TABLE tasks
  ADD COLUMN IF NOT EXISTS nudge_count integer NOT NULL DEFAULT 0;
