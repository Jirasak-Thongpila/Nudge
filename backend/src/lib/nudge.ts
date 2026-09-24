import type { Task } from "../db/schema";
import { calculateTaskPriority, getAdaptiveNudgeMessage } from "./priority";

//
// Action Nudge delivery rules.
//
// Nudge does not send reminders on a schedule — it sends a nudge only when a task
// is actually worth starting, at most once per local day, and it backs off when the
// user has not moved on a task after several nudges. Everything here is pure so the
// rules can be tested without a database, a clock, or LINE.
//

export const DEFAULT_TIMEZONE = "Asia/Bangkok";

/** Local hours during which a nudge may be delivered (quiet hours are the rest). */
export const NUDGE_WINDOW_START_HOUR = 8;
export const NUDGE_WINDOW_END_HOUR = 21;

const HOUR_MS = 60 * 60 * 1000;

/** A task is only worth nudging for one of these reasons. */
export type NudgeReason = "OVERDUE" | "POSSIBLY_AVOIDED" | "DUE_SOON";

export const NUDGE_REASON_TEXT: Record<NudgeReason, string> = {
  OVERDUE: "เลยกำหนดแล้ว แต่ยังเริ่มจากก้าวเล็ก ๆ ได้เสมอ",
  POSSIBLY_AVOIDED: "งานนี้ถูกเลื่อนซ้ำ และใกล้ถึงกำหนดแล้ว",
  DUE_SOON: "ใกล้ถึงกำหนด และงานนี้สำคัญ",
};

/** The parts of a task the nudge rules need. */
export type NudgeCandidate = Pick<
  Task,
  | "id"
  | "userId"
  | "title"
  | "deadline"
  | "importance"
  | "estimatedMinutes"
  | "status"
  | "postponeCount"
  | "createdAt"
  | "deletedAt"
  | "lastNudgedAt"
  | "nudgeCount"
> & {
  daysRemaining: number;
  isPotentiallyAvoided: boolean;
};

export interface NudgeDecision {
  taskId: number;
  title: string;
  reason: NudgeReason;
  reasonText: string;
  nudgeMessage: string;
}

export interface ZonedParts {
  year: number;
  month: number;
  day: number;
  hour: number;
  minute: number;
}

/**
 * Calendar/time parts of a moment in the user's timezone. Falls back to the default
 * timezone when the stored value is not a valid IANA name.
 */
export function getZonedParts(date: Date, timezone: string = DEFAULT_TIMEZONE): ZonedParts {
  try {
    const parts = new Intl.DateTimeFormat("en-GB", {
      timeZone: timezone,
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
      hour12: false,
    }).formatToParts(date);

    const pick = (type: string) => Number(parts.find((part) => part.type === type)?.value ?? "0");

    return {
      year: pick("year"),
      month: pick("month"),
      day: pick("day"),
      // "24" appears for midnight in some engines
      hour: pick("hour") % 24,
      minute: pick("minute"),
    };
  } catch {
    if (timezone === DEFAULT_TIMEZONE) {
      throw new Error(`Invalid default timezone: ${DEFAULT_TIMEZONE}`);
    }
    return getZonedParts(date, DEFAULT_TIMEZONE);
  }
}

/** Whether local time is inside the delivery window (i.e. outside quiet hours). */
export function isWithinNudgeWindow(now: Date, timezone: string = DEFAULT_TIMEZONE): boolean {
  const { hour } = getZonedParts(now, timezone);
  return hour >= NUDGE_WINDOW_START_HOUR && hour < NUDGE_WINDOW_END_HOUR;
}

/** Whether two moments fall on the same calendar day in the user's timezone. */
export function isSameLocalDay(a: Date, b: Date, timezone: string = DEFAULT_TIMEZONE): boolean {
  const left = getZonedParts(a, timezone);
  const right = getZonedParts(b, timezone);

  return left.year === right.year && left.month === right.month && left.day === right.day;
}

/**
 * Why this task deserves a nudge right now, or null when it does not.
 * Mirrors the spec's scenarios: hardly-urgent work stays quiet.
 */
