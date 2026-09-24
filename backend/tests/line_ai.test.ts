import { describe, expect, it, beforeEach } from "bun:test";
import { createApp } from "../src/app";
import { UserService } from "../src/services/user.service";
import { TaskService, type CreateTaskInput, type TaskWithDerived } from "../src/services/task.service";
import { LineService } from "../src/services/line.service";
import { GeminiService, type TaskIntentResult } from "../src/services/gemini.service";
import type { User, Task } from "../src/db/schema";
import { calculateDaysRemaining } from "../src/lib/date";
import { calculateAvoidanceScore, detectPotentiallyAvoided } from "../src/lib/avoidance";
import { calculateTaskPriority, getAdaptiveNudgeMessage, type RecommendationResult } from "../src/lib/priority";

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
        timezone: "Asia/Bangkok",
        lastNudgeAt: null,
        createdAt: new Date(),
      };
      this.store.push(existing);
    }
    return existing;
  }

  override async getOrCreateUserByLineUserId(lineUserId: string, fallbackDeviceUuid?: string): Promise<User> {
    const trimmed = lineUserId.trim();
    let existing = this.store.find((u) => u.lineUserId === trimmed);
    if (existing) return existing;

    if (fallbackDeviceUuid) {
      const deviceUser = this.store.find((u) => u.deviceUuid === fallbackDeviceUuid.trim());
      if (deviceUser) {
        deviceUser.lineUserId = trimmed;
        return deviceUser;
      }
    }

    const newUser: User = {
      id: this.nextId++,
      deviceUuid: fallbackDeviceUuid?.trim() || `line-${trimmed}`,
      lineUserId: trimmed,
      timezone: "Asia/Bangkok",
      lastNudgeAt: null,
      createdAt: new Date(),
    };
    this.store.push(newUser);
    return newUser;
  }

  override async findById(userId: number): Promise<User | null> {
    return this.store.find((u) => u.id === userId) ?? null;
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
      lastNudgedAt: null,
      nudgeCount: 0,
      createdAt: new Date(),
      deletedAt: null,
    };
    this.store.push(newTask);
    return this.attachDerivedFields(newTask);
  }

  override async getTasksForUser(userId: number): Promise<TaskWithDerived[]> {
    return this.store
      .filter((t) => t.userId === userId && !t.deletedAt)
      .map((t) => this.attachDerivedFields(t));
  }

  override async getRecommendedTask(userId: number): Promise<RecommendationResult | null> {
    const tasks = await this.getTasksForUser(userId);
    const active = tasks.filter((t) => t.status !== "COMPLETED");
    if (active.length === 0) return null;
    const top = active[0];
    return {
      task: calculateTaskPriority(top),
      suggestedAction: "START_10_MINUTES",
      recommendationReason: "งานสำคัญที่สุดที่ควรทำในตอนนี้",
      adaptiveNudgeMessage: getAdaptiveNudgeMessage(top.postponeCount),
    };
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

class MockGeminiService extends GeminiService {
  public mockResult: TaskIntentResult = { intent: "UNKNOWN" };

  override async parseTaskIntent(_message: string, _now: Date = new Date()): Promise<TaskIntentResult> {
    return this.mockResult;
  }
}

describe("LINE Auth & Gemini AI Chatbot", () => {
  let app: ReturnType<typeof createApp>;
  let mockUserService: MockUserService;
  let mockTaskService: MockTaskService;
  let mockGeminiService: MockGeminiService;
  let lineService: LineService;

  beforeEach(() => {
    mockUserService = new MockUserService();
    mockTaskService = new MockTaskService();
    mockGeminiService = new MockGeminiService();
    lineService = new LineService(mockUserService, mockTaskService, mockGeminiService, "test-token", "", "liff-123");

    app = createApp({
      userService: mockUserService,
      taskService: mockTaskService,
      lineService,
    });
  });

  describe("POST /line/auth", () => {
    it("should authenticate and create new user with lineUserId", async () => {
      const res = await app.handle(
        new Request("http://localhost/line/auth", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            lineUserId: "Utestline123",
            displayName: "Tle",
          }),
        })
      );

      expect(res.status).toBe(200);
      const body = (await res.json()) as any;
      expect(body.success).toBe(true);
      expect(body.data.lineUserId).toBe("Utestline123");
    });

    it("should allow calling protected API endpoints using x-line-user-id header", async () => {
      // First, create task
      const user = await mockUserService.getOrCreateUserByLineUserId("Uauthtest");
      await mockTaskService.createTask(user.id, {
        title: "Test with LINE Header",
        deadline: new Date(Date.now() + 86400000).toISOString(),
        importance: 4,
        estimatedMinutes: 30,
      });

      const res = await app.handle(
        new Request("http://localhost/tasks", {
          method: "GET",
          headers: {
            "x-line-user-id": "Uauthtest",
          },
        })
      );

      expect(res.status).toBe(200);
      const body = (await res.json()) as any;
      expect(body.success).toBe(true);
      expect(body.data.length).toBe(1);
      expect(body.data[0].title).toBe("Test with LINE Header");
    });
  });

  describe("LINE Webhook with AI NLP", () => {
    it("should automatically create task when Gemini returns CREATE_TASK intent", async () => {
      mockGeminiService.mockResult = {
        intent: "CREATE_TASK",
        title: "การบ้านแคลคูลัส",
        deadline: new Date(Date.now() + 86400000).toISOString(),
        importance: 5,
        estimatedMinutes: 45,
      };

      let sentReplies: any[] = [];
      let sentPushes: any[] = [];
      lineService.replyMessage = async (_token, messages) => {
        sentReplies = messages;
        return true;
      };
      lineService.pushMessages = async (_to, messages) => {
        sentPushes = messages;
        return true;
      };

      const res = await app.handle(
        new Request("http://localhost/line/webhook", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            destination: "Ubot",
            events: [
              {
                type: "message",
                replyToken: "reply-123",
                source: { userId: "UuserAI" },
                message: { type: "text", text: "พรุ่งนี้มีส่งการบ้านแคลคูลัส สำคัญมาก" },
                timestamp: Date.now(),
              },
            ],
          }),
        })
      );

      expect(res.status).toBe(200);
      expect(mockTaskService.store.length).toBe(1);
      expect(mockTaskService.store[0].title).toBe("การบ้านแคลคูลัส");
      expect(mockTaskService.store[0].importance).toBe(5);

      // 1. Immediate acknowledgment is sent via replyToken
      expect(sentReplies.length).toBe(1);
      expect(sentReplies[0].type).toBe("text");
      expect(sentReplies[0].text).toContain("กำลังบันทึก");

      // 2. Created task Flex Card is pushed right after AI extraction
      expect(sentPushes.length).toBe(1);
      expect(sentPushes[0].type).toBe("flex");
      expect(sentPushes[0].altText).toContain("การบ้านแคลคูลัส");
    });

    it("should return tasks list when intent is VIEW_TASKS", async () => {
      const user = await mockUserService.getOrCreateUserByLineUserId("UuserList");
      await mockTaskService.createTask(user.id, {
        title: "Task 1",
        deadline: new Date(Date.now() + 86400000).toISOString(),
        importance: 3,
        estimatedMinutes: 20,
      });

      mockGeminiService.mockResult = { intent: "VIEW_TASKS" };

      let sentReplies: any[] = [];
      lineService.replyMessage = async (_token, messages) => {
        sentReplies = messages;
        return true;
      };

      const res = await app.handle(
        new Request("http://localhost/line/webhook", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            destination: "Ubot",
            events: [
              {
                type: "message",
                replyToken: "reply-list",
                source: { userId: "UuserList" },
                message: { type: "text", text: "งานวันนี้" },
                timestamp: Date.now(),
              },
            ],
          }),
        })
      );

      expect(res.status).toBe(200);
      expect(sentReplies.length).toBe(1);
      expect(sentReplies[0].type).toBe("flex");
      expect(sentReplies[0].altText).toContain("1 รายการ");
    });

    it("should not show saving acknowledgement for non-task messages", async () => {
      mockGeminiService.mockResult = {
        intent: "UNKNOWN",
        replyMessage: "สวัสดีครับ! มีอะไรให้ช่วยไหมครับ",
      };

      let sentReplies: any[] = [];
      let sentPushes: any[] = [];
      lineService.replyMessage = async (_token, messages) => {
        sentReplies = messages;
        return true;
      };
      lineService.pushMessages = async (_to, messages) => {
        sentPushes = messages;
        return true;
      };

      const res = await app.handle(
        new Request("http://localhost/line/webhook", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            destination: "Ubot",
            events: [
              {
                type: "message",
                replyToken: "reply-chat",
                source: { userId: "UuserChat" },
                message: { type: "text", text: "สวัสดี Nudge AI" },
                timestamp: Date.now(),
              },
            ],
          }),
        })
      );

      expect(res.status).toBe(200);
      expect(mockTaskService.store.length).toBe(0);

      // The bot answers directly via replyToken without the "saving" ack
      expect(sentReplies.length).toBe(1);
      expect(sentReplies[0].type).toBe("text");
      expect(sentReplies[0].text).toContain("สวัสดีครับ");
      expect(sentReplies[0].text).not.toContain("กำลังบันทึก");
      expect(sentPushes.length).toBe(0);
    });
  });
});
