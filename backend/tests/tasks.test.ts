import { describe, expect, it, beforeEach } from "bun:test";
import { createApp } from "../src/app";
import { UserService } from "../src/services/user.service";
import {
  TaskService,
  type CreateTaskInput,
  type UpdateTaskInput,
  type TaskWithDerived,
  type TaskStatus,
} from "../src/services/task.service";
import type { User, Task } from "../src/db/schema";
import { calculateDaysRemaining } from "../src/lib/date";
import { detectPotentiallyAvoided } from "../src/lib/avoidance";
import {
  generateRecommendation,
  calculateTaskPriority,
  type RecommendationResult,
} from "../src/lib/priority";
import type { DashboardData } from "../src/services/task.service";

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

  override async createTask(userId: number, input: CreateTaskInput): Promise<TaskWithDerived> {
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
    return this.attachDerivedFields(newTask);
  }

  override async getTasksForUser(userId: number): Promise<TaskWithDerived[]> {
    return this.store
      .filter((t) => t.userId === userId && !t.deletedAt)
      .sort((a, b) => a.deadline.getTime() - b.deadline.getTime())
      .map((t) => this.attachDerivedFields(t));
  }

  override async getTaskById(userId: number, taskId: number): Promise<TaskWithDerived> {
    const existing = this.store.find(
      (t) => t.id === taskId && t.userId === userId && !t.deletedAt
    );
    if (!existing) {
      throw new Error("Task not found");
    }
    return this.attachDerivedFields(existing);
  }

  override async updateTask(
    userId: number,
    taskId: number,
    input: UpdateTaskInput
  ): Promise<TaskWithDerived> {
    const existing = this.store.find(
      (t) => t.id === taskId && t.userId === userId && !t.deletedAt
    );
    if (!existing) {
      throw new Error("Task not found");
    }

    if (input.title !== undefined) {
      const title = input.title.trim();
      if (!title) throw new Error("Task title cannot be empty");
      existing.title = title;
    }
    if (input.deadline !== undefined) {
      const deadline = new Date(input.deadline);
      if (isNaN(deadline.getTime())) throw new Error("Invalid deadline format");
      existing.deadline = deadline;
    }
    if (input.importance !== undefined) {
      const importance = Math.round(Number(input.importance));
      if (isNaN(importance) || importance < 1 || importance > 5) {
        throw new Error("Importance must be an integer between 1 and 5");
      }
      existing.importance = importance;
    }
    if (input.estimatedMinutes !== undefined) {
      const estimatedMinutes = Math.round(Number(input.estimatedMinutes));
      if (isNaN(estimatedMinutes) || estimatedMinutes <= 0) {
        throw new Error("Estimated duration must be greater than 0 minutes");
      }
      existing.estimatedMinutes = estimatedMinutes;
    }
    if (input.status !== undefined) {
      const allowedStatuses: TaskStatus[] = ["NOT_STARTED", "IN_PROGRESS", "COMPLETED"];
      if (!allowedStatuses.includes(input.status)) {
        throw new Error(`Invalid status: ${input.status}`);
      }
      existing.status = input.status;
    }

    return this.attachDerivedFields(existing);
  }

  override async updateTaskStatus(
    userId: number,
    taskId: number,
    status: TaskStatus
  ): Promise<TaskWithDerived> {
    return this.updateTask(userId, taskId, { status });
  }

  override async softDeleteTask(userId: number, taskId: number): Promise<void> {
    const existing = this.store.find(
      (t) => t.id === taskId && t.userId === userId && !t.deletedAt
    );
    if (!existing) {
      throw new Error("Task not found");
    }
    existing.deletedAt = new Date();
  }

  public getRawStore(): Task[] {
    return this.store;
  }

  override async postponeTask(userId: number, taskId: number): Promise<TaskWithDerived> {
    const existing = this.store.find(
      (t) => t.id === taskId && t.userId === userId && !t.deletedAt
    );

    if (!existing) {
      throw new Error("Task not found");
    }

    existing.postponeCount += 1;
    return this.attachDerivedFields(existing);
  }

  override async getRecommendedTask(userId: number): Promise<RecommendationResult | null> {
    const userTasks = this.store.filter((t) => t.userId === userId && !t.deletedAt);
    return generateRecommendation(userTasks);
  }

  override async getDashboard(userId: number): Promise<DashboardData> {
    const userTasks = this.store.filter((t) => t.userId === userId && !t.deletedAt);
    const now = new Date();
    const recommended = generateRecommendation(userTasks, now);
    const recommendedTaskId = recommended?.task.id;

    const remainingActive = userTasks
      .filter((t) => t.status !== "COMPLETED" && t.id !== recommendedTaskId)
      .map((t) => calculateTaskPriority(t, now));

    remainingActive.sort((a, b) => {
      if (b.priorityScore !== a.priorityScore) {
        return b.priorityScore - a.priorityScore;
      }
      return a.deadline.getTime() - b.deadline.getTime();
    });

    const next = remainingActive.slice(0, 3);
    const later = remainingActive.slice(3);

    return {
      recommended,
      next,
      later,
      summary: {
        totalActive: userTasks.filter((t) => t.status !== "COMPLETED").length,
        completedCount: userTasks.filter((t) => t.status === "COMPLETED").length,
        potentiallyAvoidedCount: userTasks.filter((t) => {
          if (t.status === "COMPLETED") return false;
          const days = calculateDaysRemaining(t.deadline, now);
          return detectPotentiallyAvoided({
            postponeCount: t.postponeCount,
            daysRemaining: days,
            importance: t.importance,
            status: t.status,
          });
        }).length,
      },
    };
  }
}

