# 05: Priority Scoring & Dashboard Recommendation Hero

**What to build:** The backend synthesizes urgency, importance, and avoidance score into a dynamic Priority Score (`priority_score = urgency_score + importance_score + avoidance_score`) and exposes `GET /tasks/recommended` and `GET /dashboard`. The Flutter dashboard highlights the top recommended task with an empathetic Action Nudge call-to-action button.

**Blocked by:** 04: Explicit Postpone & Avoidance Detection

**Status:** ready-for-agent

- [ ] Priority calculation algorithm combines `urgency_score`, `importance_score`, and `avoidance_score` (ADR-0002)
- [ ] Backend endpoint `GET /tasks/recommended` returns the single highest priority task with structured recommendation context (`suggestedAction: "START_10_MINUTES"`)
- [ ] Backend endpoint `GET /dashboard` groups tasks into Recommended, Next, and Later buckets
- [ ] Flutter Dashboard screen features the Recommended Task Hero card with days remaining, importance, postpone history, avoidance badge, and `[ เริ่ม 10 นาที ]` action button
- [ ] Unit & integration tests for ranking algorithm stability and edge cases
