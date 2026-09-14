# Anonymous Device UUID Authentication with Deferred LINE Account Binding

Status: accepted

## Context & Decision

To provide a zero-friction experience in the mobile MVP without forcing immediate registration, the Flutter client generates a persistent Device UUID stored in secure local storage and passes it via the `X-Device-Id` HTTP header. The backend transparently creates or resolves the corresponding user record on request, deferring explicit account identity until LINE OA binding in Phase 5.

## Considered Options

- **Option 1: Full Email/Password or Social Auth from day one**: Adds high onboarding friction for an MVP focused on rapid task logging and avoidance detection.
- **Option 2: Single hardcoded dev user (`userId = 1`)**: Fast to start but requires breaking database schema changes and client rewrites when multi-device testing or LINE OA integration begins.
- **Option 3: Anonymous Device UUID with late binding (Selected)**: Instant zero-friction onboarding that maps cleanly to a `users` record and can seamlessly attach a `line_user_id` when LINE integration is introduced.

## Consequences

- Users can start creating and nudging tasks immediately upon installing the application.
- Data remains tied to a single device until the user binds their LINE account.
- Schema accommodates LINE integration (`line_user_id`) without migration friction.
