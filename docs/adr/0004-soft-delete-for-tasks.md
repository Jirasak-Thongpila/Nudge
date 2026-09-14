# Soft Delete for Tasks to Preserve Focus Session History

Status: accepted

## Context & Decision

Tasks utilize a soft delete strategy via a `deleted_at` timestamp rather than physical row deletion with cascading drops. In Nudge, focus sessions and postponement history represent valuable behavioral analytics; physically deleting a task would either cascade and wipe out historical focus data or orphan relational foreign keys.

## Considered Options

- **Option 1: Hard DELETE with CASCADE**: Completely erases task and all associated `focus_sessions` records, distorting user productivity history and behavioral statistics.
- **Option 2: Soft delete with `deleted_at` column (Selected)**: The task is filtered out from active queries (Dashboard, Recommended Tasks) while preserving historical associations in `focus_sessions`.

## Consequences

- Historical focus session logs remain intact for future analytics, streaks, and review screens.
- Query filters for active tasks must consistently check `where deleted_at IS NULL`.
- Restoring accidentally deleted tasks remains technically feasible without data loss.
