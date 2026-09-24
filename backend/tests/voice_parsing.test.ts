import { describe, expect, it, mock } from "bun:test";
import { GeminiService } from "../src/services/gemini.service";

describe("GeminiService - Voice Multimodal Audio Parsing", () => {
  it("should parse audio buffer into transcription and CREATE_TASK intent with defaults", async () => {
    const service = new GeminiService();
    // Inject test API key
    (service as any).apiKey = "test-api-key";

    const fakeAudioBuffer = Buffer.from("fake-m4a-audio-data");
    const now = new Date("2026-09-24T10:00:00.000Z");

    // Mock fetch for Gemini API
    const originalFetch = globalThis.fetch;
    globalThis.fetch = mock(async (_url: string | URL | Request) => {
      return new Response(
        JSON.stringify({
          candidates: [
            {
              content: {
                parts: [
                  {
                    text: JSON.stringify({
                      transcription: "พรุ่งนี้ส่งรายงานภาษาอังกฤษ",
                      intent: "CREATE_TASK",
                      title: "ส่งรายงานภาษาอังกฤษ",
                      deadline: "2026-09-25T23:59:59.000Z",
                      importance: 3,
                      estimatedMinutes: 30,
                      replyMessage: "ได้ยินว่า: พรุ่งนี้ส่งรายงานภาษาอังกฤษ",
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
      const result = await service.parseTaskFromAudio(fakeAudioBuffer, "audio/m4a", now);
      expect(result.intent).toBe("CREATE_TASK");
      expect(result.transcription).toBe("พรุ่งนี้ส่งรายงานภาษาอังกฤษ");
      expect(result.title).toBe("ส่งรายงานภาษาอังกฤษ");
      expect(result.importance).toBe(3);
      expect(result.estimatedMinutes).toBe(30);
      expect(result.deadline).toBe("2026-09-25T23:59:59.000Z");
    } finally {
      globalThis.fetch = originalFetch;
    }
  });

  it("should handle conversational or view task audio correctly", async () => {
    const service = new GeminiService();
    (service as any).apiKey = "test-api-key";

    const fakeAudioBuffer = Buffer.from("fake-m4a-audio-data");
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
                      transcription: "งานวันนี้มีอะไรบ้างครับ",
                      intent: "VIEW_TASKS",
                      replyMessage: "นี่คือรายการงานของคุณครับ",
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
      const result = await service.parseTaskFromAudio(fakeAudioBuffer, "audio/m4a");
      expect(result.intent).toBe("VIEW_TASKS");
      expect(result.transcription).toBe("งานวันนี้มีอะไรบ้างครับ");
    } finally {
      globalThis.fetch = originalFetch;
    }
  });

  it("should gracefully handle missing API key or audio parsing error", async () => {
    const service = new GeminiService();
    (service as any).apiKey = "";

    const fakeAudioBuffer = Buffer.from("fake-m4a-audio-data");
    const result = await service.parseTaskFromAudio(fakeAudioBuffer, "audio/m4a");
    expect(result.intent).toBe("UNKNOWN");
    expect(result.replyMessage).toContain("Gemini API Key");
  });
});
