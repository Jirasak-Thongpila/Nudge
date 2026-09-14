# 01: Walking Skeleton & Anonymous Device UUID Auth

**What to build:** An end-to-end walking skeleton where opening the mobile app automatically generates or retrieves a persistent Device UUID, sends it via `x-device-uuid` header to the backend, and automatically registers or authenticates the user in the database without any signup friction. The app displays a connected state confirming communication with the backend.

**Blocked by:** None (can start immediately)

**Status:** ready-for-agent

- [ ] Backend initializes with Bun, Elysia, and Drizzle ORM connecting to PostgreSQL
- [ ] Database schema includes `users` table with `id`, `device_uuid`, `line_user_id`, `created_at`
- [ ] Backend middleware / plugin extracts `x-device-uuid` header and auto-creates or retrieves the user record (ADR-0001)
- [ ] Health / user endpoint `GET /users/me` returns current user state
- [ ] Flutter app bootstraps, generates/stores persistent UUID locally with shared_preferences
- [ ] Flutter app sends `x-device-uuid` to backend and verifies connection on startup
- [ ] Automated tests verify UUID auth and endpoint functionality
