import { describe, expect, it, beforeEach } from "bun:test";
import { createApp } from "../src/app";
import { UserService } from "../src/services/user.service";
import {
  TaskService,
  type CreateTaskInput,
  type TaskWithDerived,
  type TaskStatus,
} from "../src/services/task.service";
import {
  FocusService,
  type RecordFocusSessionInput,
} from "../src/services/focus.service";
import type { User, Task, FocusSession } from "../src/db/schema";
import { calculateDaysRemaining } from "../src/lib/date";
import { calculateAvoidanceScore, detectPotentiallyAvoided } from "../src/lib/avoidance";

class MockUserService extends UserService {
  private store: User[] = [];
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

  override async updateTaskStatus(userId: number, taskId: number, status: TaskStatus): Promise<TaskWithDerived> {
    const existing = this.store.find((t) => t.id === taskId && t.userId === userId && !t.deletedAt);
    if (!existing) {
      throw new Error("Task not found");
    }
    existing.status = status;
    return this.attachDerivedFields(existing);
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
    return {
      ...task,
      daysRemaining,
      avoidanceScore,
      isPotentiallyAvoided,
      adaptiveNudgeMessage: "ลองเริ่ม 10 นาทีไหม?",
    };
  }
}

class MockFocusService extends FocusService {
  private sessions: FocusSession[] = [];
  private nextSessionId = 1;

  constructor(private mockTaskSvc: MockTaskService) {
    super(undefined as any, mockTaskSvc);
  }

  override async startFocusSession(userId: number, taskId: number): Promise<{ task: TaskWithDerived; sessionStartedAt: Date }> {
    const task = this.mockTaskSvc.store.find((t) => t.id === taskId && t.userId === userId && !t.deletedAt);
    if (!task) {
      throw new Error("Task not found");
    }

    let currentTask: TaskWithDerived;
    if (task.status === "NOT_STARTED") {
      currentTask = await this.mockTaskSvc.updateTaskStatus(userId, taskId, "IN_PROGRESS");
    } else {
      currentTask = this.mockTaskSvc.attachDerivedFields(task);
    }

    return {
      task: currentTask,
      sessionStartedAt: new Date(),
    };
  }

  override async recordFocusSession(userId: number, input: RecordFocusSessionInput): Promise<FocusSession> {
    const task = this.mockTaskSvc.store.find((t) => t.id === input.taskId && t.userId === userId && !t.deletedAt);
    if (!task) {
      throw new Error("Task not found");
    }

    const session: FocusSession = {
      id: this.nextSessionId++,
      taskId: input.taskId,
      startedAt: new Date(),
      durationMinutes: Math.max(0, Math.round(input.durationMinutes)),
      completed: Boolean(input.completed),
    };
    this.sessions.push(session);
    return session;
  }

  override async getSessionsForTask(userId: number, taskId: number): Promise<FocusSession[]> {
    const task = this.mockTaskSvc.store.find((t) => t.id === taskId && t.userId === userId && !t.deletedAt);
    if (!task) {
      throw new Error("Task not found");
    }

    return this.sessions
      .filter((s) => s.taskId === taskId)
      .sort((a, b) => b.startedAt.getTime() - a.startedAt.getTime());
  }
}

