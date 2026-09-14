import { describe, expect, it, beforeEach } from "bun:test";
import { createApp } from "../src/app";
import { UserService } from "../src/services/user.service";
import { TaskService, type CreateTaskInput } from "../src/services/task.service";
import type { User, Task } from "../src/db/schema";

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
        createdAt: new Date(),
      };
      this.store.push(existing);
    }
    return existing;
  }
}

class MockTaskService extends TaskService {
  private store: Task[] = [];
  private nextId = 1;

  override async createTask(userId: number, input: CreateTaskInput): Promise<Task> {
    const title = input.title?.trim();
    if (!title) {
      throw new Error("Task title is required");
    }

    const deadline = new Date(input.deadline);
    if (isNaN(deadline.getTime())) {
      throw new Error("Invalid deadline format");
    }

    const importance = Math.round(Number(input.importance));
    if (isNaN(importance) || importance < 1 || importance > 5) {
      throw new Error("Importance must be an integer between 1 and 5");
    }

    const estimatedMinutes = Math.round(Number(input.estimatedMinutes));
    if (isNaN(estimatedMinutes) || estimatedMinutes <= 0) {
      throw new Error("Estimated duration must be greater than 0 minutes");
    }

    const newTask: Task = {
      id: this.nextId++,
      userId,
      title,
      deadline,
      importance,
      estimatedMinutes,
      status: "NOT_STARTED",
      postponeCount: 0,
      createdAt: new Date(),
      deletedAt: null,
    };

    this.store.push(newTask);
    return newTask;
  }

  override async getTasksForUser(userId: number): Promise<Task[]> {
    return this.store
      .filter((t) => t.userId === userId && !t.deletedAt)
      .sort((a, b) => a.deadline.getTime() - b.deadline.getTime());
  }
}

describe("Task Creation & Task List (Ticket 02)", () => {
  let mockUserService: MockUserService;
  let mockTaskService: MockTaskService;
  let app: ReturnType<typeof createApp>;

  beforeEach(() => {
    mockUserService = new MockUserService();
    mockTaskService = new MockTaskService();
    app = createApp({
      userService: mockUserService,
      taskService: mockTaskService,
    });
  });

  describe("POST /tasks", () => {
    it("should reject unauthenticated request with 401", async () => {
      const response = await app.handle(
        new Request("http://localhost/tasks", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            title: "Project Milestone",
            deadline: "2026-09-20T23:59:00.000Z",
            importance: 5,
            estimatedMinutes: 60,
          }),
        })
      );

      expect(response.status).toBe(401);
    });

    it("should create a task with default status NOT_STARTED and postponeCount 0", async () => {
      const response = await app.handle(
        new Request("http://localhost/tasks", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "x-device-uuid": "device-user-1",
          },
          body: JSON.stringify({
            title: "Finish Database Schema",
            deadline: "2026-09-25T18:00:00.000Z",
            importance: 4,
            estimatedMinutes: 45,
          }),
        })
      );

      expect(response.status).toBe(201);
      const body = (await response.json()) as { success: boolean; data: Task };
      expect(body.success).toBe(true);
      expect(body.data.id).toBeDefined();
      expect(body.data.title).toBe("Finish Database Schema");
      expect(body.data.importance).toBe(4);
      expect(body.data.estimatedMinutes).toBe(45);
      expect(body.data.status).toBe("NOT_STARTED");
      expect(body.data.postponeCount).toBe(0);
      expect(body.data.userId).toBe(1);
    });

    it("should reject task creation with empty title or invalid importance", async () => {
      // Missing title
      const res1 = await app.handle(
        new Request("http://localhost/tasks", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "x-device-uuid": "device-user-1",
          },
          body: JSON.stringify({
            title: "",
            deadline: "2026-09-25T18:00:00.000Z",
            importance: 3,
            estimatedMinutes: 30,
          }),
        })
      );
      expect(res1.status).toBe(422);

      // Invalid importance > 5
      const res2 = await app.handle(
        new Request("http://localhost/tasks", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "x-device-uuid": "device-user-1",
          },
          body: JSON.stringify({
            title: "Task with bad importance",
            deadline: "2026-09-25T18:00:00.000Z",
            importance: 10,
            estimatedMinutes: 30,
          }),
        })
      );
      expect(res2.status).toBe(422);
    });
  });

  describe("GET /tasks", () => {
    it("should return empty list when user has no tasks", async () => {
      const response = await app.handle(
        new Request("http://localhost/tasks", {
          headers: { "x-device-uuid": "device-new-user" },
        })
      );

      expect(response.status).toBe(200);
      const body = (await response.json()) as { success: boolean; data: Task[] };
      expect(body.success).toBe(true);
      expect(body.data).toEqual([]);
    });

    it("should isolate tasks between different authenticated users", async () => {
      // User 1 creates task
      await app.handle(
        new Request("http://localhost/tasks", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "x-device-uuid": "user-alpha",
          },
          body: JSON.stringify({
            title: "Alpha Task",
            deadline: "2026-09-21T10:00:00.000Z",
            importance: 3,
            estimatedMinutes: 30,
          }),
        })
      );

      // User 2 creates task
      await app.handle(
        new Request("http://localhost/tasks", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "x-device-uuid": "user-beta",
          },
          body: JSON.stringify({
            title: "Beta Task",
            deadline: "2026-09-22T10:00:00.000Z",
            importance: 5,
            estimatedMinutes: 60,
          }),
        })
      );

      // User 1 fetches tasks
      const resAlpha = await app.handle(
        new Request("http://localhost/tasks", {
          headers: { "x-device-uuid": "user-alpha" },
        })
      );
      const bodyAlpha = (await resAlpha.json()) as { data: Task[] };
      expect(bodyAlpha.data.length).toBe(1);
      expect(bodyAlpha.data[0].title).toBe("Alpha Task");

      // User 2 fetches tasks
      const resBeta = await app.handle(
        new Request("http://localhost/tasks", {
          headers: { "x-device-uuid": "user-beta" },
        })
      );
      const bodyBeta = (await resBeta.json()) as { data: Task[] };
      expect(bodyBeta.data.length).toBe(1);
      expect(bodyBeta.data[0].title).toBe("Beta Task");
    });

    it("should return tasks ordered by deadline ascending", async () => {
      const userUuid = "user-sorting";

      // Task with later deadline
      await app.handle(
        new Request("http://localhost/tasks", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "x-device-uuid": userUuid,
          },
          body: JSON.stringify({
            title: "Later Task",
            deadline: "2026-09-30T10:00:00.000Z",
            importance: 2,
            estimatedMinutes: 20,
          }),
        })
      );

      // Task with earlier deadline
      await app.handle(
        new Request("http://localhost/tasks", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "x-device-uuid": userUuid,
          },
          body: JSON.stringify({
            title: "Earlier Task",
            deadline: "2026-09-16T10:00:00.000Z",
            importance: 5,
            estimatedMinutes: 15,
          }),
        })
      );

      const response = await app.handle(
        new Request("http://localhost/tasks", {
          headers: { "x-device-uuid": userUuid },
        })
      );

      const body = (await response.json()) as { data: Task[] };
      expect(body.data.length).toBe(2);
      expect(body.data[0].title).toBe("Earlier Task");
      expect(body.data[1].title).toBe("Later Task");
    });
  });
});
