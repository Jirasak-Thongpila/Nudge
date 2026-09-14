import { describe, expect, it } from "bun:test";
import { calculateAvoidanceScore, detectPotentiallyAvoided } from "../src/lib/avoidance";

describe("Avoidance Calculation & Pattern Detection (Ticket 04)", () => {
  describe("calculateAvoidanceScore", () => {
    it("should compute postpone_count * 2 capped at 10", () => {
      expect(calculateAvoidanceScore(0)).toBe(0);
      expect(calculateAvoidanceScore(1)).toBe(2);
      expect(calculateAvoidanceScore(2)).toBe(4);
      expect(calculateAvoidanceScore(3)).toBe(6);
      expect(calculateAvoidanceScore(4)).toBe(8);
      expect(calculateAvoidanceScore(5)).toBe(10);
      expect(calculateAvoidanceScore(6)).toBe(10);
      expect(calculateAvoidanceScore(20)).toBe(10);
    });

    it("should return 0 for negative or invalid inputs", () => {
      expect(calculateAvoidanceScore(-1)).toBe(0);
      expect(calculateAvoidanceScore(NaN)).toBe(0);
    });
  });

  describe("detectPotentiallyAvoided", () => {
    it("should return false for completed tasks regardless of postponements", () => {
      expect(
        detectPotentiallyAvoided({
          postponeCount: 5,
          daysRemaining: 1,
          importance: 5,
          status: "COMPLETED",
        })
      ).toBe(false);
    });

    it("should return true for high importance tasks near deadline that are repeatedly postponed", () => {
      // High importance (5), due tomorrow (1 day), postponed 2 times
      expect(
        detectPotentiallyAvoided({
          postponeCount: 2,
          daysRemaining: 1,
          importance: 5,
          status: "NOT_STARTED",
        })
      ).toBe(true);

      // Overdue task (daysRemaining <= 0) with importance 4 and postponed 2 times
      expect(
        detectPotentiallyAvoided({
          postponeCount: 2,
          daysRemaining: -1,
          importance: 4,
          status: "IN_PROGRESS",
        })
      ).toBe(true);
    });

    it("should return false for tasks with only 0 or 1 postpone", () => {
      expect(
        detectPotentiallyAvoided({
          postponeCount: 1,
          daysRemaining: 1,
          importance: 5,
          status: "NOT_STARTED",
        })
      ).toBe(false);

      expect(
        detectPotentiallyAvoided({
          postponeCount: 0,
          daysRemaining: 0,
          importance: 5,
          status: "NOT_STARTED",
        })
      ).toBe(false);
    });

    it("should return false for low importance tasks far from deadline", () => {
      expect(
        detectPotentiallyAvoided({
          postponeCount: 2,
          daysRemaining: 10,
          importance: 2,
          status: "NOT_STARTED",
        })
      ).toBe(false);
    });

    it("should return true for chronic postponements (>= 3) within active horizon", () => {
      expect(
        detectPotentiallyAvoided({
          postponeCount: 3,
          daysRemaining: 4,
          importance: 3,
          status: "NOT_STARTED",
        })
      ).toBe(true);
    });
  });
});
