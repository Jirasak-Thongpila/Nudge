import { eq, and, isNull, asc } from "drizzle-orm";
import { tasks, type Task, type NewTask } from "../db/schema";
import { db as defaultDb, type Database } from "../db";

export interface CreateTaskInput {
  title: string;
  deadline: Date | string;
  importance: number;
  estimatedMinutes: number;
}

export class TaskService {
  constructor(private db: Database = defaultDb) {}

  async createTask(userId: number, input: CreateTaskInput): Promise<Task> {
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

    return created;
  }

  async getTasksForUser(userId: number): Promise<Task[]> {
    return this.db
      .select()
      .from(tasks)
      .where(and(eq(tasks.userId, userId), isNull(tasks.deletedAt)))
      .orderBy(asc(tasks.deadline));
  }
}

export const taskService = new TaskService();
