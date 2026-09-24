import { describe, expect, it, mock } from "bun:test";
import { GeminiService } from "../src/services/gemini.service";
import { getRandomRotatedNudge } from "../src/lib/nudge";

describe("Dynamic Nudge Copy & Persona Audit", () => {
  it("should generate contextual dynamic Thai copy from Gemini", async () => {
    const service = new GeminiService();
    (service as any).apiKey = "test-api-key";

    const originalFetch = globalThis.fetch;
    globalThis.fetch = mock(async () => {
      return new Response(
        JSON.stringify({
          candidates: [
            {
              content: {
                parts: [
                  {
                    text: JSON.stringify({
                      nudgeMessage: "บ่ายนี้ลองเปิดสไลด์สัมมนามาดูหัวข้อสัก 10 นาทีไหมครับ สบายๆ เริ่มก้าวแรกกันนะ",
                    }),
                  },
                ],
              },
            },
          ],
        }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }) as any;

    try {
      const message = await service.generateDynamicNudge(
        { title: "สไลด์สัมมนา", postponeCount: 2, deadline: new Date(), importance: 4 },
        "afternoon"
      );
      expect(message).toContain("สไลด์สัมมนา");
      expect(message).toContain("10 นาที");
      // Zero-shaming audit
      expect(message).not.toMatch(/ขี้เกียจ|ทำไมยังไม่ทำ|เดี๋ยวไม่ทัน|แย่/);
    } finally {
      globalThis.fetch = originalFetch;
    }
  });

  it("should rotate varied fallback messages without shame terms when API is offline", () => {
    const forbiddenWords = ["ขี้เกียจ", "ทำไมยังไม่ทำ", "เดี๋ยวไม่ทัน", "แย่"];
    for (let i = 0; i < 20; i++) {
      const msg = getRandomRotatedNudge("มินิโปรเจกต์", i % 5, "morning");
      expect(msg).toContain("มินิโปรเจกต์");
      for (const forbidden of forbiddenWords) {
        expect(msg.includes(forbidden)).toBe(false);
      }
    }
  });
});
