import { describe, expect, it, beforeEach } from "bun:test";
import { createApp } from "../src/app";
import { UserService } from "../src/services/user.service";
import {
  TaskService,
  type CreateTaskInput,
  type TaskWithDerived,
} from "../src/services/task.service";
import { LineService } from "../src/services/line.service";
import type { User, Task } from "../src/db/schema";
import { calculateDaysRemaining } from "../src/lib/date";
import { calculateAvoidanceScore, detectPotentiallyAvoided } from "../src/lib/avoidance";
import { getAdaptiveNudgeMessage } from "../src/lib/priority";

class MockUserService extends UserService {
  public store: User[] = [];
  private nextId = 1;

  override async getOrCreateUser(deviceUuid: string): Promise<User> {
    const trimmed = deviceUuid.trim();
    let existing = this.store.find((u) => u.deviceUuid === trimmed);
    if (!existing) {
      existing = {
        id: this.nextId++,
        deviceUuid: trimmed,
        lineUserId: null,
        createdAt: new Date(),
      };
      this.store.push(existing);
    }
    return existing;
  }

  override async findById(userId: number): Promise<User | null> {
    return this.store.find((u) => u.id === userId) ?? null;
  }

  override async linkLineUserId(userId: number, lineUserId: string): Promise<User | null> {
    const user = this.store.find((u) => u.id === userId);
    if (!user) return null;
    user.lineUserId = lineUserId;
    return user;
  }
}

class MockTaskService extends TaskService {
  public store: Task[] = [];
  private nextId = 1;

  override async createTask(userId: number, input: CreateTaskInput): Promise<TaskWithDerived> {
    const newTask: Task = {
      id: this.nextId++,
      userId,
      title: input.title,
      deadline: new Date(input.deadline),
      importance: input.importance,
      estimatedMinutes: input.estimatedMinutes,
      status: "NOT_STARTED",
      postponeCount: 0,
      createdAt: new Date(),
      deletedAt: null,
    };
    this.store.push(newTask);
    return this.attachDerivedFields(newTask);
  }

  override async getTaskById(userId: number, taskId: number): Promise<TaskWithDerived> {
    const task = this.store.find((t) => t.id === taskId && t.userId === userId && !t.deletedAt);
    if (!task) {
      throw new Error("Task not found");
    }
    return this.attachDerivedFields(task);
  }

  override attachDerivedFields(task: Task, now: Date = new Date()): TaskWithDerived {
    const daysRemaining = calculateDaysRemaining(task.deadline, now);
    const avoidanceScore = calculateAvoidanceScore(task.postponeCount);
    const isPotentiallyAvoided = detectPotentiallyAvoided({
      postponeCount: task.postponeCount,
      daysRemaining,
      importance: task.importance,
      status: task.status,
    });
    const adaptiveNudgeMessage = getAdaptiveNudgeMessage(task.postponeCount);

    return {
      ...task,
      daysRemaining,
      avoidanceScore,
      isPotentiallyAvoided,
      adaptiveNudgeMessage,
    };
  }
}

