import { describe, expect, it } from "bun:test";
import { createApp } from "../src/app";
import {
  NUDGE_REASON_TEXT,
  isEligibleForNudge,
  isSameLocalDay,
  isWithinNudgeWindow,
  selectDailyNudge,
  type NudgeCandidate,
} from "../src/lib/nudge";
import { NudgeService } from "../src/services/nudge.service";
import { UserService } from "../src/services/user.service";
import { TaskService, type TaskWithDerived } from "../src/services/task.service";
import { LineService } from "../src/services/line.service";
import type { User } from "../src/db/schema";

const BANGKOK = "Asia/Bangkok";

/** 08:00 in Bangkok */
const at = (iso: string) => new Date(iso);

const makeCandidate = (overrides: Partial<NudgeCandidate> = {}): NudgeCandidate => ({
  id: 1,
  userId: 1,
  title: "มินิโปรเจกต์",
  deadline: at("2026-09-23T02:00:00.000Z"),
  importance: 5,
  estimatedMinutes: 30,
  status: "NOT_STARTED",
  postponeCount: 0,
  lastNudgedAt: null,
  nudgeCount: 0,
  createdAt: at("2026-09-18T02:00:00.000Z"),
  deletedAt: null,
  daysRemaining: 1,
  isPotentiallyAvoided: false,
  ...overrides,
});

describe("Action Nudge rules", () => {
  describe("delivery window (quiet hours)", () => {
    it("only allows nudges between 08:00 and 21:00 local time", () => {
      expect(isWithinNudgeWindow(at("2026-09-23T00:59:00.000Z"), BANGKOK)).toBe(false); // 07:59
      expect(isWithinNudgeWindow(at("2026-09-23T01:00:00.000Z"), BANGKOK)).toBe(true); // 08:00
      expect(isWithinNudgeWindow(at("2026-09-23T13:59:00.000Z"), BANGKOK)).toBe(true); // 20:59
      expect(isWithinNudgeWindow(at("2026-09-23T14:00:00.000Z"), BANGKOK)).toBe(false); // 21:00
    });

    it("uses each user's own timezone", () => {
      const moment = at("2026-09-23T14:00:00.000Z");
      expect(isWithinNudgeWindow(moment, BANGKOK)).toBe(false); // 21:00, quiet time in Bangkok
      expect(isWithinNudgeWindow(moment, "America/New_York")).toBe(true); // 10:00, fine there
    });

    it("falls back to the default timezone when the stored one is invalid", () => {
      expect(isWithinNudgeWindow(at("2026-09-23T01:00:00.000Z"), "Not/AZone")).toBe(true);
    });
  });

  describe("one nudge per local day", () => {
    it("compares days in the user's timezone, not UTC", () => {
      const morning = at("2026-09-23T01:00:00.000Z"); // 08:00 on the 23rd
      const evening = at("2026-09-23T16:00:00.000Z"); // 23:00 on the 23rd
      const nextMorning = at("2026-09-23T17:00:00.000Z"); // 00:00 on the 24th

      expect(isSameLocalDay(morning, evening, BANGKOK)).toBe(true);
      expect(isSameLocalDay(morning, nextMorning, BANGKOK)).toBe(false);
    });
  });

  describe("which task is worth a nudge", () => {
    it("stays quiet when there is plenty of time (spec Scenario A)", () => {
      const decision = selectDailyNudge([makeCandidate({ daysRemaining: 7, importance: 5 })], at("2026-09-23T01:00:00.000Z"));
      expect(decision).toBeNull();
    });

    it("nudges an important task that is due soon (spec Scenario B)", () => {
      const decision = selectDailyNudge(
        [makeCandidate({ daysRemaining: 2, importance: 5 })],
        at("2026-09-23T01:00:00.000Z")
      );
      expect(decision?.reason).toBe("DUE_SOON");
      expect(decision?.reasonText).toBe(NUDGE_REASON_TEXT.DUE_SOON);
    });

    it("nudges a task that may be avoided (spec Scenario C)", () => {
      const decision = selectDailyNudge(
        [makeCandidate({ daysRemaining: 1, importance: 5, postponeCount: 3, isPotentiallyAvoided: true })],
        at("2026-09-23T01:00:00.000Z")
      );
      expect(decision?.reason).toBe("POSSIBLY_AVOIDED");
      // Adaptive wording for 2–3 postponements, per the spec's nudge ladder
      expect(decision?.nudgeMessage).toContain("เลื่อนหลายครั้ง");
    });

    it("nudges an overdue task (spec Scenario D)", () => {
      const decision = selectDailyNudge(
        [makeCandidate({ daysRemaining: -2 })],
        at("2026-09-23T01:00:00.000Z")
      );
      expect(decision?.reason).toBe("OVERDUE");
    });

    it("never nudges a completed task", () => {
      expect(selectDailyNudge([makeCandidate({ status: "COMPLETED" })], at("2026-09-23T01:00:00.000Z"))).toBeNull();
    });

    it("picks the most urgent task when several qualify", () => {
      const soon = makeCandidate({ id: 7, daysRemaining: 2, importance: 4 });
      const overdue = makeCandidate({ id: 9, daysRemaining: -1 });

      const decision = selectDailyNudge([soon, overdue], at("2026-09-23T01:00:00.000Z"));
      expect(decision?.taskId).toBe(9);
    });
  });

  describe("back-off", () => {
    const now = at("2026-09-23T01:00:00.000Z");

    it("does not nudge the same task twice within a day", () => {
      const task = makeCandidate({ lastNudgedAt: at("2026-09-22T20:00:00.000Z") }); // 5h ago
      expect(isEligibleForNudge(task, now)).toBe(false);
    });

    it("nudges again once a day has passed", () => {
      const task = makeCandidate({ lastNudgedAt: at("2026-09-21T20:00:00.000Z") }); // 29h ago
      expect(isEligibleForNudge(task, now)).toBe(true);
    });

    it("drops to every other day after three unanswered nudges", () => {
      const recent = makeCandidate({ nudgeCount: 3, lastNudgedAt: at("2026-09-21T20:00:00.000Z") }); // 29h
      const older = makeCandidate({ nudgeCount: 3, lastNudgedAt: at("2026-09-20T20:00:00.000Z") }); // 53h

      expect(isEligibleForNudge(recent, now)).toBe(false);
      expect(isEligibleForNudge(older, now)).toBe(true);
    });
  });
});

