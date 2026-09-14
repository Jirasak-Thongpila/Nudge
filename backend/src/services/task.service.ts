import { eq, and, isNull, asc, sql } from "drizzle-orm";
import { tasks, type Task } from "../db/schema";
import { db as defaultDb, type Database } from "../db";
import { calculateDaysRemaining } from "../lib/date";
import { calculateAvoidanceScore, detectPotentiallyAvoided } from "../lib/avoidance";
import {
  calculateTaskPriority,
  generateRecommendation,
  getAdaptiveNudgeMessage,
  type TaskWithPriority,
  type RecommendationResult,
} from "../lib/priority";

export type TaskStatus = "NOT_STARTED" | "IN_PROGRESS" | "COMPLETED";

export interface TaskWithDerived extends Task {
  daysRemaining: number;
  avoidanceScore: number;
  isPotentiallyAvoided: boolean;
  adaptiveNudgeMessage: string;
}

export interface CreateTaskInput {
  title: string;
  deadline: Date | string;
  importance: number;
  estimatedMinutes: number;
}

export interface UpdateTaskInput {
  title?: string;
  deadline?: Date | string;
  importance?: number;
  estimatedMinutes?: number;
  status?: TaskStatus;
}

export interface DashboardData {
  recommended: RecommendationResult | null;
  next: TaskWithPriority[];
  later: TaskWithPriority[];
  summary: {
    totalActive: number;
    completedCount: number;
    potentiallyAvoidedCount: number;
  };
}

export class TaskService {
  constructor(private db: Database = defaultDb) {}

