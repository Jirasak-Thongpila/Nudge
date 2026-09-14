# 09: LINE OA External Nudge & Deep Link

**What to build:** The backend supports registering a user's LINE account mapping to their anonymous device user record, and can push an external Action Nudge via the LINE Messaging API containing a direct button that triggers a mobile deep link (`nudge://focus?taskId=...`) to open the app directly to the Focus Session for that task.

**Blocked by:** 06: Client-Driven Focus Session Timer (10 Minutes)

**Status:** ready-for-agent

- [ ] Database schema links `line_user_id` on `users` table
- [ ] Backend service integrates with LINE Messaging API to dispatch push messages with flex message template
- [ ] Backend webhook endpoint `POST /line/webhook` handles LINE events
- [ ] Mobile app deep-link routing configured to intercept `nudge://focus?taskId=...` and launch directly to Focus Timer
- [ ] Manual & automated tests for webhook handling and deep link resolution
