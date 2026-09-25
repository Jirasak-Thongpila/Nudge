import { describe, expect, it, mock } from "bun:test";
import { GeminiService } from "../src/services/gemini.service";

describe("GeminiService - Automatic Model Fallback on Quota (429) & Server Errors", () => {
  it("should automatically fall back to secondary model when primary returns 429", async () => {
    const service = new GeminiService(
      "test-key",
      "gemini-primary-model",
      ["gemini-fallback-model"]
    );

    const calls: string[] = [];
    const originalFetch = globalThis.fetch;
    globalThis.fetch = mock(async (url: string | URL | Request) => {
      const urlStr = url.toString();
      calls.push(urlStr);

      if (urlStr.includes("gemini-primary-model")) {
        return new Response(
          JSON.stringify({
            error: {
              code: 429,
              message: "Resource exhausted",
              status: "RESOURCE_EXHAUSTED",
            },
          }),
          { status: 429, headers: { "Content-Type": "application/json" } }
        );
      }

      if (urlStr.includes("gemini-fallback-model")) {
        return new Response(
          JSON.stringify({
            candidates: [
              {
                content: {
                  parts: [
                    {
                      text: JSON.stringify({
                        intent: "CREATE_TASK",
                        title: "ไปเล่นเกมที่ห้องสาขา",
                        deadline: "2026-09-26T12:00:00.000Z",
                        importance: 3,
                        estimatedMinutes: 30,
                      }),
                    },
                  ],
                },
              },
            ],
          }),
          { status: 200, headers: { "Content-Type": "application/json" } }
        );
      }

      return new Response("Not found", { status: 404 });
    }) as any;

    try {
      const result = await service.parseTaskIntent("พรุ่งตอน 12.00 ฉันต้องไปเล่นเกมที่ห้องสาขา");
      expect(result.intent).toBe("CREATE_TASK");
      expect(result.title).toBe("ไปเล่นเกมที่ห้องสาขา");
      expect(calls.length).toBe(2);
      expect(calls[0]).toContain("gemini-primary-model");
      expect(calls[1]).toContain("gemini-fallback-model");
    } finally {
      globalThis.fetch = originalFetch;
    }
  });

  it("should fall back for audio parsing when primary audio model returns 429", async () => {
    const service = new GeminiService(
      "test-key",
      "gemini-primary-audio",
      ["gemini-2.5-flash-lite"]
    );

    const calls: string[] = [];
    const originalFetch = globalThis.fetch;
    globalThis.fetch = mock(async (url: string | URL | Request) => {
      const urlStr = url.toString();
      calls.push(urlStr);

      if (urlStr.includes("gemini-primary-audio")) {
        return new Response(
          JSON.stringify({ error: { code: 429, message: "Resource exhausted" } }),
          { status: 429, headers: { "Content-Type": "application/json" } }
        );
      }

      return new Response(
        JSON.stringify({
          candidates: [
            {
              content: {
                parts: [
                  {
                    text: JSON.stringify({
                      transcription: "ส่งการบ้านวันพรุ่งนี้",
                      intent: "CREATE_TASK",
                      title: "ส่งการบ้าน",
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
      const fakeBuffer = Buffer.from("fake-audio");
      const result = await service.parseTaskFromAudio(fakeBuffer, "audio/webm");
      expect(result.intent).toBe("CREATE_TASK");
      expect(result.title).toBe("ส่งการบ้าน");
      expect(calls.length).toBe(2);
      expect(calls[0]).toContain("gemini-primary-audio");
      expect(calls[1]).toContain("gemini-2.5-flash-lite");
    } finally {
      globalThis.fetch = originalFetch;
    }
  });

  it("should normalize female polite particles into male polite particles (ครับ/นะครับ)", () => {
    const service = new GeminiService("");
    expect(service.normalizePoliteParticles("สวัสดีค่ะ มีอะไรให้ช่วยไหมคะ")).toBe(
      "สวัสดีครับ มีอะไรให้ช่วยไหมครับ"
    );
    expect(service.normalizePoliteParticles("สู้ๆ นะคะ มีอะไรปรึกษาได้นะคะ")).toBe(
      "สู้ๆ นะครับ มีอะไรปรึกษาได้นะครับ"
    );
    expect(service.normalizePoliteParticles("สวัสดีค่ะ/ครับ")).toBe("สวัสดีครับ");
    expect(service.normalizePoliteParticles("คะแนน 100")).toBe("คะแนน 100");
  });
});