describe("Task Management (Ticket 02 & Ticket 03)", () => {
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

    it("should create a task with default status NOT_STARTED and dynamic daysRemaining", async () => {
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
      const body = (await response.json()) as { success: boolean; data: TaskWithDerived };
      expect(body.success).toBe(true);
      expect(body.data.id).toBeDefined();
      expect(body.data.title).toBe("Finish Database Schema");
      expect(body.data.importance).toBe(4);
      expect(body.data.estimatedMinutes).toBe(45);
      expect(body.data.status).toBe("NOT_STARTED");
      expect(body.data.postponeCount).toBe(0);
      expect(body.data.userId).toBe(1);
      expect(body.data.daysRemaining).toBeDefined();
    });

    it("should reject task creation with empty title or invalid importance", async () => {
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
      const body = (await response.json()) as { success: boolean; data: TaskWithDerived[] };
      expect(body.success).toBe(true);
      expect(body.data).toEqual([]);
    });

    it("should isolate tasks between different authenticated users and calculate daysRemaining", async () => {
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

      const resAlpha = await app.handle(
        new Request("http://localhost/tasks", {
          headers: { "x-device-uuid": "user-alpha" },
        })
      );
      const bodyAlpha = (await resAlpha.json()) as { data: TaskWithDerived[] };
      expect(bodyAlpha.data.length).toBe(1);
      expect(bodyAlpha.data[0].title).toBe("Alpha Task");
      expect(typeof bodyAlpha.data[0].daysRemaining).toBe("number");

      const resBeta = await app.handle(
        new Request("http://localhost/tasks", {
          headers: { "x-device-uuid": "user-beta" },
        })
      );
      const bodyBeta = (await resBeta.json()) as { data: TaskWithDerived[] };
      expect(bodyBeta.data.length).toBe(1);
      expect(bodyBeta.data[0].title).toBe("Beta Task");
    });
  });

  describe("PATCH /tasks/:id (Status Transition - Ticket 03)", () => {
    it("should allow status transition from NOT_STARTED to IN_PROGRESS and COMPLETED", async () => {
      const userUuid = "user-status-test";

      // Create task
      const createRes = await app.handle(
        new Request("http://localhost/tasks", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "x-device-uuid": userUuid,
          },
          body: JSON.stringify({
            title: "Status Test Task",
            deadline: "2026-09-25T18:00:00.000Z",
            importance: 4,
            estimatedMinutes: 30,
          }),
        })
      );
      const created = (await createRes.json()) as { data: TaskWithDerived };
      const taskId = created.data.id;

      // Update to IN_PROGRESS
      const patchRes1 = await app.handle(
        new Request(`http://localhost/tasks/${taskId}`, {
          method: "PATCH",
          headers: {
            "Content-Type": "application/json",
            "x-device-uuid": userUuid,
          },
          body: JSON.stringify({
            status: "IN_PROGRESS",
          }),
        })
      );
      expect(patchRes1.status).toBe(200);
      const body1 = (await patchRes1.json()) as { data: TaskWithDerived };
      expect(body1.data.status).toBe("IN_PROGRESS");

      // Update to COMPLETED
      const patchRes2 = await app.handle(
        new Request(`http://localhost/tasks/${taskId}`, {
          method: "PATCH",
          headers: {
            "Content-Type": "application/json",
            "x-device-uuid": userUuid,
          },
          body: JSON.stringify({
            status: "COMPLETED",
          }),
        })
      );
      expect(patchRes2.status).toBe(200);
      const body2 = (await patchRes2.json()) as { data: TaskWithDerived };
      expect(body2.data.status).toBe("COMPLETED");
    });

    it("should return 404 when updating a non-existent task or task belonging to another user", async () => {
      const res = await app.handle(
        new Request("http://localhost/tasks/9999", {
          method: "PATCH",
          headers: {
            "Content-Type": "application/json",
            "x-device-uuid": "user-someone-else",
          },
          body: JSON.stringify({
            status: "COMPLETED",
          }),
        })
      );
      expect(res.status).toBe(404);
    });

    it("should reject invalid status with 422", async () => {
      const res = await app.handle(
        new Request("http://localhost/tasks/1", {
          method: "PATCH",
          headers: {
            "Content-Type": "application/json",
            "x-device-uuid": "user-test",
          },
          body: JSON.stringify({
            status: "INVALID_STATUS",
          }),
        })
      );
      expect(res.status).toBe(422);
    });
  });

  describe("POST /tasks/:id/postpone (Explicit Postpone & Avoidance - Ticket 04)", () => {
    it("should atomically increment postponeCount and update avoidanceScore", async () => {
      const userUuid = "user-postpone-test";

      // Create a high-importance task with deadline in 1 day
      const createRes = await app.handle(
        new Request("http://localhost/tasks", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "x-device-uuid": userUuid,
          },
          body: JSON.stringify({
            title: "Mini Project Report",
            deadline: new Date(Date.now() + 86400000).toISOString(),
            importance: 5,
            estimatedMinutes: 60,
          }),
        })
      );
      const created = (await createRes.json()) as { data: TaskWithDerived };
      const taskId = created.data.id;
      expect(created.data.postponeCount).toBe(0);
      expect(created.data.avoidanceScore).toBe(0);
      expect(created.data.isPotentiallyAvoided).toBe(false);

      // Explicit Postpone round 1
      const postRes1 = await app.handle(
        new Request(`http://localhost/tasks/${taskId}/postpone`, {
          method: "POST",
          headers: {
            "x-device-uuid": userUuid,
          },
        })
      );
      expect(postRes1.status).toBe(200);
      const body1 = (await postRes1.json()) as { data: TaskWithDerived };
      expect(body1.data.postponeCount).toBe(1);
      expect(body1.data.avoidanceScore).toBe(2);
      expect(body1.data.isPotentiallyAvoided).toBe(false); // Only 1 postpone, not yet avoided

      // Explicit Postpone round 2 (Near deadline + importance 5 + postponeCount 2)
      const postRes2 = await app.handle(
        new Request(`http://localhost/tasks/${taskId}/postpone`, {
          method: "POST",
          headers: {
            "x-device-uuid": userUuid,
          },
        })
      );
      expect(postRes2.status).toBe(200);
      const body2 = (await postRes2.json()) as { data: TaskWithDerived };
      expect(body2.data.postponeCount).toBe(2);
      expect(body2.data.avoidanceScore).toBe(4);
      expect(body2.data.isPotentiallyAvoided).toBe(true); // Now flagged as potentially avoided!
    });

    it("should return 404 when postponing a non-existent task or task belonging to another user", async () => {
      const res = await app.handle(
        new Request("http://localhost/tasks/9999/postpone", {
          method: "POST",
          headers: {
            "x-device-uuid": "user-other",
          },
        })
      );
      expect(res.status).toBe(404);
    });
  });

  describe("GET /tasks/recommended & GET /dashboard (Ticket 05)", () => {
    it("should return null for recommended task when user has no active tasks", async () => {
      const res = await app.handle(
        new Request("http://localhost/tasks/recommended", {
          headers: { "x-device-uuid": "empty-user" },
        })
      );
      expect(res.status).toBe(200);
      const body = (await res.json()) as { data: RecommendationResult | null };
      expect(body.data).toBeNull();
    });

    it("should return the top recommended task with suggestedAction START_10_MINUTES", async () => {
      const userUuid = "recommend-user";

      // Task 1: Low urgency, importance 3
      await app.handle(
        new Request("http://localhost/tasks", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "x-device-uuid": userUuid,
          },
          body: JSON.stringify({
            title: "Low Urgency Task",
            deadline: new Date(Date.now() + 86400000 * 10).toISOString(),
            importance: 3,
            estimatedMinutes: 30,
          }),
        })
      );

      // Task 2: High urgency, importance 5 (Top priority)
      const res2 = await app.handle(
        new Request("http://localhost/tasks", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "x-device-uuid": userUuid,
          },
          body: JSON.stringify({
            title: "Urgent Mini Project",
            deadline: new Date(Date.now() + 86400000).toISOString(),
            importance: 5,
            estimatedMinutes: 120,
          }),
        })
      );
      const task2 = (await res2.json()) as { data: TaskWithDerived };

      // Explicit postpone task 2 to increase avoidance score
      await app.handle(
        new Request(`http://localhost/tasks/${task2.data.id}/postpone`, {
          method: "POST",
          headers: { "x-device-uuid": userUuid },
        })
      );

      const recRes = await app.handle(
        new Request("http://localhost/tasks/recommended", {
          headers: { "x-device-uuid": userUuid },
        })
      );
      expect(recRes.status).toBe(200);
      const recBody = (await recRes.json()) as { data: RecommendationResult };
      expect(recBody.data.task.title).toBe("Urgent Mini Project");
      expect(recBody.data.suggestedAction).toBe("START_10_MINUTES");
      expect(recBody.data.task.priorityScore).toBeGreaterThanOrEqual(15);
    });

    it("GET /dashboard should group tasks into recommended, next, later and summary", async () => {
      const userUuid = "dashboard-user";

      // Create 5 tasks
      for (let i = 1; i <= 5; i++) {
        await app.handle(
          new Request("http://localhost/tasks", {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              "x-device-uuid": userUuid,
            },
            body: JSON.stringify({
              title: `Task #${i}`,
              deadline: new Date(Date.now() + 86400000 * i).toISOString(),
              importance: i,
              estimatedMinutes: i * 20,
            }),
          })
        );
      }

      const dashRes = await app.handle(
        new Request("http://localhost/dashboard", {
          headers: { "x-device-uuid": userUuid },
        })
      );
      expect(dashRes.status).toBe(200);
      const dashBody = (await dashRes.json()) as { data: DashboardData };

      expect(dashBody.data.recommended).not.toBeNull();
      expect(dashBody.data.summary.totalActive).toBe(5);
      expect(dashBody.data.summary.completedCount).toBe(0);
      expect(dashBody.data.next.length).toBeLessThanOrEqual(3);
    });
  });

  describe("Task Detail, Editing & Soft Delete (Ticket 07 & ADR-0004)", () => {
    it("GET /tasks/:id should return single task details with derived fields", async () => {
      const userUuid = "detail-user";
      const createRes = await app.handle(
        new Request("http://localhost/tasks", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "x-device-uuid": userUuid,
          },
          body: JSON.stringify({
            title: "Task to inspect",
            deadline: new Date(Date.now() + 86400000 * 2).toISOString(),
            importance: 4,
            estimatedMinutes: 45,
          }),
        })
      );
      const created = (await createRes.json()) as any;
      const taskId = created.data.id;

      const getRes = await app.handle(
        new Request(`http://localhost/tasks/${taskId}`, {
          headers: { "x-device-uuid": userUuid },
        })
      );

      expect(getRes.status).toBe(200);
      const getBody = (await getRes.json()) as any;
      expect(getBody.success).toBe(true);
      expect(getBody.data.id).toBe(taskId);
      expect(getBody.data.title).toBe("Task to inspect");
      expect(getBody.data.daysRemaining).toBeDefined();
      expect(getBody.data.avoidanceScore).toBeDefined();
    });

    it("GET /tasks/:id should return 404 for non-existent task or task of another user", async () => {
      const res = await app.handle(
        new Request("http://localhost/tasks/99999", {
          headers: { "x-device-uuid": "detail-user" },
        })
      );
      expect(res.status).toBe(404);
      const body = (await res.json()) as any;
      expect(body.success).toBe(false);
      expect(body.error).toBe("Task not found");
    });

    it("PATCH /tasks/:id should update title, importance, estimatedMinutes, deadline", async () => {
      const userUuid = "edit-user";
      const createRes = await app.handle(
        new Request("http://localhost/tasks", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "x-device-uuid": userUuid,
          },
          body: JSON.stringify({
            title: "Original Title",
            deadline: new Date(Date.now() + 86400000).toISOString(),
            importance: 2,
            estimatedMinutes: 15,
          }),
        })
      );
      const created = (await createRes.json()) as any;
      const taskId = created.data.id;

      const newDeadline = new Date(Date.now() + 86400000 * 5).toISOString();
      const patchRes = await app.handle(
        new Request(`http://localhost/tasks/${taskId}`, {
          method: "PATCH",
          headers: {
            "Content-Type": "application/json",
            "x-device-uuid": userUuid,
          },
          body: JSON.stringify({
            title: "Updated Title",
            importance: 5,
            estimatedMinutes: 90,
            deadline: newDeadline,
          }),
        })
      );

      expect(patchRes.status).toBe(200);
      const patchBody = (await patchRes.json()) as any;
      expect(patchBody.success).toBe(true);
      expect(patchBody.data.title).toBe("Updated Title");
      expect(patchBody.data.importance).toBe(5);
      expect(patchBody.data.estimatedMinutes).toBe(90);
    });

    it("DELETE /tasks/:id should execute Soft Delete (ADR-0004), preserving DB record", async () => {
      const userUuid = "delete-user";
      const createRes = await app.handle(
        new Request("http://localhost/tasks", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "x-device-uuid": userUuid,
          },
          body: JSON.stringify({
            title: "Task to delete",
            deadline: new Date(Date.now() + 86400000).toISOString(),
            importance: 3,
            estimatedMinutes: 30,
          }),
        })
      );
      const created = (await createRes.json()) as any;
      const taskId = created.data.id;

      // Soft delete
      const delRes = await app.handle(
        new Request(`http://localhost/tasks/${taskId}`, {
          method: "DELETE",
          headers: { "x-device-uuid": userUuid },
        })
      );

      expect(delRes.status).toBe(200);
      const delBody = (await delRes.json()) as any;
      expect(delBody.success).toBe(true);

      // Verify row is NOT deleted from underlying DB store, but marked with deletedAt
      const rawTasks = mockTaskService.getRawStore();
      const rawTask = rawTasks.find((t) => t.id === taskId);
      expect(rawTask).toBeDefined();
      expect(rawTask!.deletedAt).not.toBeNull();

      // Verify GET /tasks/:id now returns 404
      const getSingleRes = await app.handle(
        new Request(`http://localhost/tasks/${taskId}`, {
          headers: { "x-device-uuid": userUuid },
        })
      );
      expect(getSingleRes.status).toBe(404);

      // Verify GET /tasks excludes the soft deleted task
      const getListRes = await app.handle(
        new Request("http://localhost/tasks", {
          headers: { "x-device-uuid": userUuid },
        })
      );
      const listBody = (await getListRes.json()) as any;
      expect(listBody.data.some((t: any) => t.id === taskId)).toBe(false);
    });
  });
});
