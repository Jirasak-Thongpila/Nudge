import { describe, expect, it, mock } from "bun:test";
import { LineService } from "../src/services/line.service";

describe("LINE Voice Message & Confirmation Flow", () => {
  it("should handle audio message event, call downloadAudioContent, and reply with confirmation card", async () => {
    const lineService = new LineService();
    (lineService as any).channelAccessToken = "test-token";

    const mockAudioBuffer = Buffer.from("audio-bytes");
    lineService.downloadAudioContent = mock(async () => mockAudioBuffer);

    (lineService as any).geminiService.parseTaskFromAudio = mock(async () => ({
      intent: "CREATE_TASK",
      transcription: "พรุ่งนี้ส่งการบ้านคณิต",
      title: "ส่งการบ้านคณิต",
      deadline: "2026-09-25T23:59:59.000Z",
      importance: 3,
      estimatedMinutes: 30,
    }));

    let sentMessages: any[] = [];
    lineService.replyMessage = mock(async (_token: string, msgs: any[]) => {
      sentMessages = msgs;
      return true;
    });

    const result = await lineService.handleWebhookEvents([
      {
        type: "message",
        replyToken: "reply-token-123",
        source: { userId: "U12345" },
        message: {
          id: "msg-456",
          type: "audio",
          duration: 3500,
        },
      },
    ]);

    expect(result.handledCount).toBe(1);
    expect(result.repliesSent).toBe(1);
    expect(lineService.downloadAudioContent).toHaveBeenCalledWith("msg-456");
    expect(sentMessages.length).toBeGreaterThan(0);
    expect(sentMessages[0].type).toBe("flex");
    const jsonStr = JSON.stringify(sentMessages[0]);
    expect(jsonStr).toContain("ส่งการบ้านคณิต");
    expect(jsonStr).toContain("พรุ่งนี้ส่งการบ้านคณิต");
  });

  it("should handle non-task voice audio (e.g. view tasks) by executing the intent directly", async () => {
    const lineService = new LineService();
    (lineService as any).channelAccessToken = "test-token";

    lineService.downloadAudioContent = mock(async () => Buffer.from("audio-bytes"));

    (lineService as any).geminiService.parseTaskFromAudio = mock(async () => ({
      intent: "VIEW_TASKS",
      transcription: "ขอดูงานหน่อยครับ",
    }));

    let sentMessages: any[] = [];
    lineService.replyMessage = mock(async (_token: string, msgs: any[]) => {
      sentMessages = msgs;
      return true;
    });

    const result = await lineService.handleWebhookEvents([
      {
        type: "message",
        replyToken: "reply-token-123",
        source: { userId: "U12345" },
        message: {
          id: "msg-789",
          type: "audio",
          duration: 2000,
        },
      },
    ]);

    expect(result.handledCount).toBe(1);
    expect(result.repliesSent).toBe(1);
    expect(sentMessages.length).toBeGreaterThan(0);
    expect(sentMessages[0].type).toBe("flex"); // Task list flex message
  });
});
