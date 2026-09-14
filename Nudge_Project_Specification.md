# Nudge — Project Specification

## 1. Project Overview

**Nudge** is a task-management and productivity system designed for users who already know what they should do, but tend to postpone difficult or important tasks.

Nudge does more than calculate task priority. It combines:

1. **Deadline Awareness** — shows how much time remains before a deadline.
2. **Avoidance Detection** — detects patterns that may indicate a task is being repeatedly postponed.
3. **Action Nudge** — recommends a small, concrete action that makes the task easier to start.

### Core Positioning

> Nudge doesn't just tell you what to do next — it helps you start.

Thai positioning:

> ระบบที่ไม่ได้แค่บอกว่าควรทำอะไร แต่ช่วยตรวจจับว่าเรากำลังเลี่ยงงานอะไร และช่วยให้เราเริ่มงานนั้น

Important: the system must say **"potentially avoided" / "อาจกำลังหลีกเลี่ยง"**, not claim that the user is lazy or definitely avoiding a task. The system can only infer patterns from observable behavior.

---

## 2. Problem Statement

The target problem is not simply:

> "I don't know which task I should do first."

The actual problem is:

> "I know which task is important, but I choose easier tasks first and keep postponing the difficult task until the deadline is close."

Example:

- Homework → easy → do first
- Reading → medium difficulty
- Mini Project → difficult → postpone

Eventually, the Mini Project becomes urgent.

Traditional to-do lists often focus on prioritization. Nudge focuses on the next step:

> After identifying the important task, how can the system make the user actually start it?

---

## 3. Product Principles

Nudge should follow these principles:

- Reduce friction instead of adding complexity.
- Make deadlines visible.
- Use observable behavior rather than guessing emotions.
- Never label a user as lazy.
- Give actionable recommendations, not just scores.
- Encourage starting with a small amount of work.
- Keep the MVP simple enough to implement reliably.

---

# 4. Core Features

## 4.1 Task Management

Users can:

- Create a task
- View tasks
- Edit a task
- Delete a task
- Set a deadline
- Set importance
- Set estimated duration
- Change task status

### Task status

Use:

- `NOT_STARTED`
- `IN_PROGRESS`
- `COMPLETED`

---

## 4.2 Deadline Awareness

Every task has a deadline.

The system dynamically calculates:

```text
days_remaining = deadline - current_time
```

Do NOT store `days_remaining` in the database because it changes over time.

Example interpretation:

| Days Remaining | Interpretation |
|---:|---|
| 7+ | Low urgency |
| 3–6 | Moderate |
| 2 | Should start soon |
| 1 | Urgent |
| 0 | Due today |
| < 0 | Overdue |

The exact thresholds can be adjusted during implementation.

### UI requirement

The dashboard should clearly show:

> เหลืออีก X วัน

For overdue tasks:

> เกินกำหนด X วัน

Do not automatically classify an overdue task as avoidance.

---

# 5. Explicit Postpone System

A task's `postpone_count` should increase only when the user explicitly chooses to postpone it.

Example:

User presses:

> "เลื่อนไปก่อน"

Then:

```text
postpone_count += 1
```

### Important distinction

#### Explicit Postpone

User deliberately presses the postpone action.

→ Increase `postpone_count`.

#### Deadline Expired

The deadline passes while the task is incomplete.

→ Do NOT increase `postpone_count`.

Reason:

The system cannot know whether the user intentionally avoided the task or simply did not open/use the app.

---

# 6. Avoidance Detection

Avoidance detection is rule-based in the MVP.

It should use signals such as:

- `postpone_count`
- `days_remaining`
- `importance`
- `status`

The system should identify patterns such as:

```text
Near deadline
+
High importance
+
Repeated postponement
+
Not completed
```

This can produce:

```text
isPotentiallyAvoided = true
```

The system must not claim certainty.

Use wording such as:

> ⚠️ งานนี้อาจกำลังถูกเลื่อนซ้ำ

instead of:

> ❌ คุณกำลังหลีกเลี่ยงงานนี้

---

# 7. Avoidance Score

Use a capped score:

```text
avoidance_score = min(postpone_count * 2, 10)
```

Examples:

| Postpone Count | Avoidance Score |
|---:|---:|
| 0 | 0 |
| 1 | 2 |
| 2 | 4 |
| 3 | 6 |
| 4 | 8 |
| 5+ | 10 |

The cap prevents a task that has been postponed many times from permanently dominating every other task.

---

# 8. Priority Score

MVP priority can be calculated as:

```text
priority_score =
    urgency_score
    + importance_score
    + avoidance_score
```

Where:

```text
avoidance_score = min(postpone_count * 2, 10)
```

`urgency_score` should be calculated dynamically from the current deadline.

`importance_score` comes from the user's importance setting.

