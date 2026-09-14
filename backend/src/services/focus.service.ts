import { eq, and, isNull, desc } from "drizzle-orm";
import { tasks, focusSessions, type FocusSession } from "../db/schema";
import { db as defaultDb, type Database } from "../db";
import { TaskService, taskService as defaultTaskService, type TaskWithDerived } from "./task.service";

export interface RecordFocusSessionInput {
  taskId: number;
  durationMinutes: number;
  completed: boolean;
}

export class FocusService {
  constructor(
    private db: Database = defaultDb,
    private taskService: TaskService = defaultTaskService
  ) {}

  /**
   * Starts a focus session on a task. If task was NOT_STARTED, transitions to IN_PROGRESS.
   * (ADR-0003: Client-driven focus timer initialization)
   */
  async startFocusSession(
    userId: number,
    taskId: number
  ): Promise<{ task: TaskWithDerived; sessionStartedAt: Date }> {
    const [task] = await this.db
      .select()
      .from(tasks)
      .where(and(eq(tasks.id, taskId), eq(tasks.userId, userId), isNull(tasks.deletedAt)))
      .limit(1);

    if (!task) {
      throw new Error("Task not found");
    }

    let currentTask: TaskWithDerived;
    if (task.status === "NOT_STARTED") {
      currentTask = await this.taskService.updateTaskStatus(userId, taskId, "IN_PROGRESS");
    } else {
      currentTask = this.taskService.attachDerivedFields(task);
    }

    return {
      task: currentTask,
      sessionStartedAt: new Date(),
    };
  }

  /**
   * Records a completed or interrupted focus session.
   */
  async recordFocusSession(
    userId: number,
    input: RecordFocusSessionInput
  ): Promise<FocusSession> {
    const { taskId, durationMinutes, completed } = input;

    // Verify task exists and belongs to user
    const [task] = await this.db
      .select()
      .from(tasks)
      .where(and(eq(tasks.id, taskId), eq(tasks.userId, userId), isNull(tasks.deletedAt)))
      .limit(1);

    if (!task) {
      throw new Error("Task not found");
    }

    const duration = Math.max(0, Math.round(Number(durationMinutes)));

    const [session] = await this.db
      .insert(focusSessions)
      .values({
        taskId,
        durationMinutes: duration,
        completed: Boolean(completed),
      })
      .returning();

    return session;
  }

  /**
   * Gets history of focus sessions for a specific task.
   */
  async getSessionsForTask(userId: number, taskId: number): Promise<FocusSession[]> {
    const [task] = await this.db
      .select()
      .from(tasks)
      .where(and(eq(tasks.id, taskId), eq(tasks.userId, userId), isNull(tasks.deletedAt)))
      .limit(1);

    if (!task) {
      throw new Error("Task not found");
    }

    return this.db
      .select()
      .from(focusSessions)
      .where(eq(focusSessions.taskId, taskId))
      .orderBy(desc(focusSessions.startedAt));
  }
}

export const focusService = new FocusService();
