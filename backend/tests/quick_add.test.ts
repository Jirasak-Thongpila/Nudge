import { describe, expect, it, beforeEach } from "bun:test";
import { createApp } from "../src/app";
import { UserService } from "../src/services/user.service";
import { TaskService, type CreateTaskInput, type TaskWithDerived } from "../src/services/task.service";
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
        timezone: "Asia/Bangkok",
        lastNudgeAt: null,
        createdAt: new Date(),
      };
      this.store.push(existing);
    }
    return existing;
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

describe("Task Quick Add Endpoints (Ticket 10 / Smart Natural Language)", () => {
  let app: ReturnType<typeof createApp>;
  let mockUserService: MockUserService;
  let mockTaskService: MockTaskService;

  beforeEach(() => {
    mockUserService = new MockUserService();
    mockTaskService = new MockTaskService();
    app = createApp({
      userService: mockUserService,
      taskService: mockTaskService,
    });
  });

  it("should create a task via POST /tasks/quick-add using fast/gemini parser", async () => {
    const response = await app.handle(
      new Request("http://localhost/tasks/quick-add", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-device-uuid": "test-device-quick-add",
        },
        body: JSON.stringify({
          text: "พรุ่งนี้ 9 โมงส่งรายงานวิจัย 4 ดาว 45 นาที",
        }),
      })
    );

    expect(response.status).toBe(201);
    const body = (await response.json()) as any;
    expect(body.success).toBe(true);
    expect(body.duplicate).toBe(false);
    expect(body.data.title).toContain("รายงานวิจัย");
    expect(body.data.importance).toBe(4);
    expect(body.data.estimatedMinutes).toBe(45);
  });

  it("should detect duplicate when creating a task with similar title", async () => {
    // 1. Create first task
    const firstRes = await app.handle(
      new Request("http://localhost/tasks/quick-add", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-device-uuid": "test-device-duplicate-check",
        },
        body: JSON.stringify({
          text: "ส่งมินิโปรเจกต์วิจัย พรุ่งนี้ 5 ดาว",
        }),
      })
    );
    expect(firstRes.status).toBe(201);

    // 2. Try creating similar task without confirmed: true
    const dupResponse = await app.handle(
      new Request("http://localhost/tasks/quick-add", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-device-uuid": "test-device-duplicate-check",
        },
        body: JSON.stringify({
          text: "ส่งมินิโปรเจกต์วิจัย มะรืนนี้ 5 ดาว",
          confirmed: false,
        }),
      })
    );

    expect(dupResponse.status).toBe(200);
    const dupBody = (await dupResponse.json()) as any;
    expect(dupBody.success).toBe(true);
    expect(dupBody.duplicate).toBe(true);
    expect(dupBody.existingTask).toBeDefined();

    // 3. Confirm creation anyway
    const confirmResponse = await app.handle(
      new Request("http://localhost/tasks/quick-add", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-device-uuid": "test-device-duplicate-check",
        },
        body: JSON.stringify({
          text: "ส่งมินิโปรเจกต์วิจัย มะรืนนี้ 5 ดาว",
          confirmed: true,
        }),
      })
    );

    expect(confirmResponse.status).toBe(201);
    const confirmBody = (await confirmResponse.json()) as any;
    expect(confirmBody.success).toBe(true);
    expect(confirmBody.duplicate).toBe(false);
  });

  it("should return notTask if message is casual small talk", async () => {
    const response = await app.handle(
      new Request("http://localhost/tasks/quick-add", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-device-uuid": "test-device-smalltalk",
        },
        body: JSON.stringify({
          text: "สวัสดีครับ ทำอะไรอยู่เหรอ",
        }),
      })
    );

    expect(response.status).toBe(200);
    const body = (await response.json()) as any;
    expect(body.success).toBe(false);
    expect(body.notTask).toBe(true);
    expect(body.replyMessage).toBeDefined();
  });
});
