import { TaskService, taskService as defaultTaskService, type TaskWithDerived } from "./task.service";
import { UserService, userService as defaultUserService } from "./user.service";
import type { User } from "../db/schema";

export interface LineFlexMessage {
  type: "flex";
  altText: string;
  contents: Record<string, any>;
}

export interface LinePushResult {
  success: boolean;
  messageId?: string;
  recipientLineUserId: string;
  flexMessage: LineFlexMessage;
}

export class LineService {
  private channelAccessToken: string;

  constructor(
    private userService: UserService = defaultUserService,
    private taskService: TaskService = defaultTaskService,
    channelAccessToken?: string
  ) {
    this.channelAccessToken = channelAccessToken ?? process.env.LINE_CHANNEL_ACCESS_TOKEN ?? "";
  }

  /**
   * Constructs an empathetic LINE Flex Message containing a direct deep-link CTA.
   */
  createActionNudgeFlexMessage(task: TaskWithDerived): LineFlexMessage {
    const deepLinkUrl = `nudge://focus?taskId=${task.id}`;
    const nudgeText = task.adaptiveNudgeMessage || "ลองเริ่ม 10 นาทีไหม?";
    const altText = `Nudge: ${task.title} — ${nudgeText}`;

    const deadlineText =
      task.daysRemaining < 0
        ? `เลยกำหนด ${Math.abs(task.daysRemaining)} วัน`
        : task.daysRemaining === 0
        ? "ครบกำหนดวันนี้"
        : `เหลือ ${task.daysRemaining} วัน`;

    const contents = {
      type: "bubble",
      size: "kilo",
      header: {
        type: "box",
        layout: "vertical",
        backgroundColor: "#4F46E5",
        paddingAll: "16px",
        contents: [
          {
            type: "text",
            text: "🌱 NUDGE • ACTION REMINDER",
            color: "#C7D2FE",
            size: "xxs",
            weight: "bold",
          },
          {
            type: "text",
            text: task.title,
            color: "#FFFFFF",
            size: "lg",
            weight: "bold",
            margin: "xs",
            wrap: true,
          },
        ],
      },
      body: {
        type: "box",
        layout: "vertical",
        paddingAll: "16px",
        spacing: "md",
        contents: [
          {
            type: "text",
            text: `“${nudgeText}”`,
            color: "#4338CA",
            weight: "bold",
            size: "sm",
            wrap: true,
          },
          {
            type: "box",
            layout: "horizontal",
            contents: [
              {
                type: "text",
                text: `กำหนดส่ง: ${deadlineText}`,
                color: "#64748B",
                size: "xs",
                flex: 1,
              },
              {
                type: "text",
                text: `ความสำคัญ: ${task.importance}/5`,
                color: "#64748B",
                size: "xs",
                align: "end",
              },
            ],
          },
        ],
      },
      footer: {
        type: "box",
        layout: "vertical",
        paddingAll: "16px",
        paddingTop: "0px",
        contents: [
          {
            type: "button",
            style: "primary",
            color: "#4F46E5",
            height: "sm",
            action: {
              type: "uri",
              label: "เริ่ม 10 นาที",
              uri: deepLinkUrl,
            },
          },
        ],
      },
    };

    return {
      type: "flex",
      altText,
      contents,
    };
  }

  /**
   * Sends an external action nudge to the user's linked LINE account.
   */
  async sendActionNudge(userId: number, taskId: number): Promise<LinePushResult> {
    const task = await this.taskService.getTaskById(userId, taskId);
    if (!task) {
      throw new Error("Task not found");
    }

    const user = await this.userService.findById(userId);

    if (!user || !user.lineUserId) {
      throw new Error("User has not linked a LINE account");
    }

    const flexMessage = this.createActionNudgeFlexMessage(task);

    // If channel token is provided, execute real HTTP request to LINE Messaging API
    if (this.channelAccessToken) {
      const response = await fetch("https://api.line.me/v2/bot/message/push", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${this.channelAccessToken}`,
        },
        body: JSON.stringify({
          to: user.lineUserId,
          messages: [flexMessage],
        }),
      });

      if (!response.ok) {
        const errorText = await response.text();
        throw new Error(`LINE API error: ${response.status} - ${errorText}`);
      }
    }

    return {
      success: true,
      messageId: `mock-msg-${Date.now()}`,
      recipientLineUserId: user.lineUserId,
      flexMessage,
    };
  }

  /**
   * Sends a reply message to LINE via the replyToken.
   */
  async replyMessage(replyToken: string, messages: any[]): Promise<boolean> {
    if (!this.channelAccessToken) {
      return false;
    }

    try {
      const response = await fetch("https://api.line.me/v2/bot/message/reply", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${this.channelAccessToken}`,
        },
        body: JSON.stringify({
          replyToken,
          messages,
        }),
      });

      return response.ok;
    } catch (e) {
      console.error("Failed to send LINE reply:", e);
      return false;
    }
  }

  /**
   * Handles incoming LINE webhook events.
   * Responds with user ID on follow or text query to streamline development and account linking.
   */
  async handleWebhookEvents(events: any[]): Promise<{ handledCount: number; repliesSent: number }> {
    let repliesSent = 0;

    for (const event of events) {
      const lineUserId = event.source?.userId;
      const replyToken = event.replyToken;

      if (!replyToken || !lineUserId) continue;

      if (event.type === "follow") {
        await this.replyMessage(replyToken, [
          {
            type: "text",
            text: `🌱 ยินดีต้อนรับสู่ Nudge!\n\nLINE User ID ของคุณคือ:\n${lineUserId}\n\nคัดลอกรหัสนี้ไปกรอกในแอป Nudge (หน้า Task Detail -> เชื่อมต่อ LINE OA) เพื่อรับ Action Nudge ได้เลยครับ!`,
          },
        ]);
        repliesSent++;
      } else if (event.type === "message" && event.message?.type === "text") {
        const text = (event.message.text || "").trim().toLowerCase();
        if (text === "id" || text === "userid" || text === "uid" || text === "เชื่อมต่อ" || text === "ลิงก์") {
          await this.replyMessage(replyToken, [
            {
              type: "text",
              text: `🆔 LINE User ID ของคุณคือ:\n${lineUserId}`,
            },
          ]);
          repliesSent++;
        }
      }
    }

    return { handledCount: events.length, repliesSent };
  }
}

export const lineService = new LineService();