  public attachDerivedFields(task: Task, now: Date = new Date()): TaskWithDerived {
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

  async createTask(userId: number, input: CreateTaskInput): Promise<TaskWithDerived> {
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

    const [created] = await this.db
      .insert(tasks)
      .values({
        userId,
        title,
        deadline,
        importance,
        estimatedMinutes,
        status: "NOT_STARTED",
        postponeCount: 0,
      })
      .returning();

    return this.attachDerivedFields(created);
  }

  async getTasksForUser(userId: number): Promise<TaskWithDerived[]> {
    const rows = await this.db
      .select()
      .from(tasks)
      .where(and(eq(tasks.userId, userId), isNull(tasks.deletedAt)))
      .orderBy(asc(tasks.deadline));

    const now = new Date();
    return rows.map((task) => this.attachDerivedFields(task, now));
  }

  async getTaskById(userId: number, taskId: number): Promise<TaskWithDerived> {
    const [task] = await this.db
      .select()
      .from(tasks)
      .where(and(eq(tasks.id, taskId), eq(tasks.userId, userId), isNull(tasks.deletedAt)))
      .limit(1);

    if (!task) {
      throw new Error("Task not found");
    }

    return this.attachDerivedFields(task);
  }

  async updateTask(
    userId: number,
    taskId: number,
    input: UpdateTaskInput
  ): Promise<TaskWithDerived> {
    const [existing] = await this.db
      .select()
      .from(tasks)
      .where(and(eq(tasks.id, taskId), eq(tasks.userId, userId), isNull(tasks.deletedAt)))
      .limit(1);

    if (!existing) {
      throw new Error("Task not found");
    }

    const updates: Partial<typeof tasks.$inferInsert> = {};

    if (input.title !== undefined) {
      const title = input.title.trim();
      if (!title) {
        throw new Error("Task title cannot be empty");
      }
      updates.title = title;
    }

    if (input.deadline !== undefined) {
      const deadline = new Date(input.deadline);
      if (isNaN(deadline.getTime())) {
        throw new Error("Invalid deadline format");
      }
      updates.deadline = deadline;
    }

    if (input.importance !== undefined) {
      const importance = Math.round(Number(input.importance));
      if (isNaN(importance) || importance < 1 || importance > 5) {
        throw new Error("Importance must be an integer between 1 and 5");
      }
      updates.importance = importance;
    }

    if (input.estimatedMinutes !== undefined) {
      const estimatedMinutes = Math.round(Number(input.estimatedMinutes));
      if (isNaN(estimatedMinutes) || estimatedMinutes <= 0) {
        throw new Error("Estimated duration must be greater than 0 minutes");
      }
      updates.estimatedMinutes = estimatedMinutes;
    }

    if (input.status !== undefined) {
      const allowedStatuses: TaskStatus[] = ["NOT_STARTED", "IN_PROGRESS", "COMPLETED"];
      if (!allowedStatuses.includes(input.status)) {
        throw new Error(`Invalid status: ${input.status}. Allowed: ${allowedStatuses.join(", ")}`);
      }
      updates.status = input.status;
    }

    if (Object.keys(updates).length === 0) {
      return this.attachDerivedFields(existing);
    }

    const [updated] = await this.db
      .update(tasks)
      .set(updates)
      .where(and(eq(tasks.id, taskId), eq(tasks.userId, userId)))
      .returning();

    return this.attachDerivedFields(updated);
  }

  async updateTaskStatus(
    userId: number,
    taskId: number,
    status: TaskStatus
  ): Promise<TaskWithDerived> {
    return this.updateTask(userId, taskId, { status });
  }

  async softDeleteTask(userId: number, taskId: number): Promise<void> {
    const [existing] = await this.db
      .select()
      .from(tasks)
      .where(and(eq(tasks.id, taskId), eq(tasks.userId, userId), isNull(tasks.deletedAt)))
      .limit(1);

    if (!existing) {
      throw new Error("Task not found");
    }

    await this.db
      .update(tasks)
      .set({ deletedAt: new Date() })
      .where(and(eq(tasks.id, taskId), eq(tasks.userId, userId)));
  }

  async postponeTask(userId: number, taskId: number): Promise<TaskWithDerived> {
    const [existing] = await this.db
      .select()
      .from(tasks)
      .where(and(eq(tasks.id, taskId), eq(tasks.userId, userId), isNull(tasks.deletedAt)))
      .limit(1);

    if (!existing) {
      throw new Error("Task not found");
    }

    const [updated] = await this.db
      .update(tasks)
      .set({
        postponeCount: sql`${tasks.postponeCount} + 1`,
      })
      .where(and(eq(tasks.id, taskId), eq(tasks.userId, userId)))
      .returning();

    return this.attachDerivedFields(updated);
  }

  async getRecommendedTask(userId: number): Promise<RecommendationResult | null> {
    const rows = await this.db
      .select()
      .from(tasks)
      .where(and(eq(tasks.userId, userId), isNull(tasks.deletedAt)));

    return generateRecommendation(rows);
  }

  async getDashboard(userId: number): Promise<DashboardData> {
    const rows = await this.db
      .select()
      .from(tasks)
      .where(and(eq(tasks.userId, userId), isNull(tasks.deletedAt)));

    const now = new Date();
    const recommended = generateRecommendation(rows, now);
    const recommendedTaskId = recommended?.task.id;

    // Filter active tasks that aren't the top recommended task
    const remainingActive = rows
      .filter((t) => t.status !== "COMPLETED" && t.id !== recommendedTaskId)
      .map((t) => calculateTaskPriority(t, now));

    // Sort active tasks by priorityScore DESC, then deadline ASC
    remainingActive.sort((a, b) => {
      if (b.priorityScore !== a.priorityScore) {
        return b.priorityScore - a.priorityScore;
      }
      return a.deadline.getTime() - b.deadline.getTime();
    });

    const next = remainingActive.slice(0, 3);
    const later = remainingActive.slice(3);

    const totalActive = rows.filter((t) => t.status !== "COMPLETED").length;
    const completedCount = rows.filter((t) => t.status === "COMPLETED").length;
    const potentiallyAvoidedCount = rows.filter((t) => {
      if (t.status === "COMPLETED") return false;
      const days = calculateDaysRemaining(t.deadline, now);
      return detectPotentiallyAvoided({
        postponeCount: t.postponeCount,
        daysRemaining: days,
        importance: t.importance,
        status: t.status,
      });
    }).length;

    return {
      recommended,
      next,
      later,
      summary: {
        totalActive,
        completedCount,
        potentiallyAvoidedCount,
      },
    };
  }
}

export const taskService = new TaskService();
