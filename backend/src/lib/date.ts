function getZonedYMD(date: Date, timeZone: string): { y: number; m: number; d: number } {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(date);
  const [y, m, d] = parts.split("-").map(Number);
  return { y, m, d };
}

/**
 * Calculates dynamic Days Remaining between a task's deadline and the reference time.
 * In accordance with CONTEXT.md and ADR-0002, this is derived at runtime, not persisted.
 *
 * @param deadline Target completion timestamp
 * @param now Reference timestamp (defaults to current time)
 * @param timeZone Optional IANA timezone string (e.g. "Asia/Bangkok")
 * @returns Integer day difference (0 = due today, >0 = days remaining, <0 = days overdue)
 */
export function calculateDaysRemaining(
  deadline: Date | string,
  now: Date | string = new Date(),
  timeZone?: string
): number {
  const d = new Date(deadline);
  const n = new Date(now);

  if (isNaN(d.getTime())) {
    throw new Error("Invalid deadline Date");
  }
  if (isNaN(n.getTime())) {
    throw new Error("Invalid reference Date");
  }

  // If a timezone is specified, calculate calendar day difference in that timezone
  if (timeZone) {
    const dParts = getZonedYMD(d, timeZone);
    const nParts = getZonedYMD(n, timeZone);
    const dUtc = Date.UTC(dParts.y, dParts.m - 1, dParts.d);
    const nUtc = Date.UTC(nParts.y, nParts.m - 1, nParts.d);
    const msPerDay = 1000 * 60 * 60 * 24;
    return Math.round((dUtc - nUtc) / msPerDay);
  }

  // Default: use UTC calendar dates to avoid daylight saving and timezone skew
  const dUtc = Date.UTC(d.getFullYear(), d.getMonth(), d.getDate());
  const nUtc = Date.UTC(n.getFullYear(), n.getMonth(), n.getDate());

  const msPerDay = 1000 * 60 * 60 * 24;
  return Math.round((dUtc - nUtc) / msPerDay);
}