class StubUserService extends UserService {
  public users: User[] = [];
  public marked: Array<{ userId: number; at: Date }> = [];

  override async listLineLinkedUsers(): Promise<User[]> {
    return this.users;
  }

  override async getOrCreateUser(deviceUuid: string): Promise<User> {
    const trimmed = deviceUuid.trim();
    const existing = this.users.find((user) => user.deviceUuid === trimmed);
    if (existing) {
      return existing;
    }

    const created = makeUser({
      id: this.users.length + 1,
      deviceUuid: trimmed,
      lineUserId: null,
    });
    this.users.push(created);
    return created;
  }

  override async findById(userId: number): Promise<User | null> {
    return this.users.find((user) => user.id === userId) ?? null;
  }

  override async markNudgeSent(userId: number, at: Date = new Date()): Promise<void> {
    this.marked.push({ userId, at });
  }
}

class StubTaskService extends TaskService {
  public tasks: TaskWithDerived[] = [];
  public nudged: number[] = [];

  override async getTasksForUser(): Promise<TaskWithDerived[]> {
    return this.tasks;
  }

  override async markNudged(taskId: number): Promise<void> {
    this.nudged.push(taskId);
  }

  override async getRecommendedTask() {
    const active = this.tasks.filter((task) => task.status !== "COMPLETED");
    return active.length ? ({ task: active[0] } as any) : null;
  }
}

class StubLineService extends LineService {
  public sent: Array<{ userId: number; taskId: number; reasonText?: string }> = [];
  public failNext = false;

