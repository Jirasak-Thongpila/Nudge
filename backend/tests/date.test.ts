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

  it("should calculate calendar day difference in specific timezone (Asia/Bangkok)", () => {
    // In UTC, both are on 2026-09-26 (15:00Z and 19:00Z) -> UTC difference would be 0!
    // But in Bangkok (+07:00), 15:00Z is Sep 26 22:00, and 19:00Z is Sep 27 02:00 -> difference must be 1!
    const nowBkkNight = new Date("2026-09-26T15:00:00.000Z"); // 22:00 BKK
    const tomorrowEarlyBkk = new Date("2026-09-26T19:00:00.000Z"); // 02:00 BKK tomorrow

    expect(calculateDaysRemaining(tomorrowEarlyBkk, nowBkkNight, "Asia/Bangkok")).toBe(1);
    expect(calculateDaysRemaining(tomorrowEarlyBkk, nowBkkNight)).toBe(0); // UTC skew without timezone
  });

  it("should throw for invalid date inputs", () => {
    expect(() => calculateDaysRemaining("not-a-date", baseDate)).toThrow();
    expect(() => calculateDaysRemaining(baseDate, "invalid-now")).toThrow();
  });
});
