import { UserService, userService as defaultUserService } from "./user.service";
import { TaskService, taskService as defaultTaskService } from "./task.service";
import { LineService, lineService as defaultLineService } from "./line.service";
import {
  DEFAULT_TIMEZONE,
  NUDGE_REASON_TEXT,
  isSameLocalDay,
  isWithinNudgeWindow,
  selectDailyNudge,
  type NudgeReason,
} from "../lib/nudge";

export type NudgeSkipReason =
  | "OUTSIDE_WINDOW"
  | "ALREADY_NUDGED_TODAY"
  | "NO_URGENT_TASK"
  | "SEND_FAILED";

export interface NudgeDispatchResult {
  /** Moment the dispatch ran, for logs and for the caller's tests. */
  dispatchedAt: string;
  checked: number;
  sent: Array<{ userId: number; taskId: number; reason: NudgeReason }>;
  skipped: Array<{ userId: number; reason: NudgeSkipReason }>;
}

/**
 * Delivers the daily Action Nudge.
 *
 * The backend stays stateless: an external scheduler (cron, hosting cron job, a
 * GitHub Action) calls POST /nudges/dispatch, and this service decides per user
 * whether a nudge is warranted at that moment. Skipping is the normal case — a
 * user only hears from Nudge on days when something is actually worth starting.
 */
export class NudgeService {
  constructor(
    private userService: UserService = defaultUserService,
    private taskService: TaskService = defaultTaskService,
    private lineService: LineService = defaultLineService
  ) {}

  /**
   * Runs one dispatch pass over every user with a linked LINE account.
   */
  async dispatchDailyNudges(now: Date = new Date()): Promise<NudgeDispatchResult> {
    const users = await this.userService.listLineLinkedUsers();
    const result: NudgeDispatchResult = {
      dispatchedAt: now.toISOString(),
      checked: users.length,
      sent: [],
      skipped: [],
    };

    for (const user of users) {
      const timezone = user.timezone || DEFAULT_TIMEZONE;

      if (!isWithinNudgeWindow(now, timezone)) {
        result.skipped.push({ userId: user.id, reason: "OUTSIDE_WINDOW" });
        continue;
      }

      if (user.lastNudgeAt && isSameLocalDay(new Date(user.lastNudgeAt), now, timezone)) {
        result.skipped.push({ userId: user.id, reason: "ALREADY_NUDGED_TODAY" });
        continue;
      }

      const tasks = await this.taskService.getTasksForUser(user.id);
      const decision = selectDailyNudge(tasks, now);

      if (!decision) {
        result.skipped.push({ userId: user.id, reason: "NO_URGENT_TASK" });
        continue;
      }

      try {
        await this.lineService.sendActionNudge(user.id, decision.taskId, {
          reasonText: NUDGE_REASON_TEXT[decision.reason],
        });
        await this.taskService.markNudged(decision.taskId, now);
        await this.userService.markNudgeSent(user.id, now);
        result.sent.push({ userId: user.id, taskId: decision.taskId, reason: decision.reason });
      } catch (error) {
        console.error(`[nudge] failed to deliver nudge for user ${user.id}:`, error);
        result.skipped.push({ userId: user.id, reason: "SEND_FAILED" });
      }
    }

    return result;
  }

  /**
   * What the user's next nudge would look like, without sending anything.
   * Used by the in-app preview and by tests/demos.
   */
  async previewNudge(userId: number, now: Date = new Date()) {
    const user = await this.userService.findById(userId);
    if (!user) {
      throw new Error("User not found");
    }

    const timezone = user.timezone || DEFAULT_TIMEZONE;
    const tasks = await this.taskService.getTasksForUser(userId);
    const decision = selectDailyNudge(tasks, now);
    const alreadyNudgedToday = Boolean(
      user.lastNudgeAt && isSameLocalDay(new Date(user.lastNudgeAt), now, timezone)
    );

    return {
      timezone,
      withinSendWindow: isWithinNudgeWindow(now, timezone),
      alreadyNudgedToday,
      willSendToday: isWithinNudgeWindow(now, timezone) && !alreadyNudgedToday && Boolean(decision),
      decision,
      lineLinked: Boolean(user.lineUserId),
    };
  }
}

export const nudgeService = new NudgeService();
