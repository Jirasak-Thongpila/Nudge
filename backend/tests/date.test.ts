import { describe, expect, it } from "bun:test";
import { calculateDaysRemaining } from "../src/lib/date";

describe("Dynamic Days Remaining Calculation (ADR-0002)", () => {
  const baseDate = new Date("2026-09-14T10:00:00.000Z");

  it("should return 0 when deadline is on the same calendar day (due today)", () => {
    const todayDeadline = new Date("2026-09-14T23:59:00.000Z");
    expect(calculateDaysRemaining(todayDeadline, baseDate)).toBe(0);
  });

  it("should return positive numbers for future deadlines", () => {
    const tomorrow = new Date("2026-09-15T12:00:00.000Z");
    const nextWeek = new Date("2026-09-21T18:00:00.000Z");

    expect(calculateDaysRemaining(tomorrow, baseDate)).toBe(1);
    expect(calculateDaysRemaining(nextWeek, baseDate)).toBe(7);
  });

  it("should return negative numbers for past deadlines (overdue)", () => {
    const yesterday = new Date("2026-09-13T23:59:00.000Z");
    const threeDaysAgo = new Date("2026-09-11T12:00:00.000Z");

    expect(calculateDaysRemaining(yesterday, baseDate)).toBe(-1);
    expect(calculateDaysRemaining(threeDaysAgo, baseDate)).toBe(-3);
  });

  it("should accept ISO string representations as arguments", () => {
    expect(
      calculateDaysRemaining("2026-09-16T15:00:00.000Z", "2026-09-14T10:00:00.000Z")
    ).toBe(2);
  });

  it("should throw for invalid date inputs", () => {
    expect(() => calculateDaysRemaining("not-a-date", baseDate)).toThrow();
    expect(() => calculateDaysRemaining(baseDate, "invalid-now")).toThrow();
  });
});