describe("LINE OA Messaging & Deep Link (Ticket 09)", () => {
  let app: ReturnType<typeof createApp>;
  let mockUserService: MockUserService;
  let mockTaskService: MockTaskService;
  let lineService: LineService;

  beforeEach(() => {
    mockUserService = new MockUserService();
    mockTaskService = new MockTaskService();
    lineService = new LineService(mockUserService, mockTaskService);

    app = createApp({
      userService: mockUserService,
      taskService: mockTaskService,
      lineService,
    });
  });

  describe("POST /line/link", () => {
    it("should reject unauthenticated request with 401", async () => {
      const res = await app.handle(
        new Request("http://localhost/line/link", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ lineUserId: "U12345678" }),
        })
      );
      expect(res.status).toBe(401);
    });

    it("should link LINE user ID to current user account", async () => {
      const user = await mockUserService.getOrCreateUser("device-line-1");
      expect(user.lineUserId).toBeNull();

      const res = await app.handle(
        new Request("http://localhost/line/link", {
          method: "POST",
          headers: {
            "x-device-uuid": "device-line-1",
            "Content-Type": "application/json",
          },
          body: JSON.stringify({ lineUserId: "Uabcdef123456" }),
        })
      );

      expect(res.status).toBe(200);
      const body = (await res.json()) as any;
      expect(body.success).toBe(true);
      expect(body.data.lineUserId).toBe("Uabcdef123456");
      expect(mockUserService.store[0].lineUserId).toBe("Uabcdef123456");
    });
  });

  describe("POST /line/nudge/:taskId", () => {
    it("should reject if user has not linked a LINE account", async () => {
      const user = await mockUserService.getOrCreateUser("device-unlinked");
      const task = await mockTaskService.createTask(user.id, {
        title: "Test Task",
        deadline: new Date(Date.now() + 86400000).toISOString(),
        importance: 4,
        estimatedMinutes: 30,
      });

      const res = await app.handle(
        new Request(`http://localhost/line/nudge/${task.id}`, {
          method: "POST",
          headers: { "x-device-uuid": "device-unlinked" },
        })
      );

      expect(res.status).toBe(400);
      const body = (await res.json()) as any;
      expect(body.success).toBe(false);
      expect(body.error).toContain("User has not linked a LINE account");
    });

    it("should generate Action Nudge flex message with deep link nudge://focus?taskId=...", async () => {
      const user = await mockUserService.getOrCreateUser("device-linked");
      await mockUserService.linkLineUserId(user.id, "Ulinked123");

      const task = await mockTaskService.createTask(user.id, {
        title: "Important Report",
        deadline: new Date(Date.now() + 86400000).toISOString(),
        importance: 5,
        estimatedMinutes: 60,
      });

      const res = await app.handle(
        new Request(`http://localhost/line/nudge/${task.id}`, {
          method: "POST",
          headers: { "x-device-uuid": "device-linked" },
        })
      );

      expect(res.status).toBe(200);
      const body = (await res.json()) as any;
      expect(body.success).toBe(true);
      expect(body.data.recipientLineUserId).toBe("Ulinked123");

      const flex = body.data.flexMessage;
      expect(flex.type).toBe("flex");
      expect(flex.altText).toContain("Important Report");

      // Verify deep link in flex message footer button
      const buttonUri = flex.contents.footer.contents[0].action.uri;
      expect(buttonUri).toBe(`nudge://focus?taskId=${task.id}`);
    });
  });

  describe("POST /line/webhook", () => {
    it("should handle incoming LINE webhook events and return 200 ok", async () => {
      const res = await app.handle(
        new Request("http://localhost/line/webhook", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            destination: "Ubot123",
            events: [
              {
                type: "follow",
                source: { userId: "Uuser999" },
                timestamp: Date.now(),
              },
            ],
          }),
        })
      );

      expect(res.status).toBe(200);
      const body = (await res.json()) as any;
      expect(body.status).toBe("ok");
      expect(body.handledCount).toBe(1);
    });

    it("should process follow and message events with reply tokens", async () => {
      let replyCalled = false;
      lineService.replyMessage = async (token, msgs) => {
        replyCalled = true;
        expect(token).toBe("reply-token-123");
        expect(msgs[0].text).toContain("Uuser999");
        return true;
      };

      const res = await app.handle(
        new Request("http://localhost/line/webhook", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            destination: "Ubot123",
            events: [
              {
                type: "follow",
                replyToken: "reply-token-123",
                source: { userId: "Uuser999" },
                timestamp: Date.now(),
              },
              {
                type: "message",
                replyToken: "reply-token-123",
                source: { userId: "Uuser999" },
                message: { type: "text", text: "id" },
                timestamp: Date.now(),
              },
            ],
          }),
        })
      );

      expect(res.status).toBe(200);
      const body = (await res.json()) as any;
      expect(body.handledCount).toBe(2);
      expect(body.repliesSent).toBe(2);
      expect(replyCalled).toBe(true);
    });
  });
});