  override async sendActionNudge(userId: number, taskId: number, options?: { reasonText?: string }) {
    if (this.failNext) {
      throw new Error("LINE push failed");
    }
    this.sent.push({ userId, taskId, reasonText: options?.reasonText });
    return {
      success: true,
      messageId: "test",
      recipientLineUserId: "U1",
      flexMessage: { type: "flex", altText: "test", contents: {} },
    } as any;
  }
}

const makeTask = (overrides: Partial<TaskWithDerived> = {}): TaskWithDerived => ({
  id: 1,
  userId: 1,
  title: "มินิโปรเจกต์",
  deadline: at("2026-09-22T02:00:00.000Z"),
  importance: 5,
  estimatedMinutes: 30,
  status: "NOT_STARTED",
  postponeCount: 0,
  lastNudgedAt: null,
  nudgeCount: 0,
  createdAt: at("2026-09-18T02:00:00.000Z"),
  deletedAt: null,
  daysRemaining: -1,
  avoidanceScore: 0,
  isPotentiallyAvoided: false,
  adaptiveNudgeMessage: "ลองเริ่ม 10 นาทีไหม?",
  ...overrides,
});

const makeUser = (overrides: Partial<User> = {}): User => ({
  id: 1,
  deviceUuid: "device-1",
  lineUserId: "Uline1",
  timezone: BANGKOK,
  lastNudgeAt: null,
  createdAt: at("2026-09-01T00:00:00.000Z"),
  ...overrides,
});

const buildService = () => {
  const users = new StubUserService();
  const tasks = new StubTaskService();
  const line = new StubLineService();
  const service = new NudgeService(users, tasks, line);

  return { service, users, tasks, line };
};

describe("NudgeService.dispatchDailyNudges", () => {
  it("delivers one nudge and records the delivery", async () => {
    const { service, users, tasks, line } = buildService();
    users.users = [makeUser()];
    tasks.tasks = [makeTask({ id: 4 })];

    const result = await service.dispatchDailyNudges(at("2026-09-23T01:00:00.000Z")); // 08:00 Bangkok

    expect(result.sent).toEqual([{ userId: 1, taskId: 4, reason: "OVERDUE" }]);
    expect(line.sent[0]).toMatchObject({ userId: 1, taskId: 4 });
    expect(line.sent[0].reasonText).toBe(NUDGE_REASON_TEXT.OVERDUE);
    expect(tasks.nudged).toEqual([4]);
    expect(users.marked.length).toBe(1);
  });

  it("stays silent during quiet hours", async () => {
    const { service, users, tasks, line } = buildService();
    users.users = [makeUser()];
    tasks.tasks = [makeTask()];

    const result = await service.dispatchDailyNudges(at("2026-09-22T23:00:00.000Z")); // 06:00 Bangkok

    expect(result.skipped).toEqual([{ userId: 1, reason: "OUTSIDE_WINDOW" }]);
    expect(line.sent).toEqual([]);
    expect(tasks.nudged).toEqual([]);
  });

  it("sends at most one nudge per user per local day", async () => {
    const { service, users, tasks, line } = buildService();
    users.users = [makeUser({ lastNudgeAt: at("2026-09-23T01:00:00.000Z") })];
    tasks.tasks = [makeTask({ lastNudgedAt: null })];

    const result = await service.dispatchDailyNudges(at("2026-09-23T10:00:00.000Z")); // 17:00 same day

    expect(result.skipped).toEqual([{ userId: 1, reason: "ALREADY_NUDGED_TODAY" }]);
    expect(line.sent).toEqual([]);
  });

  it("sends nothing at all when no task deserves a nudge", async () => {
    const { service, users, tasks, line } = buildService();
    users.users = [makeUser()];
    tasks.tasks = [makeTask({ daysRemaining: 9, importance: 3 })];

    const result = await service.dispatchDailyNudges(at("2026-09-23T01:00:00.000Z"));

    expect(result.skipped).toEqual([{ userId: 1, reason: "NO_URGENT_TASK" }]);
    expect(line.sent).toEqual([]);
    expect(users.marked).toEqual([]);
  });

  it("does not record a delivery when LINE rejects the push", async () => {
    const { service, users, tasks, line } = buildService();
    users.users = [makeUser()];
    tasks.tasks = [makeTask()];
    line.failNext = true;

    const result = await service.dispatchDailyNudges(at("2026-09-23T01:00:00.000Z"));

    expect(result.skipped).toEqual([{ userId: 1, reason: "SEND_FAILED" }]);
    expect(tasks.nudged).toEqual([]);
    expect(users.marked).toEqual([]);
  });

  it("previews the next nudge without sending it", async () => {
    const { service, users, tasks, line } = buildService();
    users.users = [makeUser()];
    tasks.tasks = [makeTask({ id: 9 })];

    const preview = await service.previewNudge(1, at("2026-09-23T01:00:00.000Z"));

    expect(preview.willSendToday).toBe(true);
    expect(preview.decision?.taskId).toBe(9);
    expect(preview.lineLinked).toBe(true);
    expect(line.sent).toEqual([]);
  });
});

