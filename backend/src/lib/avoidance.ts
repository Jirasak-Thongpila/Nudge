/**
 * Avoidance score calculation and behavioral pattern detection
 * in accordance with CONTEXT.md and Nudge Project Specification (Sections 6 & 7).
 */

/**
 * Calculates the capped Avoidance Score:
 * avoidance_score = min(postpone_count * 2, 10)
 *
 * @param postponeCount Number of deliberate, explicit postponements
 * @returns Score between 0 and 10
 */
export function calculateAvoidanceScore(postponeCount: number): number {
  if (isNaN(postponeCount) || postponeCount <= 0) {
    return 0;
  }
  return Math.min(Math.floor(postponeCount) * 2, 10);
}

export interface AvoidanceDetectionInput {
  postponeCount: number;
  daysRemaining: number;
  importance: number;
  status: string;
}

/**
 * Rule-based Avoidance Detection.
 * Infers observable behavior without labeling the user as lazy or claiming absolute certainty.
 *
 * Patterns:
 * 1. High importance (>= 4), near deadline (daysRemaining <= 2), repeatedly postponed (postponeCount >= 2)
 * 2. Frequent postponement (postponeCount >= 3) within active horizon (daysRemaining <= 5)
 */
export function detectPotentiallyAvoided(input: AvoidanceDetectionInput): boolean {
  // Completed tasks are never classified as potentially avoided
  if (input.status === "COMPLETED") {
    return false;
  }

  const { postponeCount, daysRemaining, importance } = input;

  // Pattern 1: Near deadline + High importance + Repeated postponement
  const isHighImportanceNearDeadline =
    importance >= 4 && daysRemaining <= 2 && postponeCount >= 2;

  // Pattern 2: Frequent postponement within active timeframe
  const isFrequentPostponement = postponeCount >= 3 && daysRemaining <= 5;

  return isHighImportanceNearDeadline || isFrequentPostponement;
}