Do NOT persist `priority_score` in the database because urgency changes with time.

The backend should calculate it when needed, especially for:

```text
GET /tasks/recommended
GET /dashboard
```

---

# 9. Recommendation Engine

The recommendation engine should answer two questions:

1. What task should the user work on now?
2. How should the user start it?

It should NOT return only a numeric score.

Example backend response:

```json
{
  "recommendedTask": {
    "id": 123,
    "title": "Mini Project",
    "daysRemaining": 1,
    "importance": 5,
    "postponeCount": 3,
    "isPotentiallyAvoided": true,
    "suggestedAction": "START_10_MINUTES"
  }
}
```

Flutter should convert this into human-friendly UI:

> 🔴 ควรเริ่มวันนี้  
> Mini Project  
> เหลือ 1 วัน  
> สำคัญมาก  
> ถูกเลื่อน 3 ครั้ง  
> ⚠️ อาจกำลังถูกเลื่อนซ้ำ  
>
> [ เริ่ม 10 นาที ]

---

# 10. Adaptive Nudge

The recommendation should change depending on repeated postponement.

### 0–1 postpones

Recommend:

> ลองเริ่ม 10 นาทีไหม?

### 2–3 postpones

Recommend:

> งานนี้ถูกเลื่อนหลายครั้ง ลองแบ่งงานเป็นขั้นเล็ก ๆ ไหม?

### 4+ postpones

Recommend:

> งานนี้ถูกเลื่อนซ้ำ ลองลดสิ่งที่ต้องทำตอนนี้ให้เล็กลงไหม?

Reason:

Repeated postponement may indicate that the task is too large, unclear, or difficult to start. It does not necessarily mean laziness.

---

# 11. Focus Session

The main purpose of Focus Session is to reduce the psychological barrier to starting.

Instead of asking:

> "Can you finish the whole project?"

Nudge asks:

> "Can you start for 10 minutes?"

Flow:

```text
Dashboard
    ↓
Recommended Task
    ↓
Start 10 Minutes
    ↓
Focus Timer
    ↓
10 minutes completed
    ↓
Continue / Take a Break / Mark Completed
```

Timer example:

```text
Mini Project

Start with just 10 minutes.

09:42
```

The 10-minute session is not expected to finish the entire task.

Its purpose is to get the user started.

---

# 12. Dashboard

The dashboard is the primary screen.

## Recommended Task

Show:

- Task title
- Days remaining
- Importance
- Postpone count
- Potential avoidance state
- Reason for recommendation
- Start 10 Minutes button

Example:

```text
Recommended Task

🔴 Mini Project
เหลืออีก 1 วัน
สำคัญมาก
ถูกเลื่อน 3 ครั้ง

⚠️ อาจกำลังถูกเลื่อนซ้ำ

[ เริ่ม 10 นาที ]
```

## Other sections

### Next

Tasks that should be worked on soon.

### Later

Tasks that are currently less urgent.

---

# 13. LINE OA Integration

LINE OA is used as an external nudge channel.

Example message:

```text
🔔 วันนี้มีงานที่ควรจับตา

Mini Project
เหลืออีก 1 วัน
สำคัญมาก
ถูกเลื่อน 3 ครั้ง

ลองเริ่มแค่ 10 นาทีไหม?
```

The message should include an action button:

```text
[ เริ่ม 10 นาที ]
```

The ideal future flow is:

```text
LINE OA
    ↓
LINE Messaging API
    ↓
Deep Link
    ↓
Flutter
    ↓
Focus Session for specific task
```

Conceptual deep link:

```text
nudge://focus?taskId=123
```

Do not treat this exact scheme as final until mobile deep-link configuration is implemented.

### MVP implementation order

First implement:

```text
Flutter Dashboard
→ Task Detail
→ Start 10 Minutes
→ Focus Timer
```

Then add LINE integration and deep links.

This prevents LINE integration from blocking the core application.

---

# 14. Database Design

## users

```text
id
line_user_id
created_at
```

## tasks

```text
id
user_id
title
deadline
importance
estimated_minutes
status
postpone_count
created_at
```

## focus_sessions

```text
id
task_id
started_at
duration_minutes
completed
```

## Optional future table: daily_checkins

```text
id
user_id
energy_level
created_at
```

## Optional future table: task_events

Can be added later for detailed behavioral history.

Possible event types:

```text
POSTPONED
STARTED
COMPLETED
EXPIRED
```

MVP does not require this table.

---

# 15. Important Database Rules

Do NOT store these as persistent fields unless there is a clear future requirement:

### `days_remaining`

Calculate dynamically:

```text
deadline - current_time
```

### `priority_score`

Calculate dynamically because urgency changes.

### `urgency_score`

Calculate dynamically from the current time and deadline.

Persist the underlying facts instead:

- deadline
- importance
- postpone_count
- status

