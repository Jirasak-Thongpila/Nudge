import { describe, expect, it } from "bun:test";
import {
  calculateUrgencyScore,
  calculateTaskPriority,
  generateRecommendation,
  getAdaptiveNudgeMessage,
} from "../src/lib/priority";
import type { Task } from "../src/db/schema";

describe("Priority Scoring & Recommendation (Ticket 05)", () => {
  const baseNow = new Date("2026-09-14T10:00:00.000Z");

  describe("calculateUrgencyScore", () => {
    it("should return correct urgency based on days remaining", () => {
      expect(calculateUrgencyScore(-2)).toBe(10); // Overdue
      expect(calculateUrgencyScore(0)).toBe(9); // Due today
      expect(calculateUrgencyScore(1)).toBe(8); // Urgent (1 day remaining)
      expect(calculateUrgencyScore(2)).toBe(6); // Should start soon
      expect(calculateUrgencyScore(3)).toBe(4); // 3-4 days
      expect(calculateUrgencyScore(6)).toBe(3); // 5-6 days
      expect(calculateUrgencyScore(10)).toBe(1); // 7+ days (low urgency)
    });
  });

  describe("calculateTaskPriority", () => {
    it("should compute priority_score = urgency + importance + avoidance", () => {
      const task: Task = {
        id: 123,
        userId: 1,
        title: "Mini Project",
        deadline: new Date("2026-09-15T23:59:00.000Z"), // 1 day remaining -> urgency = 8
        importance: 5, // importance = 5
        estimatedMinutes: 120,
        status: "NOT_STARTED",
        postponeCount: 3, // avoidance = 6
        createdAt: new Date("2026-09-10T10:00:00.000Z"),
        deletedAt: null,
      };

      const result = calculateTaskPriority(task, baseNow);

      expect(result.daysRemaining).toBe(1);
      expect(result.urgencyScore).toBe(8);
      expect(result.avoidanceScore).toBe(6);
      expect(result.priorityScore).toBe(19); // 8 + 5 + 6 = 19
      expect(result.isPotentiallyAvoided).toBe(true);
    });
  });

  describe("generateRecommendation", () => {
    it("should return null if there are no pending tasks", () => {
      expect(generateRecommendation([], baseNow)).toBeNull();

      const completedTask: Task = {
        id: 1,
        userId: 1,
        title: "Done Task",
        deadline: new Date("2026-09-15T00:00:00Z"),
        importance: 5,
        estimatedMinutes: 30,
        status: "COMPLETED",
        postponeCount: 0,
        createdAt: new Date(),
        deletedAt: null,
      };
      expect(generateRecommendation([completedTask], baseNow)).toBeNull();
    });

    it("should prioritize avoided high-urgency task and provide suggestedAction START_10_MINUTES", () => {
      const taskEasy: Task = {
        id: 1,
        userId: 1,
        title: "Easy Homework",
        deadline: new Date("2026-09-20T00:00:00Z"), // 6 days -> urgency 3
        importance: 2,
        estimatedMinutes: 20,
        status: "NOT_STARTED",
        postponeCount: 0,
        createdAt: new Date(),
        deletedAt: null,
      };

      const taskAvoided: Task = {
        id: 2,
        userId: 1,
        title: "Difficult Mini Project",
        deadline: new Date("2026-09-15T18:00:00Z"), // 1 day -> urgency 8
        importance: 5,
        estimatedMinutes: 120,
        status: "NOT_STARTED",
        postponeCount: 2, // avoidance 4 -> priority 17
        createdAt: new Date(),
        deletedAt: null,
      };

      const recommendation = generateRecommendation([taskEasy, taskAvoided], baseNow);

      expect(recommendation).not.toBeNull();
      expect(recommendation!.task.id).toBe(2);
      expect(recommendation!.task.title).toBe("Difficult Mini Project");
      expect(recommendation!.suggestedAction).toBe("START_10_MINUTES");
      expect(recommendation!.recommendationReason).toContain("10 นาที");
      expect(recommendation!.adaptiveNudgeMessage).toBe("งานนี้ถูกเลื่อนหลายครั้ง ลองแบ่งงานเป็นขั้นเล็ก ๆ ไหม?");
    });
  });

  describe("Adaptive Action Nudge Messaging (Ticket 08 & Spec Section 8)", () => {
    it("should provide tier 1 nudge for 0 or 1 postponements", () => {
      expect(getAdaptiveNudgeMessage(0)).toBe("ลองเริ่ม 10 นาทีไหม?");
      expect(getAdaptiveNudgeMessage(1)).toBe("ลองเริ่ม 10 นาทีไหม?");
    });

    it("should provide tier 2 nudge for 2 or 3 postponements", () => {
      expect(getAdaptiveNudgeMessage(2)).toBe("งานนี้ถูกเลื่อนหลายครั้ง ลองแบ่งงานเป็นขั้นเล็ก ๆ ไหม?");
      expect(getAdaptiveNudgeMessage(3)).toBe("งานนี้ถูกเลื่อนหลายครั้ง ลองแบ่งงานเป็นขั้นเล็ก ๆ ไหม?");
    });

    it("should provide tier 3 nudge for 4 or more postponements", () => {
      expect(getAdaptiveNudgeMessage(4)).toBe("งานนี้ถูกเลื่อนซ้ำ ลองลดสิ่งที่ต้องทำตอนนี้ให้เล็กลงไหม?");
      expect(getAdaptiveNudgeMessage(7)).toBe("งานนี้ถูกเลื่อนซ้ำ ลองลดสิ่งที่ต้องทำตอนนี้ให้เล็กลงไหม?");
    });

    it("Language Audit: all messages must contain zero shaming or guilt-inducing terms", () => {
      const bannedWords = ["ขี้เกียจ", "ผลัดวัน", "ล้มเหลว", "ทำโทษ", "สาย", "lazy", "procrastinate", "snooze", "penalty"];
      const messages = [
        getAdaptiveNudgeMessage(0),
        getAdaptiveNudgeMessage(1),
        getAdaptiveNudgeMessage(2),
        getAdaptiveNudgeMessage(3),
        getAdaptiveNudgeMessage(4),
        getAdaptiveNudgeMessage(10),
      ];

      for (const msg of messages) {
        for (const banned of bannedWords) {
          expect(msg.toLowerCase()).not.toContain(banned);
        }
      }
    });
  });
});
