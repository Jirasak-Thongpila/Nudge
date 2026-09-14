/**
 * Calculates dynamic Days Remaining between a task's deadline and the reference time.
 * In accordance with CONTEXT.md and ADR-0002, this is derived at runtime, not persisted.
 *
 * @param deadline Target completion timestamp
 * @param now Reference timestamp (defaults to current time)
 * @returns Integer day difference (0 = due today, >0 = days remaining, <0 = days overdue)
 */
export function calculateDaysRemaining(
  deadline: Date | string,
  now: Date | string = new Date()
): number {
  const d = new Date(deadline);
  const n = new Date(now);

  if (isNaN(d.getTime())) {
    throw new Error("Invalid deadline Date");
  }
  if (isNaN(n.getTime())) {
    throw new Error("Invalid reference Date");
  }

  // Use UTC calendar dates to avoid daylight saving and timezone skew
  const dUtc = Date.UTC(d.getFullYear(), d.getMonth(), d.getDate());
  const nUtc = Date.UTC(n.getFullYear(), n.getMonth(), n.getDate());

  const msPerDay = 1000 * 60 * 60 * 24;
  return Math.round((dUtc - nUtc) / msPerDay);
}
