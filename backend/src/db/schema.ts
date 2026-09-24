import { pgTable, serial, varchar, timestamp, integer, boolean } from "drizzle-orm/pg-core";

export const users = pgTable("users", {
  id: serial("id").primaryKey(),
  deviceUuid: varchar("device_uuid", { length: 128 }).notNull().unique(),
  lineUserId: varchar("line_user_id", { length: 128 }),
  // IANA timezone used to decide when an Action Nudge may be delivered
  timezone: varchar("timezone", { length: 64 }).notNull().default("Asia/Bangkok"),
  // Delivery state: at most one Action Nudge per user per local day
  lastNudgeAt: timestamp("last_nudge_at", { withTimezone: true }),
  createdAt: timestamp("created_at", { withTimezone: true }).defaultNow().notNull(),
});

export const tasks = pgTable("tasks", {
  id: serial("id").primaryKey(),
  userId: integer("user_id")
    .references(() => users.id, { onDelete: "cascade" })
    .notNull(),
  title: varchar("title", { length: 255 }).notNull(),
  deadline: timestamp("deadline", { withTimezone: true }).notNull(),
  importance: integer("importance").notNull(),
  estimatedMinutes: integer("estimated_minutes").notNull(),
  status: varchar("status", { length: 32 }).notNull().default("NOT_STARTED"),
  postponeCount: integer("postpone_count").notNull().default(0),
  // Action Nudge history: when this task was nudged last, and how many times in a row
  lastNudgedAt: timestamp("last_nudged_at", { withTimezone: true }),
  nudgeCount: integer("nudge_count").notNull().default(0),
  createdAt: timestamp("created_at", { withTimezone: true }).defaultNow().notNull(),
  deletedAt: timestamp("deleted_at", { withTimezone: true }),
});

export const focusSessions = pgTable("focus_sessions", {
  id: serial("id").primaryKey(),
  taskId: integer("task_id")
    .references(() => tasks.id, { onDelete: "cascade" })
    .notNull(),
  startedAt: timestamp("started_at", { withTimezone: true }).defaultNow().notNull(),
  durationMinutes: integer("duration_minutes").notNull().default(10),
  completed: boolean("completed").notNull().default(false),
});

export type User = typeof users.$inferSelect;
export type NewUser = typeof users.$inferInsert;
export type Task = typeof tasks.$inferSelect;
export type NewTask = typeof tasks.$inferInsert;
export type FocusSession = typeof focusSessions.$inferSelect;
export type NewFocusSession = typeof focusSessions.$inferInsert;