---

# 16. Technology Stack

## Mobile

```text
Flutter
Dart
```

## Backend

```text
Elysia
Bun
TypeScript
```

## ORM

```text
Drizzle ORM
```

## Database

```text
Neon PostgreSQL
```

## Messaging

```text
LINE OA
LINE Messaging API
```

---

# 17. System Architecture

```text
Flutter
   │
   │ REST API
   ▼
Elysia / Bun
   │
   ├── Task Service
   ├── Priority Service
   ├── Avoidance Detection
   ├── Focus Session
   └── LINE Service
          │
          ▼
     Drizzle ORM
          │
          ▼
   Neon PostgreSQL
```

LINE flow:

```text
LINE OA
   │
   ▼
LINE Messaging API
   │
   ▼
Elysia Backend
   │
   ▼
Flutter Deep Link
   │
   ▼
Focus Session
```

---

# 18. Backend Structure

Recommended structure:

```text
src/
├── routes/
│   ├── tasks.ts
│   ├── focus.ts
│   └── users.ts
│
├── services/
│   ├── task.service.ts
│   ├── priority.service.ts
│   └── line.service.ts
│
├── db/
│   ├── schema.ts
│   └── index.ts
│
├── lib/
│   └── priority.ts
│
└── index.ts
```

Keep business logic out of route handlers when possible.

For example:

```text
route
  ↓
service
  ↓
database
```

Priority and recommendation logic should live in reusable services/functions.

---

# 19. API Design

## Tasks

```http
POST /tasks
GET /tasks
PATCH /tasks/:id
DELETE /tasks/:id
POST /tasks/:id/postpone
POST /tasks/:id/start
```

## Recommendation

```http
GET /tasks/recommended
GET /dashboard
```

## Focus

```http
GET /history
```

Future:

```http
POST /focus/sessions
PATCH /focus/sessions/:id
```

## LINE

```http
POST /line/webhook
```

---

# 20. Example Task Object

```json
{
  "id": 123,
  "userId": 1,
  "title": "Mini Project",
  "deadline": "2026-09-15T23:59:00+07:00",
  "importance": 5,
  "estimatedMinutes": 120,
  "status": "NOT_STARTED",
  "postponeCount": 3,
  "createdAt": "2026-09-10T10:00:00+07:00"
}
```

Derived fields should be calculated by the backend:

```json
{
  "daysRemaining": 1,
  "urgencyScore": 8,
  "avoidanceScore": 6,
  "priorityScore": 19,
  "isPotentiallyAvoided": true,
  "suggestedAction": "START_10_MINUTES"
}
```

---

# 21. MVP Screens

Keep the MVP to approximately four core screens.

## 1. Dashboard

Purpose:

> Tell the user what to do now.

## 2. Add Task

Purpose:

> Create a task with deadline, importance, and estimated duration.

## 3. Task Detail

Purpose:

> View task information, postpone, and start the task.

## 4. Focus Timer

Purpose:

> Help the user start working for 10 minutes.

Optional:

## 5. History / Statistics

Only implement if there is enough development time.

---

# 22. MVP Scope

## Must Have

- Task CRUD
- Deadline
- Importance
- Estimated time
- Task status
- Explicit postpone action
- Postpone count
- Dynamic days remaining
- Dynamic priority score
- Avoidance detection
- Recommended task
- 10-minute focus session
- Dashboard

## Should Have

- LINE OA reminder
- LINE Messaging API
- Deep link to Focus Session
- Basic history

## Optional

- Daily energy check-in
- Task event history
- Subtask decomposition
- Statistics

---

# 23. Features Explicitly Out of MVP

Do not implement these unless the core system is already complete:

- AI chatbot
- Machine learning
- Google Calendar integration
- Apple Calendar integration
- Social features
- Friends
- Leaderboards
- Large gamification system
- XP
- Levels
- Avatars
- Complex mood tracking
- Complex notification engine

The project should demonstrate the core concept before adding advanced features.

---

# 24. Future Task Decomposition

A possible future feature is automatically breaking a large task into smaller steps.

Example:

```text
Mini Project
    ↓
Create Flutter project
    ↓
Create Dashboard
    ↓
Create Task model
    ↓
Create API
```

This does not need AI.

Rule-based decomposition can be enough for an early version.

The purpose is to answer:

> "I know I need to do this, but where do I start?"

---

# 25. Example User Scenarios

## Scenario A — Low Urgency

```text
Task: Mini Project
Days remaining: 7
Postpone count: 0
Importance: 5
Status: NOT_STARTED
```

Expected behavior:

> Do not strongly warn the user.

Possible recommendation:

> ยังมีเวลา ลองวางแผนเริ่มงานไว้ก่อน

---

## Scenario B — Deadline Approaching

