import { TaskService, taskService as defaultTaskService, type TaskWithDerived } from "./task.service";
import { UserService, userService as defaultUserService } from "./user.service";
import { GeminiService, geminiService as defaultGeminiService } from "./gemini.service";
import { verifyLineSignature } from "../lib/line-signature";
import type { User } from "../db/schema";

export interface LineQuickReply {
  items: Array<{ type: "action"; action: Record<string, any> }>;
}

export interface LineFlexMessage {
  type: "flex";
  altText: string;
  contents: Record<string, any>;
  quickReply?: LineQuickReply;
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
      nudgeReasonText?: string;
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
          ...(task.nudgeReasonText
            ? [
                {
                  type: "text",
                  text: task.nudgeReasonText,
                  color: "#64748B",
                  size: "xxs",
                  wrap: true,
                },
              ]
            : []),
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
      // Answerable without opening the app: start, postpone, or close the task
      quickReply: {
        items: [
          {
            type: "action",
            action: { type: "uri", label: "เริ่ม 10 นาที", uri: deepLinkUrl },
          },
          {
            type: "action",
            action: { type: "message", label: "เลื่อนไปก่อน", text: `เลื่อนงาน #${task.id}` },
          },
          {
            type: "action",
            action: { type: "message", label: "ทำเสร็จแล้ว", text: `ปิดงาน #${task.id}` },
          },
        ],
      },
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
  async sendActionNudge(
    userId: number,
    taskId: number,
    options?: { reasonText?: string }
  ): Promise<LinePushResult> {
    const task = await this.taskService.getTaskById(userId, taskId);
    if (!task) {
      throw new Error("Task not found");
    }

    const user = await this.userService.findById(userId);

    if (!user || !user.lineUserId) {
      throw new Error("User has not linked a LINE account");
    }

    const flexMessage = this.createActionNudgeFlexMessage({
      ...task,
      nudgeReasonText: options?.reasonText,
    });

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
   * Looks for an active task that already covers what the user is about to save,
   * so we can warn before creating a second copy of the same work.
   */
  async findDuplicateTask(userId: number, title: string): Promise<TaskWithDerived | null> {
    const normalized = this.geminiService.normalizeMessage(title);
    if (normalized.length < 2) {
      return null;
    }

    const activeTasks = (await this.taskService.getTasksForUser(userId)).filter(
      (task) => task.status !== "COMPLETED"
    );

    return (
      activeTasks.find((task) => {
        const existing = this.geminiService.normalizeMessage(task.title);
        if (existing === normalized) {
          return true;
        }

        // Near-duplicates only count when the shared part is meaningful
        const shorter = Math.min(existing.length, normalized.length);
        if (shorter < 3) {
          return false;
        }
        if (existing.includes(normalized) || normalized.includes(existing)) {
          return true;
        }

        // 0.65 catches typos and prefix variants ("ส่งมินิโปรเจกต์" vs "สมินโปรเจกต์")
        // while leaving genuinely different work alone ("ติวสอบฟิสิกส์" vs "ติวสอบคณิต" = 0.6).
        return this.longestCommonSubstringLength(existing, normalized) / shorter >= 0.65;
      }) ?? null
    );
  }

  /**
   * Longest run of characters two titles share, used to catch near-duplicates
   * such as "ส่งมินิโปรเจกต์" and "สมินิโปรเจกต์".
   */
  private longestCommonSubstringLength(a: string, b: string): number {
    let best = 0;
    let previous = new Array(b.length + 1).fill(0);

    for (let i = 1; i <= a.length; i++) {
      const current = new Array(b.length + 1).fill(0);
      for (let j = 1; j <= b.length; j++) {
        if (a[i - 1] === b[j - 1]) {
          current[j] = previous[j - 1] + 1;
          if (current[j] > best) {
            best = current[j];
          }
        }
      }
      previous = current;
    }

    return best;
  }

  /**
   * Resolves which existing task a chat command points at.
   * "unspecified" means the user did not name a task we can match on.
   */
  private resolveTaskTarget(
    tasks: TaskWithDerived[],
    taskQuery?: string
  ):
    | { kind: "one"; task: TaskWithDerived }
    | { kind: "many"; tasks: TaskWithDerived[] }
    | { kind: "none"; query: string }
    | { kind: "unspecified" } {
    const query = this.normalizeTaskQuery(taskQuery);
    if (!query) {
      return { kind: "unspecified" };
    }

    const matches = this.matchTasksByQuery(tasks, query);
    if (matches.length === 1) {
      return { kind: "one", task: matches[0] };
    }
    if (matches.length > 1) {
      return { kind: "many", tasks: matches };
    }

    return { kind: "none", query };
  }

  /**
   * Names that are too generic ("งาน", "อันนี้") would match every task, so they are
   * treated as "the user did not name a task".
   */
  private normalizeTaskQuery(taskQuery?: string): string {
    const query = this.geminiService.normalizeMessage(taskQuery ?? "");
    const generic = ["งาน", "ทำงาน", "งานนี้", "อันนี้", "นี้", "ที่", "มัน", "ทั้งหมด", "หมด"];

    return query.length < 3 || generic.includes(query) ? "" : query;
  }

  private matchTasksByQuery(tasks: TaskWithDerived[], query: string): TaskWithDerived[] {
    const withoutVerb = query.replace(/^(เพิ่ง|ทำ|ไป|จะ|ช่วย)/, "");
    const needles = withoutVerb.length >= 3 ? [query, withoutVerb] : [query];

    return tasks.filter((task) => {
      const title = this.geminiService.normalizeMessage(task.title);
      return needles.some((needle) => title.includes(needle) || needle.includes(title));
    });
  }

  /**
   * Lists tasks with their number and deadline, so several tasks sharing a name
   * (duplicates) can still be told apart and picked.
   */
  private formatTaskChoices(tasks: TaskWithDerived[]): string {
    return tasks
      .slice(0, 5)
      .map((task) => {
        const done = task.status === "COMPLETED" ? " (เสร็จแล้ว)" : "";
        const deadline = task.deadline ? ` · กำหนด ${this.formatDeadline(task.deadline)}` : "";
        return `• ${task.title}${done} — #${task.id}${deadline}`;
      })
      .join("\n");
  }

  private formatDeadline(deadline: Date): string {
    const date = new Date(deadline);
    const day = date.getDate();
    const month = date.getMonth() + 1;
    const hours = date.getHours().toString().padStart(2, "0");
    const minutes = date.getMinutes().toString().padStart(2, "0");
    return `${day}/${month} ${hours}:${minutes}`;
  }

  /**
   * Tappable choices for the first few candidates of an ambiguous command.
   */
  private buildTaskChoiceQuickReply(command: "ปิดงาน" | "ลบงาน" | "เลื่อนงาน", tasks: TaskWithDerived[]) {
    return {
      items: tasks.slice(0, 3).map((task) => ({
        type: "action",
        action: {
          type: "message",
          label: `#${task.id} ${task.title}`.slice(0, 20),
          text: `${command} #${task.id}`,
        },
      })),
    };
  }

  /**
   * Marks a task as done from a chat command such as "ทำการบ้านเสร็จแล้ว".
   * With no task name it closes the task the user is most likely working on.
   */
  async handleCompleteTaskCommand(
    replyToken: string,
    userId: number,
    taskQuery?: string,
    taskId?: number
  ): Promise<void> {
    const activeTasks = (await this.taskService.getTasksForUser(userId)).filter(
      (task) => task.status !== "COMPLETED"
    );

    if (activeTasks.length === 0) {
      await this.replyMessage(replyToken, [
        { type: "text", text: "🎉 ตอนนี้ยังไม่มีงานค้างในระบบเลยครับ พิมพ์บอกงานใหม่ได้เสมอนะครับ" },
      ]);
      return;
    }

    // The user picked a specific task by number ("ปิดงาน #12")
    if (taskId) {
      const chosen = activeTasks.find((task) => task.id === taskId);
      if (!chosen) {
        await this.replyMessage(replyToken, [
          {
            type: "text",
            text: `🔎 ไม่พบงานหมายเลข #${taskId} ในงานที่ยังไม่เสร็จครับ\n\nงานที่ยังไม่เสร็จของคุณ:\n${this.formatTaskChoices(
              activeTasks
            )}`,
          },
        ]);
        return;
      }
      await this.completeTask(replyToken, userId, chosen, activeTasks);
      return;
    }

    const target = this.resolveTaskTarget(activeTasks, taskQuery);

    if (target.kind === "none") {
      await this.replyMessage(replyToken, [
        {
          type: "text",
          text: `🔎 ไม่พบงานที่ชื่อใกล้เคียงกับ "${target.query}" ครับ\n\nงานที่ยังไม่เสร็จของคุณ:\n${this.formatTaskChoices(
            activeTasks
          )}`,
        },
      ]);
      return;
    }

    if (target.kind === "many") {
      await this.replyMessage(replyToken, [
        {
          type: "text",
          text: `🔎 เจอหลายงานที่ชื่อใกล้กันครับ เลือกงานที่ต้องการได้เลย:\n${this.formatTaskChoices(
            target.tasks
          )}\n\nพิมพ์ "ปิดงาน #<หมายเลข>" หรือกดปุ่มด้านล่างครับ`,
          quickReply: this.buildTaskChoiceQuickReply("ปิดงาน", target.tasks),
        },
      ]);
      return;
    }

    let task: TaskWithDerived;
    if (target.kind === "one") {
      task = target.task;
    } else {
      // No task named: close the one Nudge is recommending right now
      const recommended = await this.taskService.getRecommendedTask(userId);
      if (!recommended) {
        await this.replyMessage(replyToken, [
          { type: "text", text: "🎉 ตอนนี้ยังไม่มีงานค้างในระบบเลยครับ" },
        ]);
        return;
      }
      task = await this.taskService.getTaskById(userId, recommended.task.id);
    }

    await this.completeTask(replyToken, userId, task, activeTasks);
  }

  private async completeTask(
    replyToken: string,
    userId: number,
    task: TaskWithDerived,
    activeTasks: TaskWithDerived[]
  ): Promise<void> {
    await this.taskService.updateTaskStatus(userId, task.id, "COMPLETED");

    const remainingCount = activeTasks.filter((t) => t.id !== task.id).length;
    const next = await this.taskService.getRecommendedTask(userId);
    const nextLine = next
      ? `\n\nงานถัดไปที่ควรเริ่ม: ${next.task.title}`
      : "\n\nตอนนี้ไม่มีงานค้างแล้วครับ 🎉";

    await this.replyMessage(replyToken, [
      {
        type: "text",
        text: `🎉 เยี่ยมมากครับ! ปิดงาน "${task.title}" เรียบร้อยแล้ว\nเหลืองานที่ยังไม่เสร็จ ${remainingCount} รายการ${nextLine}`,
      },
    ]);
  }

  /**
   * Records an explicit postpone ("เลื่อนไปก่อน") from chat. This is the deliberate
   * choice the avoidance detection counts, so it is logged as a normal postpone.
   */
  async handlePostponeTaskCommand(
    replyToken: string,
    userId: number,
    taskQuery?: string,
    taskId?: number
  ): Promise<void> {
    const activeTasks = (await this.taskService.getTasksForUser(userId)).filter(
      (task) => task.status !== "COMPLETED"
    );

    if (activeTasks.length === 0) {
      await this.replyMessage(replyToken, [
        { type: "text", text: "🎉 ตอนนี้ยังไม่มีงานค้างในระบบเลยครับ" },
      ]);
      return;
    }

    let task: TaskWithDerived;

    if (taskId) {
      const chosen = activeTasks.find((candidate) => candidate.id === taskId);
      if (!chosen) {
        await this.replyMessage(replyToken, [
          {
            type: "text",
            text: `🔎 ไม่พบงานหมายเลข #${taskId} ในงานที่ยังไม่เสร็จครับ\n\nงานของคุณ:\n${this.formatTaskChoices(
              activeTasks
            )}`,
          },
        ]);
        return;
      }
      task = chosen;
    } else {
      const target = this.resolveTaskTarget(activeTasks, taskQuery);

      if (target.kind === "none") {
        await this.replyMessage(replyToken, [
          {
            type: "text",
            text: `🔎 ไม่พบงานที่ชื่อใกล้เคียงกับ "${target.query}" ครับ\n\nงานของคุณ:\n${this.formatTaskChoices(
              activeTasks
            )}`,
          },
        ]);
        return;
      }

      if (target.kind === "many") {
        await this.replyMessage(replyToken, [
          {
            type: "text",
            text: `🔎 เจอหลายงานที่ชื่อใกล้กันครับ จะเลื่อนงานไหน?\n${this.formatTaskChoices(
              target.tasks
            )}\n\nพิมพ์ "เลื่อนงาน #<หมายเลข>" หรือกดปุ่มด้านล่างครับ`,
            quickReply: this.buildTaskChoiceQuickReply("เลื่อนงาน", target.tasks),
          },
        ]);
        return;
      }

      if (target.kind === "one") {
        task = target.task;
      } else {
        // No task named: the one Nudge would recommend right now
        const recommended = await this.taskService.getRecommendedTask(userId);
        if (!recommended) {
          await this.replyMessage(replyToken, [
            { type: "text", text: "🎉 ตอนนี้ยังไม่มีงานค้างในระบบเลยครับ" },
          ]);
          return;
        }
        task = await this.taskService.getTaskById(userId, recommended.task.id);
      }
    }

    const postponed = await this.taskService.postponeTask(userId, task.id);

    await this.replyMessage(replyToken, [
      {
        type: "text",
        text: `⏳ เลื่อนงาน "${postponed.title}" ไปก่อนแล้วครับ\n${postponed.adaptiveNudgeMessage}`,
      },
    ]);
  }

  /**
   * Deletes a task from chat. Deleting is destructive, so a named task asks for
   * confirmation (quick reply) before anything is removed.
   */
  async handleDeleteTaskCommand(
    replyToken: string,
    userId: number,
    taskQuery?: string,
    taskId?: number,
    confirmed = false
  ): Promise<void> {
    // Only an explicit confirmation actually removes anything
    if (taskId && confirmed) {
      try {
        const task = await this.taskService.getTaskById(userId, taskId);
        await this.taskService.softDeleteTask(userId, taskId);
        await this.replyMessage(replyToken, [
          {
            type: "text",
            text: `🗑️ ลบงาน "${task.title}" แล้วครับ\nถ้าลบผิดตัว พิมพ์บอกงานเดิมอีกครั้งเพื่อบันทึกใหม่ได้เลยครับ`,
          },
        ]);
      } catch {
        await this.replyMessage(replyToken, [
          { type: "text", text: "🔎 ไม่พบงานนี้แล้วครับ อาจถูกลบไปก่อนหน้านี้" },
        ]);
      }
      return;
    }

    const tasks = await this.taskService.getTasksForUser(userId);
    if (tasks.length === 0) {
      await this.replyMessage(replyToken, [
        { type: "text", text: "✨ ไม่มีงานให้ลบตอนนี้ครับ พิมพ์บอกงานใหม่ได้เสมอนะครับ" },
      ]);
      return;
    }

    // Picked by number ("ลบงาน #12") — resolve it, then confirm like any other pick
    if (taskId) {
      const chosen = tasks.find((task) => task.id === taskId);
      if (!chosen) {
        await this.replyMessage(replyToken, [
          {
            type: "text",
            text: `🔎 ไม่พบงานหมายเลข #${taskId} ครับ\n\nงานของคุณ:\n${this.formatTaskChoices(tasks)}`,
          },
        ]);
        return;
      }
      await this.confirmDeleteTask(replyToken, chosen);
      return;
    }

    const target = this.resolveTaskTarget(tasks, taskQuery);

    if (target.kind === "none") {
      await this.replyMessage(replyToken, [
        {
          type: "text",
          text: `🔎 ไม่พบงานที่ชื่อใกล้เคียงกับ "${target.query}" ครับ\n\nงานของคุณ:\n${this.formatTaskChoices(
            tasks
          )}`,
        },
      ]);
      return;
    }

    if (target.kind === "many") {
      await this.replyMessage(replyToken, [
        {
          type: "text",
          text: `🔎 เจอหลายงานที่ชื่อใกล้กันครับ เลือกงานที่ต้องการได้เลย:\n${this.formatTaskChoices(
            target.tasks
          )}\n\nพิมพ์ "ลบงาน #<หมายเลข>" หรือกดปุ่มด้านล่างครับ`,
          quickReply: this.buildTaskChoiceQuickReply("ลบงาน", target.tasks),
        },
      ]);
      return;
    }

    if (target.kind === "unspecified") {
      await this.replyMessage(replyToken, [
        {
          type: "text",
          text: `🗑️ จะลบงานไหนครับ? พิมพ์ชื่อหรือหมายเลขงานได้เลย เช่น "ลบงานอ่านหนังสือ" หรือ "ลบงาน #12"\n\nงานของคุณ:\n${this.formatTaskChoices(
            tasks
          )}`,
        },
      ]);
      return;
    }

    await this.confirmDeleteTask(replyToken, target.task);
  }

  private async confirmDeleteTask(replyToken: string, task: TaskWithDerived): Promise<void> {
    await this.replyMessage(replyToken, [
      {
        type: "text",
        text: `🗑️ ต้องการลบงาน "${task.title}" (#${task.id} · กำหนด ${this.formatDeadline(
          task.deadline
        )}) ใช่ไหมครับ?\nถ้าใช่ กดปุ่มด้านล่างหรือพิมพ์ "ยืนยันลบ #${task.id}" ได้เลยครับ`,
        quickReply: {
          items: [
            {
              type: "action",
              action: { type: "message", label: "ยืนยันลบ", text: `ยืนยันลบ #${task.id}` },
            },
            {
              type: "action",
              action: { type: "message", label: "ยกเลิก", text: "ยกเลิก" },
            },
          ],
        },
      },
    ]);
  }

  /**
   * Downloads binary audio content from LINE Messaging API.
   */
  async downloadAudioContent(messageId: string): Promise<Buffer> {
    const url = `https://api-data.line.me/v2/bot/message/${messageId}/content`;
    const response = await fetch(url, {
      headers: {
        Authorization: `Bearer ${this.channelAccessToken}`,
      },
    });

    if (!response.ok) {
      throw new Error(`Failed to download LINE audio: ${response.status} ${await response.text()}`);
    }

    const arrayBuffer = await response.arrayBuffer();
    return Buffer.from(arrayBuffer);
  }

  createVoiceConfirmationFlexMessage(result: {
    transcription?: string;
    title?: string;
    deadline?: string;
    importance?: number;
    estimatedMinutes?: number;
  }): LineFlexMessage {
    const transcription = result.transcription || "ข้อความเสียง";
    const title = result.title || "งานใหม่";
    const deadlineText = result.deadline ? this.formatDeadline(new Date(result.deadline)) : "วันนี้ 23:59";
    const importance = result.importance ?? 3;
    const estimatedMinutes = result.estimatedMinutes ?? 30;

    return {
      type: "flex",
      altText: `🎙️ บันทึกงานจากเสียง: ${title}`,
      contents: {
        type: "bubble",
        header: {
          type: "box",
          layout: "vertical",
          backgroundColor: "#4F46E5",
          paddingAll: "16px",
          contents: [
            {
              type: "text",
              text: "🎙️ สรุปงานจากข้อความเสียง",
              color: "#FFFFFF",
              weight: "bold",
              size: "sm",
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
              layout: "vertical",
              backgroundColor: "#F8FAFC",
              cornerRadius: "8px",
              paddingAll: "10px",
              contents: [
                {
                  type: "text",
                  text: `ได้ยินว่า: "${transcription}"`,
                  color: "#475569",
                  size: "xs",
                  wrap: true,
                },
              ],
            },
            {
              type: "text",
              text: title,
              color: "#1E293B",
              weight: "bold",
              size: "md",
              wrap: true,
            },
            {
              type: "box",
              layout: "vertical",
              spacing: "sm",
              contents: [
                {
                  type: "box",
                  layout: "horizontal",
                  contents: [
                    { type: "text", text: "กำหนดส่ง:", color: "#64748B", size: "xs", flex: 2 },
                    { type: "text", text: deadlineText, color: "#1E293B", size: "xs", flex: 3, align: "end" },
                  ],
                },
                {
                  type: "box",
                  layout: "horizontal",
                  contents: [
                    { type: "text", text: "ความสำคัญ:", color: "#64748B", size: "xs", flex: 2 },
                    { type: "text", text: `${importance}/5`, color: "#1E293B", size: "xs", flex: 3, align: "end" },
                  ],
                },
                {
                  type: "box",
                  layout: "horizontal",
                  contents: [
                    { type: "text", text: "เวลาโดยประมาณ:", color: "#64748B", size: "xs", flex: 2 },
                    { type: "text", text: `${estimatedMinutes} นาที`, color: "#1E293B", size: "xs", flex: 3, align: "end" },
                  ],
                },
              ],
            },
          ],
        },
        footer: {
          type: "box",
          layout: "horizontal",
          spacing: "sm",
          paddingAll: "16px",
          contents: [
            {
              type: "button",
              style: "secondary",
              height: "sm",
              action: {
                type: "message",
                label: "ยกเลิก",
                text: "ยกเลิก",
              },
            },
            {
              type: "button",
              style: "primary",
              color: "#4F46E5",
              height: "sm",
              action: {
                type: "message",
                label: "ยืนยันบันทึกงาน",
                text: `ยืนยันบันทึกงาน ${title}`,
              },
            },
          ],
        },
      },
      quickReply: {
        items: [
          {
            type: "action",
            action: {
              type: "message",
              label: "✅ ยืนยันบันทึกงาน",
              text: `ยืนยันบันทึกงาน ${title}`,
            },
          },
          {
            type: "action",
            action: {
              type: "message",
              label: "❌ ยกเลิก",
              text: "ยกเลิก",
            },
          },
        ],
      },
    };
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
        // Log the raw text so misrouted commands (e.g. a "list tasks" phrase that
        // was stored as a new task) can be diagnosed from the server logs.
        console.log(`[LINE] message from ${lineUserId}: ${JSON.stringify(text)}`);
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
                "• พิมพ์ 'ทำการบ้านเสร็จแล้ว' เพื่อปิดงานที่ทำเสร็จ\n" +
                "• พิมพ์ 'ลบงานอ่านหนังสือ' เพื่อลบงานที่ไม่ต้องการแล้ว\n" +
                "• พิมพ์ 'id' เพื่อดู LINE User ID ของคุณ",
            },
          ]);
          repliesSent++;
        } else {
          // Natural language task creation or query:
          // Parse intent with Gemini 2.5 Flash first so the "saving" acknowledgement
          // is only shown when we are actually creating a task.
          const intentResult = await this.geminiService.parseTaskIntent(text);
          console.log(`[LINE] resolved intent: ${intentResult.intent}`);

          if (intentResult.intent === "CREATE_TASK") {
            const title = intentResult.title || text;

            // Warn instead of silently saving a second copy of the same work
            const duplicate = intentResult.confirmed ? null : await this.findDuplicateTask(user.id, title);
            if (duplicate) {
              await this.replyMessage(replyToken, [
                {
                  type: "text",
                  text:
                    `⚠️ มีงานชื่อ "${duplicate.title}" อยู่แล้วครับ (#${duplicate.id} · กำหนด ${this.formatDeadline(
                      duplicate.deadline
                    )})\n` +
                    `ถ้าเป็นงานเดียวกัน พิมพ์ "งานทั้งหมด" เพื่อดูรายการเดิมได้ครับ\n` +
                    `แต่ถ้าต้องการบันทึกเป็นงานใหม่จริง ๆ กดปุ่มด้านล่างได้เลย`,
                  quickReply: {
                    items: [
                      {
                        type: "action",
                        action: { type: "message", label: "บันทึกซ้ำ", text: `ยืนยันบันทึกงาน ${text}` },
                      },
                      {
                        type: "action",
                        action: { type: "message", label: "ยกเลิก", text: "ยกเลิก" },
                      },
                    ],
                  },
                },
              ]);
              repliesSent++;
            } else {
              // 1. Trigger loading indicator and send immediate acknowledgment via replyToken
              this.sendLoadingIndicator(lineUserId, 5).catch(() => {});
              await this.replyMessage(replyToken, [
                { type: "text", text: "กำลังบันทึกข้อมูลงานครับ... ⏳" },
              ]);
              repliesSent++;

              // 2. Save the task and push the created-task Flex Card
              const newTask = await this.taskService.createTask(user.id, {
                title,
                deadline: intentResult.deadline || new Date(Date.now() + 86400000).toISOString(),
                importance: intentResult.importance || 3,
                estimatedMinutes: intentResult.estimatedMinutes || 30,
              });

              const flex = this.createTaskCreatedFlexMessage(newTask);
              await this.pushMessages(lineUserId, [flex]);
            }
          } else if (intentResult.intent === "GET_ID") {
            await this.replyMessage(replyToken, [
              { type: "text", text: `🆔 LINE User ID ของคุณคือ:\n${lineUserId}` },
            ]);
            repliesSent++;
          } else if (intentResult.intent === "VIEW_TASKS") {
            const tasks = await this.taskService.getTasksForUser(user.id);
            const activeTasks = tasks.filter((t) => t.status !== "COMPLETED");
            const flex = this.createTaskListFlexMessage(activeTasks);
            await this.replyMessage(replyToken, [flex]);
            repliesSent++;
          } else if (intentResult.intent === "COMPLETE_TASK") {
            await this.handleCompleteTaskCommand(replyToken, user.id, intentResult.taskQuery, intentResult.taskId);
            repliesSent++;
          } else if (intentResult.intent === "POSTPONE_TASK") {
            await this.handlePostponeTaskCommand(replyToken, user.id, intentResult.taskQuery, intentResult.taskId);
            repliesSent++;
          } else if (intentResult.intent === "DELETE_TASK") {
            await this.handleDeleteTaskCommand(
              replyToken,
              user.id,
              intentResult.taskQuery,
              intentResult.taskId,
              intentResult.confirmed
            );
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
      } else if (event.type === "message" && event.message?.type === "audio") {
        const messageId = event.message.id;
        const user = await this.userService.getOrCreateUserByLineUserId(lineUserId);

        try {
          const audioBuffer = await this.downloadAudioContent(messageId);
          const parsed = await this.geminiService.parseTaskFromAudio(audioBuffer, "audio/m4a");

          if (parsed.intent === "CREATE_TASK" && parsed.title) {
            const flex = this.createVoiceConfirmationFlexMessage(parsed);
            await this.replyMessage(replyToken, [flex]);
            repliesSent++;
          } else if (parsed.intent === "VIEW_TASKS") {
            const tasks = await this.taskService.getTasksForUser(user.id);
            const activeTasks = tasks.filter((t) => t.status !== "COMPLETED");
            const flex = this.createTaskListFlexMessage(activeTasks);
            await this.replyMessage(replyToken, [flex]);
            repliesSent++;
          } else if (parsed.intent === "GET_RECOMMENDATION") {
            const recommendation = await this.taskService.getRecommendedTask(user.id);
            if (!recommendation) {
              await this.replyMessage(replyToken, [
                {
                  type: "text",
                  text: "🎉 ยอดเยี่ยมมากครับ! ตอนนี้คุณไม่มีงานค้างเลย พักผ่อนให้สบายใจได้ครับ 🌱",
                },
              ]);
            } else {
              const flex = this.createActionNudgeFlexMessage({
                ...recommendation.task,
                adaptiveNudgeMessage: recommendation.adaptiveNudgeMessage,
              });
              await this.replyMessage(replyToken, [flex]);
            }
            repliesSent++;
          } else {
            await this.replyMessage(replyToken, [
              {
                type: "text",
                text:
                  parsed.replyMessage ||
                  (parsed.transcription
                    ? `🎙️ ได้ยินว่า: "${parsed.transcription}"\n\nสามารถบอกให้บันทึกงาน ดูงาน หรือช่วยเริ่มงานได้นะครับ 🌱`
                    : "ฟังเสียงไม่ค่อยชัดเจนเลยครับ รบกวนลองส่งใหม่อีกครั้งนะครับ"),
              },
            ]);
            repliesSent++;
          }
        } catch (error) {
          console.error("Error processing LINE audio message:", error);
          await this.replyMessage(replyToken, [
            {
              type: "text",
              text: "ขออภัยครับ ไม่สามารถประมวลผลไฟล์เสียงได้ในขณะนี้ กรุณาลองใหม่อีกครั้งนะครับ",
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


