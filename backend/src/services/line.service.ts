import { TaskService, taskService as defaultTaskService, type TaskWithDerived } from "./task.service";
import { UserService, userService as defaultUserService } from "./user.service";
import { GeminiService, geminiService as defaultGeminiService } from "./gemini.service";
import { verifyLineSignature } from "../lib/line-signature";
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
  private channelSecret: string;
  private liffId: string;

  constructor(
    private userService: UserService = defaultUserService,
    private taskService: TaskService = defaultTaskService,
    private geminiService: GeminiService = defaultGeminiService,
    channelAccessToken?: string,
    channelSecret?: string,
    liffId?: string
  ) {
    this.channelAccessToken = channelAccessToken ?? process.env.LINE_CHANNEL_ACCESS_TOKEN ?? "";
    this.channelSecret = channelSecret ?? process.env.LINE_CHANNEL_SECRET ?? "";
    this.liffId = liffId ?? process.env.LINE_LIFF_ID ?? "";
  }

  /**
   * Whether a LINE channel secret is configured.
   * When absent, signature verification is skipped (development convenience).
   */
  isSignatureVerificationEnabled(): boolean {
    return this.channelSecret.length > 0;
  }

  /**
   * Verifies the `X-Line-Signature` header against the raw webhook body.
   */
  verifySignature(rawBody: string, signature: string | null | undefined): boolean {
    if (!this.isSignatureVerificationEnabled()) {
      return true;
    }
    return verifyLineSignature(rawBody, signature, this.channelSecret);
  }

  /**
   * Constructs an empathetic LINE Flex Message containing a direct deep-link CTA.
   */
  createActionNudgeFlexMessage(
    task: Pick<TaskWithDerived, "id" | "title" | "importance" | "daysRemaining"> & {
      adaptiveNudgeMessage?: string;
    }
  ): LineFlexMessage {
    const deepLinkUrl = this.liffId
      ? `https://liff.line.me/${this.liffId}?taskId=${task.id}`
      : `nudge://focus?taskId=${task.id}`;
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
   * Constructs a Flex Message confirmation for newly created tasks via AI NLP.
   */
  createTaskCreatedFlexMessage(task: TaskWithDerived): LineFlexMessage {
    const liffUrl = this.liffId
      ? `https://liff.line.me/${this.liffId}?taskId=${task.id}`
      : `nudge://focus?taskId=${task.id}`;
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
        backgroundColor: "#10B981",
        paddingAll: "16px",
        contents: [
          {
            type: "text",
            text: "✅ บันทึกงานสำเร็จแล้ว (AI Created)",
            color: "#D1FAE5",
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
            type: "box",
            layout: "horizontal",
            contents: [
              {
                type: "text",
                text: `📅 กำหนดส่ง: ${deadlineText}`,
                color: "#475569",
                size: "xs",
                flex: 1,
              },
              {
                type: "text",
                text: `⭐ ความสำคัญ: ${task.importance}/5`,
                color: "#475569",
                size: "xs",
                align: "end",
              },
            ],
          },
          {
            type: "text",
            text: `⏱️ เวลาที่คาดว่าจะใช้: ${task.estimatedMinutes} นาที`,
            color: "#64748B",
            size: "xs",
          },
        ],
      },
      footer: {
        type: "box",
        layout: "vertical",
        paddingAll: "16px",
        paddingTop: "0px",
        spacing: "sm",
        contents: [
          {
            type: "button",
            style: "primary",
            color: "#4F46E5",
            height: "sm",
            action: {
              type: "uri",
              label: "เริ่ม 10 นาที",
              uri: liffUrl,
            },
          },
        ],
      },
    };

    return {
      type: "flex",
      altText: `บันทึกงาน: ${task.title} สำเร็จแล้ว`,
      contents,
    };
  }

  /**
   * Constructs a Flex Message summarizing the user's active tasks.
   */
  createTaskListFlexMessage(tasks: TaskWithDerived[]): LineFlexMessage {
    const liffBaseUrl = this.liffId ? `https://liff.line.me/${this.liffId}` : `nudge://app`;

    if (tasks.length === 0) {
      return {
        type: "flex",
        altText: "รายการงานของคุณ",
        contents: {
          type: "bubble",
          size: "kilo",
          body: {
            type: "box",
            layout: "vertical",
            paddingAll: "20px",
            contents: [
              {
                type: "text",
                text: "✨ ไม่มีงานค้างในระบบ",
                weight: "bold",
                size: "md",
                color: "#0F172A",
              },
              {
                type: "text",
                text: "คุณจัดการงานทั้งหมดเรียบร้อยแล้ว หรือพิมพ์บอกงานใหม่เพื่อให้ Nudge ช่วยเตือนได้เลยครับ",
                color: "#64748B",
                size: "xs",
                margin: "sm",
                wrap: true,
              },
            ],
          },
        },
      };
    }

    const taskItems = tasks.slice(0, 5).map((t) => ({
      type: "box",
      layout: "horizontal",
      spacing: "md",
      contents: [
        {
          type: "text",
          text: t.title,
          size: "sm",
          color: "#1E293B",
          weight: "bold",
          flex: 3,
          wrap: true,
        },
        {
          type: "text",
          text: t.daysRemaining < 0 ? `เลย ${Math.abs(t.daysRemaining)} วัน` : `${t.daysRemaining} วัน`,
          size: "xs",
          color: t.daysRemaining <= 1 ? "#EF4444" : "#64748B",
          align: "end",
          flex: 1,
        },
      ],
    }));

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
            text: "📋 รายการงานของคุณ (NUDGE TASKS)",
            color: "#C7D2FE",
            size: "xxs",
            weight: "bold",
          },
          {
            type: "text",
            text: `มีงานทั้งหมด ${tasks.length} รายการ`,
            color: "#FFFFFF",
            size: "md",
            weight: "bold",
            margin: "xs",
          },
        ],
      },
      body: {
        type: "box",
        layout: "vertical",
        paddingAll: "16px",
        spacing: "md",
        contents: taskItems,
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
              label: "ดูงานทั้งหมด",
              uri: liffBaseUrl,
            },
          },
        ],
      },
    };

    return {
      type: "flex",
      altText: `รายการงานของคุณ (${tasks.length} รายการ)`,
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
      await this.pushMessages(user.lineUserId, [flexMessage]);
    }

    return {
      success: true,
      messageId: `msg-${Date.now()}`,
      recipientLineUserId: user.lineUserId,
      flexMessage,
    };
  }

  /**
   * Starts a loading animation (chat dots) in the LINE chat.
   */
  async sendLoadingIndicator(chatId: string, loadingSeconds: number = 5): Promise<boolean> {
    if (!this.channelAccessToken) return false;
    try {
      const response = await fetch("https://api.line.me/v2/bot/chat/loading/start", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${this.channelAccessToken}`,
        },
        body: JSON.stringify({
          chatId,
          loadingSeconds,
        }),
      });
      return response.ok;
    } catch {
      return false;
    }
  }

  /**
   * Sends push messages to a specific LINE user ID.
   */
  async pushMessages(to: string, messages: any[]): Promise<boolean> {
    if (!this.channelAccessToken) {
      console.warn("LINE pushMessages: channelAccessToken is not set");
      return false;
    }

    try {
      const response = await fetch("https://api.line.me/v2/bot/message/push", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${this.channelAccessToken}`,
        },
        body: JSON.stringify({
          to,
          messages,
        }),
      });

      if (!response.ok) {
        const errorText = await response.text();
        console.error(`LINE push API error: ${response.status} - ${errorText}`);
      }

      return response.ok;
    } catch (e) {
      console.error("Failed to send LINE push:", e);
      return false;
    }
  }

  /**
   * Sends a reply message to LINE via the replyToken.
   */
  async replyMessage(replyToken: string, messages: any[]): Promise<boolean> {
    if (!this.channelAccessToken) {
      console.warn("LINE replyMessage: channelAccessToken is not set");
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

      if (!response.ok) {
        const errorText = await response.text();
        console.error(`LINE reply API error: ${response.status} - ${errorText}`);
      }

      return response.ok;
    } catch (e) {
      console.error("Failed to send LINE reply:", e);
      return false;
    }
  }

  /**
   * Handles incoming LINE webhook events.
   * Leverages Gemini 2.5 Flash for natural language Thai task creation & intent routing.
   */
  async handleWebhookEvents(events: any[]): Promise<{ handledCount: number; repliesSent: number }> {
    let repliesSent = 0;

    for (const event of events) {
      const lineUserId = event.source?.userId;
      const replyToken = event.replyToken;

      if (!replyToken || !lineUserId) continue;

      if (event.type === "follow") {
        await this.userService.getOrCreateUserByLineUserId(lineUserId);
        const liffBaseUrl = this.liffId ? `https://liff.line.me/${this.liffId}` : undefined;
        const msg = liffBaseUrl
          ? `🌱 ยินดีต้อนรับสู่ Nudge!\n\nเปิดแอป Nudge ผ่าน LINE ได้ที่นี่: ${liffBaseUrl}\nหรือพิมพ์บอกงาน เช่น 'พรุ่งนี้ 10 โมงมีสอบ' ได้ทันทีครับ`
          : `🌱 ยินดีต้อนรับสู่ Nudge!\n\nLINE User ID ของคุณคือ:\n${lineUserId}\n\nพิมพ์บอกงานในแชทนี้เพื่อให้ Nudge ช่วยเตือนได้เลยครับ!`;

        await this.replyMessage(replyToken, [{ type: "text", text: msg }]);
        repliesSent++;
      } else if (event.type === "message" && event.message?.type === "text") {
        const text = (event.message.text || "").trim();
        const lower = text.toLowerCase();
        const user = await this.userService.getOrCreateUserByLineUserId(lineUserId);

        // Fast path for immediate single-turn commands
        const isIdQuery =
          lower === "id" || lower === "uid" || lower === "userid" || lower === "ไอดี" || lower === "ขอไอดี";
        const isViewQuery =
          lower === "งาน" ||
          lower === "งานวันนี้" ||
          lower === "งานทั้งหมด" ||
          lower === "ดูงาน" ||
          lower === "ดูงานทั้งหมด" ||
          lower === "รายการงาน" ||
          lower === "งานค้าง" ||
          lower === "มีงานอะไรบ้าง" ||
          lower === "งานที่ต้องทำ" ||
          lower === "เช็คงาน" ||
          lower === "tasks" ||
          lower === "task" ||
          lower === "all tasks" ||
          lower === "list" ||
          lower === "todo" ||
          lower.startsWith("ดูงาน") ||
          lower.startsWith("ขอดูงาน") ||
          lower.startsWith("รายการ");
        const isRecQuery =
          lower === "แนะนำ" ||
          lower === "nudge" ||
          lower === "focus" ||
          lower === "เริ่ม" ||
          lower === "ทำอะไรดี" ||
          lower === "เริ่มงานไหนดี" ||
          lower.includes("แนะนำ");
        const isHelpQuery =
          lower === "help" ||
          lower === "ช่วยเหลือ" ||
          lower === "วิธีใช้" ||
          lower === "คำสั่ง" ||
          lower === "ทำอะไรได้บ้าง";

        if (isIdQuery) {
          await this.replyMessage(replyToken, [
            { type: "text", text: `🆔 LINE User ID ของคุณคือ:\n${lineUserId}` },
          ]);
          repliesSent++;
        } else if (isViewQuery) {
          const tasks = await this.taskService.getTasksForUser(user.id);
          const activeTasks = tasks.filter((t) => t.status !== "COMPLETED");
          const flex = this.createTaskListFlexMessage(activeTasks);
          await this.replyMessage(replyToken, [flex]);
          repliesSent++;
        } else if (isRecQuery) {
          const rec = await this.taskService.getRecommendedTask(user.id);
          if (rec) {
            const flex = this.createActionNudgeFlexMessage({
              ...rec.task,
              adaptiveNudgeMessage: rec.adaptiveNudgeMessage,
            });
            await this.replyMessage(replyToken, [flex]);
          } else {
            await this.replyMessage(replyToken, [
              {
                type: "text",
                text: "🎉 ยอดเยี่ยมมากครับ! ตอนนี้คุณไม่มีงานค้างเลย พักผ่อนให้สบายใจ หรือพิมพ์บอกงานใหม่ได้เสมอนะครับ",
              },
            ]);
          }
          repliesSent++;
        } else if (isHelpQuery) {
          await this.replyMessage(replyToken, [
            {
              type: "text",
              text:
                "🌱 Nudge Assistant พร้อมช่วยคุณเริ่มต้นงานสำคัญ:\n\n" +
                "• พิมพ์บอกงาน เช่น 'พรุ่งนี้ 9 โมงส่งมินิโปรเจกต์ สำคัญมาก'\n" +
                "• พิมพ์ 'งานทั้งหมด' เพื่อดูรายการงานทั้งหมด\n" +
                "• พิมพ์ 'แนะนำ' เพื่อดูงานที่ควรเริ่มทำ 10 นาทีแรก\n" +
                "• พิมพ์ 'id' เพื่อดู LINE User ID ของคุณ",
            },
          ]);
          repliesSent++;
        } else {
          // Natural language task creation or query:
          // Parse intent with Gemini 2.5 Flash first so the "saving" acknowledgement
          // is only shown when we are actually creating a task.
          const intentResult = await this.geminiService.parseTaskIntent(text);

          if (intentResult.intent === "CREATE_TASK") {
            // 1. Trigger loading indicator and send immediate acknowledgment via replyToken
            this.sendLoadingIndicator(lineUserId, 5).catch(() => {});
            await this.replyMessage(replyToken, [
              { type: "text", text: "กำลังบันทึกข้อมูลงานครับ... ⏳" },
            ]);
            repliesSent++;

            // 2. Save the task and push the created-task Flex Card
            const newTask = await this.taskService.createTask(user.id, {
              title: intentResult.title || text,
              deadline: intentResult.deadline || new Date(Date.now() + 86400000).toISOString(),
              importance: intentResult.importance || 3,
              estimatedMinutes: intentResult.estimatedMinutes || 30,
            });

            const flex = this.createTaskCreatedFlexMessage(newTask);
            await this.pushMessages(lineUserId, [flex]);
          } else if (intentResult.intent === "VIEW_TASKS") {
            const tasks = await this.taskService.getTasksForUser(user.id);
            const activeTasks = tasks.filter((t) => t.status !== "COMPLETED");
            const flex = this.createTaskListFlexMessage(activeTasks);
            await this.replyMessage(replyToken, [flex]);
            repliesSent++;
          } else if (intentResult.intent === "GET_RECOMMENDATION") {
            const rec = await this.taskService.getRecommendedTask(user.id);
            if (rec) {
              const flex = this.createActionNudgeFlexMessage({
                ...rec.task,
                adaptiveNudgeMessage: rec.adaptiveNudgeMessage,
              });
              await this.replyMessage(replyToken, [flex]);
            } else {
              await this.replyMessage(replyToken, [
                {
                  type: "text",
                  text: "🎉 ยอดเยี่ยมมากครับ! ตอนนี้คุณไม่มีงานค้างเลย พักผ่อนให้สบายใจ หรือพิมพ์บอกงานใหม่ได้เสมอนะครับ",
                },
              ]);
            }
            repliesSent++;
          } else {
            await this.replyMessage(replyToken, [
              {
                type: "text",
                text:
                  intentResult.replyMessage ||
                  `สวัสดีครับ! สามารถพิมพ์บอกงาน เช่น "พรุ่งนี้ส่งโปรเจกต์" หรือพิมพ์ "งานวันนี้" เพื่อดูงานได้เลยครับ 🌱`,
              },
            ]);
            repliesSent++;
          }
        }
      }
    }

    return { handledCount: events.length, repliesSent };
  }
}

export const lineService = new LineService();