```text
Task: Mini Project
Days remaining: 2
Postpone count: 0
Importance: 5
Status: NOT_STARTED
```

Expected behavior:

> Moderate warning.

Recommendation:

> เหลืออีก 2 วัน ลองเริ่ม 10 นาทีไหม?

---

## Scenario C — Potential Avoidance

```text
Task: Mini Project
Days remaining: 1
Postpone count: 3
Importance: 5
Status: NOT_STARTED
```

Expected behavior:

> Strong Nudge.

UI:

```text
🔴 ควรเริ่มวันนี้

Mini Project
เหลืออีก 1 วัน
สำคัญมาก
ถูกเลื่อน 3 ครั้ง

⚠️ งานนี้อาจกำลังถูกเลื่อนซ้ำ

[ เริ่ม 10 นาที ]
```

---

## Scenario D — Overdue Without Explicit Postponement

```text
Task: Mini Project
Days remaining: -2
Postpone count: 0
Importance: 5
Status: NOT_STARTED
```

Expected behavior:

> Show overdue state.

Do NOT automatically say:

> "You are avoiding this task."

Instead:

> 🔴 เกินกำหนด 2 วัน  
> งานนี้ยังไม่เสร็จ ลองจัดการ Deadline ใหม่หรือเริ่มตอนนี้ดีไหม?

---

# 26. Main User Flow

```text
User creates task
        ↓
Set deadline + importance + estimated time
        ↓
Task saved
        ↓
Backend calculates urgency dynamically
        ↓
User views Dashboard
        ↓
Recommendation Engine selects task
        ↓
User sees:
- days remaining
- importance
- postpone count
- potential avoidance
- suggested action
        ↓
User starts 10-minute session
        ↓
Focus Timer
        ↓
Continue / Break / Complete
```

LINE flow:

```text
Backend identifies a task worth nudging
        ↓
LINE OA sends message
        ↓
User taps "Start 10 minutes"
        ↓
Deep link opens Flutter
        ↓
Correct task is opened
        ↓
Focus Session starts
```

---

# 27. Key Differentiator

Do not position Nudge as merely:

> "An AI to-do list that prioritizes tasks."

The stronger positioning is:

> **Nudge observes deadlines and repeated postponement, then turns that pattern into a small actionable next step.**

Core loop:

```text
Deadline Awareness
        ↓
Avoidance Detection
        ↓
Action Nudge
        ↓
Start 10 Minutes
        ↓
Make Progress
```

This is the central product concept.

---

# 28. Implementation Priority

When implementing the project, follow this order:

### Phase 1 — Backend Foundation

1. Initialize Bun + Elysia + TypeScript
2. Configure Drizzle
3. Connect Neon PostgreSQL
4. Create database schema
5. Implement task CRUD

### Phase 2 — Recommendation Logic

6. Implement dynamic `days_remaining`
7. Implement urgency calculation
8. Implement avoidance score
9. Implement priority score
10. Implement recommendation service
11. Implement `/tasks/recommended`

### Phase 3 — Flutter Core

12. Create Flutter project
13. Create Dashboard
14. Create Add Task screen
15. Create Task Detail screen
16. Connect REST API
17. Implement Focus Timer

### Phase 4 — Nudge Behavior

18. Implement explicit postpone
19. Display potential avoidance
20. Implement adaptive recommendations

### Phase 5 — LINE

21. Create/configure LINE OA
22. Implement LINE Messaging API
23. Implement webhook
24. Send daily nudge
25. Add Flutter deep link
26. Open the correct task from LINE

### Phase 6 — Polish

27. Add History/Statistics if time allows
28. Improve UI/UX
29. Test edge cases
30. Prepare project demonstration

---

# 29. Important Edge Cases

The implementation should consider:

- Task with no deadline, if allowed
- Deadline exactly today
- Deadline already passed
- Task completed before deadline
- Task postponed multiple times
- Task postponed 5+ times
- User postpones and then completes the task
- Multiple tasks with the same priority
- Multiple urgent tasks
- User starts a task but does not complete it
- Focus session interrupted
- LINE deep link opened when the task no longer exists
- LINE deep link opened while the user is not logged in

---

# 30. Definition of Success for MVP

The MVP is successful if a user can:

1. Create several tasks.
2. Assign deadlines and importance.
3. See which task is recommended.
4. Understand why that task is recommended.
5. See how many days remain.
6. Explicitly postpone a task.
7. See that repeated postponement affects the recommendation.
8. Receive a Nudge.
9. Press "Start 10 minutes."
10. Complete a focus session.
11. Mark the task as completed.

The MVP does not need AI or machine learning to demonstrate the core concept.

---

# 31. One-Sentence Project Summary

> **Nudge is a productivity system that uses deadlines, importance, and repeated postponement patterns to identify tasks that may be avoided and turn them into small, actionable steps that help users start.**