export function getNudgeReason(task: NudgeCandidate, _now: Date = new Date()): NudgeReason | null {
  if (task.status === "COMPLETED" || task.deletedAt) {
    return null;
  }

  if (task.daysRemaining <= 0) {
    return "OVERDUE";
  }

  if (task.isPotentiallyAvoided) {
    return "POSSIBLY_AVOIDED";
  }

  // Due today/tomorrow is urgent whatever its importance; two days out it has to be
  // an important task to be worth interrupting the user for.
  if (task.daysRemaining <= 1 || (task.daysRemaining <= 2 && task.importance >= 4)) {
    return "DUE_SOON";
  }

  return null;
}

/**
 * Whether a task may be nudged again today. A task is never nudged twice within
 * 24 hours, and after three unanswered nudges it drops to every other day.
 */
export function isEligibleForNudge(task: NudgeCandidate, now: Date): boolean {
  if (!getNudgeReason(task, now)) {
    return false;
  }

  if (task.lastNudgedAt) {
    const sinceLastNudge = now.getTime() - new Date(task.lastNudgedAt).getTime();

    if (sinceLastNudge < 24 * HOUR_MS) {
      return false;
    }
    if (task.nudgeCount >= 3 && sinceLastNudge < 48 * HOUR_MS) {
      return false;
    }
  }

  return true;
}

/**
 * Picks the single task worth nudging now: the most urgent eligible task, or null
 * when nothing deserves a nudge (in which case the user hears nothing).
 */
export function selectDailyNudge(
  tasks: NudgeCandidate[],
  now: Date = new Date()
): NudgeDecision | null {
  const eligible = tasks.filter((task) => isEligibleForNudge(task, now));
  if (eligible.length === 0) {
    return null;
  }

  const ranked = eligible
    .map((task) => ({ task, priorityScore: calculateTaskPriority(task, now).priorityScore }))
    .sort((a, b) => {
      if (b.priorityScore !== a.priorityScore) {
        return b.priorityScore - a.priorityScore;
      }
      return new Date(a.task.deadline).getTime() - new Date(b.task.deadline).getTime();
    });

  const chosen = ranked[0].task;
  const reason = getNudgeReason(chosen, now)!;

  return {
    taskId: chosen.id,
    title: chosen.title,
    reason,
    reasonText: NUDGE_REASON_TEXT[reason],
    nudgeMessage: getAdaptiveNudgeMessage(chosen.postponeCount),
  };
}

export const FALLBACK_NUDGE_TEMPLATES: Array<(title: string) => string> = [
  (title: string) => `เช้านี้ลองเปิดดู ${title} สัก 10 นาทีไหมครับ สบายๆ เริ่มก้าวแรกกันนะ`,
  (title: string) => `บ่ายนี้แวบมาเริ่ม ${title} สักยก 10 นาทีดีไหมครับ เผื่อสมองแล่นลุยต่อได้`,
  (title: string) => `ก่อนพักผ่อนเย็นนี้ มาลองเคาะ ${title} ก้าวแรก 10 นาที จะได้สบายใจขึ้นครับ`,
  (title: string) => `งาน ${title} ก้อนนี้อาจจะดูเยอะ ลองวางโครงสั้นๆ 10 นาทีพอนะครับ`,
  (title: string) => `ไม่ต้องกดดันตัวเองเรื่องที่ผ่านมาครับ แค่เริ่มใหม่กับ ${title} ตอนนี้สัก 10 นาที ลุยไปด้วยกันนะ`,
  (title: string) => `แค่เปิดไฟล์ ${title} ทิ้งไว้สัก 10 นาทีก็ถือว่าได้เริ่มแล้วครับ สู้ๆ นะ`,
];

let lastFallbackIndex = -1;
export function getRandomRotatedNudge(title: string, _postponeCount: number = 0, _timeOfDay: string = "afternoon"): string {
  const nextIndex = (lastFallbackIndex + 1) % FALLBACK_NUDGE_TEMPLATES.length;
  lastFallbackIndex = nextIndex;
  return FALLBACK_NUDGE_TEMPLATES[nextIndex](title);
}
