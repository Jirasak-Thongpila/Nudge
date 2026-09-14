# Client-Driven Focus Session Timer with REST Lifecycle Sync

Status: accepted

## Context & Decision

The 10-minute focus session timer is managed locally within the Flutter client, interacting with the backend via stateless REST endpoints (`POST /tasks/:id/start` or `POST /focus/sessions` and `PATCH /focus/sessions/:id`). A server-managed timer over persistent WebSockets or Server-Sent Events adds heavy connection overhead and breaks when mobile devices encounter screen lock, backgrounding, or intermittent network drops.

## Considered Options

- **Option 1: Server-driven timer via WebSockets / SSE**: Heavy connection management with fragile reconnection requirements when mobile screens turn off or apps enter background state.
- **Option 2: Client-driven timer with REST lifecycle hooks (Selected)**: The mobile application maintains countdown state and local OS notifications, dispatching REST calls only on session start, completion, or premature termination.

## Consequences

- Focus sessions run reliably offline or in the background without dropping state.
- Backend remains completely stateless and horizontally scalable.
- The `focus_sessions` table accurately records start time, actual duration, and completion status without persistent socket connections.
