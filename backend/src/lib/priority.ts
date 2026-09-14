import { calculateDaysRemaining } from "./date";
import { calculateAvoidanceScore, detectPotentiallyAvoided } from "./avoidance";
import type { Task } from "../db/schema";

/**
 * Calculates Urgency Score (1 to 10) dynamically from days remaining
 * based on Nudge Project Specification (Section 4.2 & Section 8).
 */
export function calculateUrgencyScore(daysRemaining: number): number {
  if (daysRemaining < 0) return 10; // Overdue
  if (daysRemaining === 0) return 9; // Due today
  if (daysRemaining === 1) return 8; // Urgent (1 day remaining)
  if (daysRemaining === 2) return 6; // Should start soon
  if (daysRemaining >= 3 && daysRemaining <= 4) return 4;
  if (daysRemaining >= 5 && daysRemaining <= 6) return 3;
  return 1; // 7+ days remaining (low urgency)
}

export interface TaskWithPriority extends Task {
  daysRemaining: number;
  urgencyScore: number;
  avoidanceScore: number;
  priorityScore: number;
  isPotentiallyAvoided: boolean;
}

/**
 * Calculates the dynamic Priority Score combining urgency, importance, and avoidance score:
 * priority_score = urgency_score + importance_score + avoidance_score
 * (ADR-0002: Computed dynamically at runtime, never stored in DB)
 */
export function calculateTaskPriority(task: Task, now: Date = new Date()): TaskWithPriority {
  const daysRemaining = calculateDaysRemaining(task.deadline, now);
  const urgencyScore = calculateUrgencyScore(daysRemaining);
  const importanceScore = Math.max(1, Math.min(5, Math.round(Number(task.importance))));
  const avoidanceScore = calculateAvoidanceScore(task.postponeCount);
  const isPotentiallyAvoided = detectPotentiallyAvoided({
    postponeCount: task.postponeCount,
    daysRemaining,
    importance: task.importance,
    status: task.status,
  });

  const priorityScore = urgencyScore + importanceScore + avoidanceScore;

  return {
    ...task,
    daysRemaining,
    urgencyScore,
    avoidanceScore,
    priorityScore,
    isPotentiallyAvoided,
  };
}

/**
 * Generates an adaptive action nudge message tailored to postponement count tiers (Spec Section 8).
 * Adheres strictly to empathetic, non-shaming behavioral support.
 */
export function getAdaptiveNudgeMessage(postponeCount: number): string {
  const count = Math.max(0, Math.round(Number(postponeCount) || 0));
  if (count >= 4) {
    return "งานนี้ถูกเลื่อนซ้ำ ลองลดสิ่งที่ต้องทำตอนนี้ให้เล็กลงไหม?";
  }
  if (count >= 2) {
    return "งานนี้ถูกเลื่อนหลายครั้ง ลองแบ่งงานเป็นขั้นเล็ก ๆ ไหม?";
  }
  return "ลองเริ่ม 10 นาทีไหม?";
}

export interface RecommendationResult {
  task: TaskWithPriority;
  suggestedAction: string;
  recommendationReason: string;
  adaptiveNudgeMessage: string;
}

export function generateRecommendation(
  tasks: Task[],
  now: Date = new Date()
): RecommendationResult | null {
  const activeTasks = tasks
    .filter((t) => t.status !== "COMPLETED" && !t.deletedAt)
    .map((t) => calculateTaskPriority(t, now));

  if (activeTasks.length === 0) {
    return null;
  }

  // Sort by priorityScore DESC, then deadline ASC, then importance DESC
  activeTasks.sort((a, b) => {
    if (b.priorityScore !== a.priorityScore) {
      return b.priorityScore - a.priorityScore;
    }
    if (a.deadline.getTime() !== b.deadline.getTime()) {
      return a.deadline.getTime() - b.deadline.getTime();
    }
    return b.importance - a.importance;
  });

  const top = activeTasks[0];

  let recommendationReason = "งานสำคัญที่สุดที่ควรทำในตอนนี้";
  if (top.isPotentiallyAvoided) {
    recommendationReason = "งานนี้ถูกเลื่อนซ้ำและใกล้กำหนดส่ง ลองเริ่มก้าวเล็กๆ 10 นาที";
  } else if (top.daysRemaining < 0) {
    recommendationReason = `เกินกำหนดส่งแล้ว ${-top.daysRemaining} วัน ควรเริ่มทำทันที`;
  } else if (top.daysRemaining === 0) {
    recommendationReason = "ครบกำหนดส่งวันนี้ ควรเริ่มทำเป็นอันดับแรก";
  } else if (top.daysRemaining === 1) {
    recommendationReason = "เหลือเวลาอีก 1 วัน ควรเริ่มลงมือวันนี้";
  }

  const adaptiveNudgeMessage = getAdaptiveNudgeMessage(top.postponeCount);

  return {
    task: top,
    suggestedAction: "START_10_MINUTES",
    recommendationReason,
    adaptiveNudgeMessage,
  };
}
