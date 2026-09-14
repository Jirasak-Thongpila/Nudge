# Nudge

Nudge is a task-management and behavioral productivity system designed to identify avoidance patterns and help users start important tasks through low-friction actions.

## Language

**Task**:
An actionable unit of work created by a user with a deadline, importance level, and estimated duration.
_Avoid_: Todo, Item, Job, Chore

**Deadline**:
The target date and time by which a task should be finished.
_Avoid_: Due Date, Target Date, Expiry

**Explicit Postpone**:
A deliberate user action indicating an intentional choice to postpone a task rather than passive expiration.
_Avoid_: Snooze, Delay, Reschedule, Procrastinate

**Potentially Avoided**:
A behavioral inference indicating that an important task near its deadline is being repeatedly postponed, without labeling the user as lazy.
_Avoid_: Lazy, Procrastinated, Avoided Task, Failed Task

**Action Nudge**:
An empathetic, context-aware prompt recommending a small, concrete starting action based on postponement history.
_Avoid_: Reminder, Alert, Notification, Warning

**Focus Session**:
A dedicated, low-friction work interval (defaulting to 10 minutes) aimed at overcoming the psychological barrier to start.
_Avoid_: Pomodoro, Study Sprint, Work Block

**Days Remaining**:
The dynamic time difference between a task's deadline and the current moment.
_Avoid_: Time Left, Days Left, Countdown

**Avoidance Score**:
A capped numeric representation of a task's repeated postponement frequency.
_Avoid_: Procrastination Score, Penalty Score, Laziness Index

**Priority Score**:
A dynamic combined rating derived from urgency, importance, and avoidance score to determine the next recommended task.
_Avoid_: Rank, Urgency Level, Task Weight
