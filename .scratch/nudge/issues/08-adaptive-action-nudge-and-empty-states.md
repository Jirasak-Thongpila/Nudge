# 08: Adaptive Action Nudge Messaging & Empty States

**What to build:** The recommendation system provides dynamic, adaptive action nudge messages tailored to the user's postponement count (0–1: "ลองเริ่ม 10 นาทีไหม?", 2–3: "งานนี้ถูกเลื่อนหลายครั้ง ลองแบ่งงานเป็นขั้นเล็ก ๆ ไหม?", 4+: "งานนี้ถูกเลื่อนซ้ำ ลองลดสิ่งที่ต้องทำตอนนี้ให้เล็กลงไหม?"). The app also includes encouraging, empathetic empty states when no tasks are pending.

**Blocked by:** 05: Priority Scoring & Dashboard Recommendation Hero

**Status:** completed

- [x] Backend recommendation engine formats `adaptiveNudgeMessage` based on postpone count tiers
- [x] Language audit verifies zero shaming or guilt-inducing terms across all responses (strict adherence to CONTEXT.md)
- [x] Flutter UI renders adaptive nudge copy dynamically within the Recommendation Hero and Task Detail views
- [x] Empathetic empty states in Flutter when all tasks are completed or when no tasks exist
- [x] Tests verify copy generation across different postpone count thresholds
