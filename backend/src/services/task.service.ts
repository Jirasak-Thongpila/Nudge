import { eq, and, isNull, asc, sql } from "drizzle-orm";
import { tasks, type Task } from "../db/schema";
import { db as defaultDb, type Database } from "../db";
import { calculateDaysRemaining } from "../lib/date";
import { calculateAvoidanceScore, detectPotentiallyAvoided } from "../lib/avoidance";

export type TaskStatus = "NOT_STARTED" | "IN_PROGRESS" | "COMPLETED";

export interface TaskWithDerived extends Task {
  daysRemaining: number;
  avoidanceScore: number;
  isPotentiallyAvoided: boolean;
}

export interface CreateTaskInput {
  title: string;
  deadline: Date | string;
  importance: number;
  estimatedMinutes: number;
}

export class TaskService {
  constructor(private db: Database = defaultDb) {}

  protected attachDerivedFields(task: Task, now: Date = new Date()): TaskWithDerived {
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

  async updateTaskStatus(
    userId: number,
    taskId: number,
    status: TaskStatus
  ): Promise<TaskWithDerived> {
    const allowedStatuses: TaskStatus[] = ["NOT_STARTED", "IN_PROGRESS", "COMPLETED"];
    if (!allowedStatuses.includes(status)) {
      throw new Error(`Invalid status: ${status}. Allowed: ${allowedStatuses.join(", ")}`);
    }

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
      .set({ status })
      .where(and(eq(tasks.id, taskId), eq(tasks.userId, userId)))
      .returning();

    return this.attachDerivedFields(updated);
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
}

export const taskService = new TaskService();