describe("POST /nudges/dispatch", () => {
  const buildApp = (dispatchKey?: string) => {
    const users = new StubUserService();
    const tasks = new StubTaskService();
    const line = new StubLineService();
    const nudgeService = new NudgeService(users, tasks, line);
    users.users = [makeUser()];
    tasks.tasks = [makeTask({ id: 4 })];

    const app = createApp({ nudgeService, userService: users, taskService: tasks, dispatchKey });
    return { app, users, tasks, line };
  };

  it("rejects requests without the dispatch key", async () => {
    const { app, line } = buildApp("secret-key");

    const res = await app.handle(new Request("http://localhost/nudges/dispatch", { method: "POST" }));

    expect(res.status).toBe(401);
    expect(line.sent).toEqual([]);
  });

  it("rejects requests with the wrong dispatch key", async () => {
    const { app } = buildApp("secret-key");

    const res = await app.handle(
      new Request("http://localhost/nudges/dispatch", {
        method: "POST",
        headers: { "x-nudge-dispatch-key": "nope" },
      })
    );

    expect(res.status).toBe(401);
  });

  it("dispatches when the scheduler presents the right key", async () => {
    const { app, tasks } = buildApp("secret-key");

    const res = await app.handle(
      new Request("http://localhost/nudges/dispatch", {
        method: "POST",
        headers: { "x-nudge-dispatch-key": "secret-key" },
      })
    );

    expect(res.status).toBe(200);
    const body = (await res.json()) as any;
    expect(body.success).toBe(true);
    expect(body.data.checked).toBe(1);
    expect(["sent", "skipped"]).toContain(body.data.sent.length ? "sent" : "skipped");
    expect(tasks.tasks.length).toBe(1);
  });

  it("refuses to run when no key is configured on the server", async () => {
    const previous = process.env.NUDGE_DISPATCH_KEY;
    delete process.env.NUDGE_DISPATCH_KEY;

    try {
      const { app } = buildApp(undefined);
      const res = await app.handle(
        new Request("http://localhost/nudges/dispatch", {
          method: "POST",
          headers: { "x-nudge-dispatch-key": "anything" },
        })
      );

      expect(res.status).toBe(503);
    } finally {
      if (previous !== undefined) {
        process.env.NUDGE_DISPATCH_KEY = previous;
      }
    }
  });

  it("exposes a preview for the authenticated user", async () => {
    const { app } = buildApp("secret-key");

    const unauthorized = await app.handle(new Request("http://localhost/nudges/preview"));
    expect(unauthorized.status).toBe(401);

    const res = await app.handle(
      new Request("http://localhost/nudges/preview", {
        headers: { "x-device-uuid": "device-1" },
      })
    );

    expect(res.status).toBe(200);
    const body = (await res.json()) as any;
    expect(body.success).toBe(true);
    expect(body.data.lineLinked).toBe(true);
  });
});