describe("Focus Session Routes (Ticket 06)", () => {
  let app: ReturnType<typeof createApp>;
  let mockUserService: MockUserService;
  let mockTaskService: MockTaskService;
  let mockFocusService: MockFocusService;

  beforeEach(() => {
    mockUserService = new MockUserService();
    mockTaskService = new MockTaskService();
    mockFocusService = new MockFocusService(mockTaskService);

    app = createApp({
      userService: mockUserService,
      taskService: mockTaskService,
      focusService: mockFocusService,
    });
  });

  describe("POST /tasks/:id/start", () => {
    it("should return 401 when x-device-uuid is missing", async () => {
      const res = await app.handle(
        new Request("http://localhost/tasks/1/start", {
          method: "POST",
        })
      );
      expect(res.status).toBe(401);
    });

    it("should return 404 when starting non-existent task", async () => {
      const res = await app.handle(
        new Request("http://localhost/tasks/999/start", {
          method: "POST",
          headers: { "x-device-uuid": "device-focus-1" },
        })
      );
      expect(res.status).toBe(404);
      const data = (await res.json()) as any;
      expect(data.success).toBe(false);
      expect(data.error).toBe("Task not found");
    });

    it("should transition NOT_STARTED task to IN_PROGRESS when focus session starts", async () => {
      // Create user and task
      const user = await mockUserService.getOrCreateUser("device-focus-1");
      const task = await mockTaskService.createTask(user.id, {
        title: "เขียนรายงานภาษาไทย",
        deadline: new Date(Date.now() + 86400000).toISOString(),
        importance: 4,
        estimatedMinutes: 30,
      });
      expect(task.status).toBe("NOT_STARTED");

      // Start focus session
      const res = await app.handle(
        new Request(`http://localhost/tasks/${task.id}/start`, {
          method: "POST",
          headers: { "x-device-uuid": "device-focus-1" },
        })
      );

      expect(res.status).toBe(200);
      const data = (await res.json()) as any;
      expect(data.success).toBe(true);
      expect(data.data.task.status).toBe("IN_PROGRESS");
      expect(data.data.sessionStartedAt).toBeDefined();

      // Check task in store
      expect(mockTaskService.store[0].status).toBe("IN_PROGRESS");
    });

    it("should prevent starting another user's task", async () => {
      const user1 = await mockUserService.getOrCreateUser("device-user-1");
      const task = await mockTaskService.createTask(user1.id, {
        title: "User 1 task",
        deadline: new Date(Date.now() + 86400000).toISOString(),
        importance: 3,
        estimatedMinutes: 20,
      });

      // User 2 attempts to start User 1's task
      const res = await app.handle(
        new Request(`http://localhost/tasks/${task.id}/start`, {
          method: "POST",
          headers: { "x-device-uuid": "device-user-2" },
        })
      );

      expect(res.status).toBe(404);
    });
  });

  describe("POST /focus/sessions", () => {
    it("should record completed 10-minute focus session", async () => {
      const user = await mockUserService.getOrCreateUser("device-focus-1");
      const task = await mockTaskService.createTask(user.id, {
        title: "ทำแบบฝึกหัด Math",
        deadline: new Date(Date.now() + 86400000).toISOString(),
        importance: 5,
        estimatedMinutes: 60,
      });

      const res = await app.handle(
        new Request("http://localhost/focus/sessions", {
          method: "POST",
          headers: {
            "x-device-uuid": "device-focus-1",
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            taskId: task.id,
            durationMinutes: 10,
            completed: true,
          }),
        })
      );

      expect(res.status).toBe(201);
      const data = (await res.json()) as any;
      expect(data.success).toBe(true);
      expect(data.data.taskId).toBe(task.id);
      expect(data.data.durationMinutes).toBe(10);
      expect(data.data.completed).toBe(true);
    });

    it("should record interrupted focus session with partial duration", async () => {
      const user = await mockUserService.getOrCreateUser("device-focus-1");
      const task = await mockTaskService.createTask(user.id, {
        title: "อ่านเปเปอร์ AI",
        deadline: new Date(Date.now() + 86400000).toISOString(),
        importance: 3,
        estimatedMinutes: 45,
      });

      const res = await app.handle(
        new Request("http://localhost/focus/sessions", {
          method: "POST",
          headers: {
            "x-device-uuid": "device-focus-1",
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            taskId: task.id,
            durationMinutes: 4,
            completed: false,
          }),
        })
      );

      expect(res.status).toBe(201);
      const data = (await res.json()) as any;
      expect(data.success).toBe(true);
      expect(data.data.taskId).toBe(task.id);
      expect(data.data.durationMinutes).toBe(4);
      expect(data.data.completed).toBe(false);
    });

    it("should return 404 when logging session for task belonging to another user", async () => {
      const user1 = await mockUserService.getOrCreateUser("user-1");
      const task = await mockTaskService.createTask(user1.id, {
        title: "Private task",
        deadline: new Date(Date.now() + 86400000).toISOString(),
        importance: 3,
        estimatedMinutes: 20,
      });

      const res = await app.handle(
        new Request("http://localhost/focus/sessions", {
          method: "POST",
          headers: {
            "x-device-uuid": "user-2",
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            taskId: task.id,
            durationMinutes: 10,
            completed: true,
          }),
        })
      );

      expect(res.status).toBe(404);
    });
  });

  describe("GET /focus/sessions", () => {
    it("should return all focus sessions logged for a task", async () => {
      const user = await mockUserService.getOrCreateUser("device-focus-hist");
      const task = await mockTaskService.createTask(user.id, {
        title: "เขียนโค้ด Flutter",
        deadline: new Date(Date.now() + 86400000).toISOString(),
        importance: 4,
        estimatedMinutes: 60,
      });

      // Log 2 sessions
      await mockFocusService.recordFocusSession(user.id, {
        taskId: task.id,
        durationMinutes: 10,
        completed: true,
      });
      await mockFocusService.recordFocusSession(user.id, {
        taskId: task.id,
        durationMinutes: 6,
        completed: false,
      });

      const res = await app.handle(
        new Request(`http://localhost/focus/sessions?taskId=${task.id}`, {
          method: "GET",
          headers: {
            "x-device-uuid": "device-focus-hist",
          },
        })
      );

      expect(res.status).toBe(200);
      const data = (await res.json()) as any;
      expect(data.success).toBe(true);
      expect(Array.isArray(data.data)).toBe(true);
      expect(data.data.length).toBe(2);
    });
  });
});
