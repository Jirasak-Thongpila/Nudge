import { describe, expect, it, mock } from "bun:test";
import { LineService } from "../src/services/line.service";

describe("In-Chat 10-Minute Focus Session", () => {
  it("should start in-chat focus session and acknowledge in LINE without requiring app deep link", async () => {
    const lineService = new LineService();
    (lineService as any).taskService.getTaskById = mock(async () => ({
      id: 10,
      title: "ทำสรุปรายงาน",
      userId: 1,
      status: "NOT_STARTED",
      importance: 4,
      estimatedMinutes: 30,
      deadline: new Date(),
      postponeCount: 1,
      createdAt: new Date(),
      deletedAt: null,
      lastNudgedAt: null,
      nudgeCount: 0,
    })) as any;

    (lineService as any).taskService.updateTask = mock(async () => ({}));

    let replies: any[] = [];
    lineService.replyMessage = mock(async (_token: string, msgs: any[]) => {
      replies = msgs;
      return true;
    });

    await lineService.startChatFocusSession(1, 10, "reply-token-focus");

    expect(replies.length).toBeGreaterThan(0);
    expect(replies[0].text).toContain("ทำสรุปรายงาน");
    expect(replies[0].text).toContain("10 นาที");
    expect(replies[0].text).toContain("วางมือถือ");
    expect((lineService as any).taskService.updateTask).toHaveBeenCalledWith(1, 10, { status: "IN_PROGRESS" });
  });

  it("should send completion check-in message with quick replies after focus period", async () => {
    const lineService = new LineService();

    let sentPush: any = null;
    lineService.pushMessages = mock(async (_lineUserId: string, msgs: any) => {
      sentPush = msgs;
      return true as any;
    });

    await lineService.sendFocusSessionCheckIn("U123456", 10);

    expect(sentPush).not.toBeNull();
    const pushStr = JSON.stringify(sentPush);
    expect(pushStr).toContain("ครบ 10 นาทีแล้ว");
    expect(pushStr).toContain("ทำงานนี้เสร็จแล้ว");
    expect(pushStr).toContain("ขอทำต่ออีกนิด");
  });

  it("should trigger startChatFocusSession when user sends message matching 'เริ่ม 10 นาที'", async () => {
    const lineService = new LineService();
    (lineService as any).userService.getOrCreateUserByLineUserId = mock(async () => ({ id: 1 }));
    (lineService as any).taskService.getTasksForUser = mock(async () => [
      { id: 15, title: "อ่านหนังสือ", status: "NOT_STARTED" },
    ]);
    lineService.startChatFocusSession = mock(async () => {});

    await lineService.handleWebhookEvents([
      {
        type: "message",
        replyToken: "reply-token-777",
        source: { userId: "Uuser123" },
        message: {
          id: "msg-777",
          type: "text",
          text: "เริ่ม 10 นาที #15",
        },
      },
    ]);

    expect(lineService.startChatFocusSession).toHaveBeenCalledWith(1, 15, "reply-token-777");
  });
});
