# Dynamic Calculation of Temporal and Priority Scores

Status: accepted

## Context & Decision

Time-dependent values (`days_remaining`, `urgency_score`, `avoidance_score`, `priority_score`, and `isPotentiallyAvoided`) are dynamically calculated at query time by the backend application layer rather than persisted in the database. Persisting time-dependent scores creates immediate data staleness and introduces unnecessary background cron workers to keep static rows accurate.

## Considered Options

- **Option 1: Persist scores in PostgreSQL columns**: Requires periodic background workers or database triggers to constantly re-evaluate urgency across all rows as deadlines approach.
- **Option 2: Dynamic calculation on read requests (Selected)**: Persist only foundational domain facts (`deadline`, `importance`, `postpone_count`, `status`), deriving priority and avoidance status in memory when serving `/tasks/recommended` and `/dashboard`.

## Consequences

- Zero data synchronization lag between clock progression and task urgency.
- Database schema remains minimal, durable, and free of volatile derived state.
- Calculation logic is centralized within reusable domain services in the Elysia backend.
