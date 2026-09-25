import { describe, expect, it } from "bun:test";
import { GeminiService } from "../src/services/gemini.service";
import { LineService } from "../src/services/line.service";
import { UserService } from "../src/services/user.service";
import {
  TaskService,
  type CreateTaskInput,
  type TaskStatus,
  type TaskWithDerived,
} from "../src/services/task.service";
import type { RecommendationResult } from "../src/lib/priority";
import type { User } from "../src/db/schema";

// No API key => deterministic fast regex parser (no network calls in tests)
const service = new GeminiService("");
const now = new Date("2026-09-22T14:57:00+07:00");

describe("Thai task parsing (fast path)", () => {
  it("lets an explicit star rating win over urgency adjectives", async () => {
    // "สำคัญมาก" alone would mean 5, but the user typed "3 ดาว"
    const result = await service.parseTaskIntent("พรุ่งนี้ 9 โมงมีมินิโปรเจกต์สำคัญมาก 3 ดาว", now);
    expect(result.intent).toBe("CREATE_TASK");
    expect(result.importance).toBe(3);
  });

  it("reads importance from plain star ratings", () => {
    expect(service.fastParseThaiTask("พรุ่งนี้ส่งการบ้าน 1 ดาว", now)?.importance).toBe(1);
    expect(service.fastParseThaiTask("พรุ่งนี้ส่งการบ้าน 2/5", now)?.importance).toBe(2);
    expect(service.fastParseThaiTask("พรุ่งนี้ส่งการบ้านด่วนมาก", now)?.importance).toBe(5);
    expect(service.fastParseThaiTask("พรุ่งนี้ส่งงานสำคัญ", now)?.importance).toBe(4);
  });

  it("treats 'ไม่สำคัญ' as low importance instead of matching 'สำคัญ'", () => {
    expect(service.fastParseThaiTask("พรุ่งนี้ส่งการบ้านไม่สำคัญ", now)?.importance).toBe(1);
  });

  it("recognises task messages with common spellings, typos and seminar/meeting words", () => {
    for (const text of [
      "พรุ่งนี้ 9 โมงมีสมินโปรเจคสำคัญมาก 3 ดาว", // โปรเจค without the final ต์
      "พรุ่งนี้ 9 โมงมีสัมมนาโปรเจกต์",
      "มีตติ้งกับลูกค้า 9 โมงเย็น",
      "นัดหมอ 5 โมงเย็น 45 นาที",
    ]) {
      expect(service.fastParseThaiTask(text, now)?.intent).toBe("CREATE_TASK");
    }
  });

  it("keeps the user's own words instead of inventing a title", () => {
    const result = service.fastParseThaiTask("พรุ่งนี้ 9 โมงมีมินิโปรเจกต์สำคัญมาก 3 ดาว", now);
    expect(result?.title).toBe("มินิโปรเจกต์");

    // Only add the "ส่ง" prefix when the user actually said "ส่ง"
    expect(service.fastParseThaiTask("พรุ่งนี้ 9 โมงส่งมินิโปรเจกต์", now)?.title).toBe("ส่งมินิโปรเจกต์");
    expect(service.fastParseThaiTask("พรุ่งนี้ต้องส่งการบ้าน", now)?.title).toBe("ส่งการบ้าน");
  });

  it("computes the deadline from the date and time words the user typed", () => {
    const tomorrow9 = service.fastParseThaiTask("พรุ่งนี้ 9 โมงส่งรายงาน", now);
    const deadline = new Date(tomorrow9!.deadline!);
    expect(deadline.getDate()).toBe(now.getDate() + 1);
    expect(deadline.getHours()).toBe(9);
    expect(deadline.getMinutes()).toBe(0);

    // "9 โมงเย็น" is 21:00, not 09:00
    expect(new Date(service.fastParseThaiTask("มีตติ้งกับลูกค้า 9 โมงเย็น", now)!.deadline!).getHours()).toBe(21);
    expect(new Date(service.fastParseThaiTask("นัดหมอ 5 โมงเย็น", now)!.deadline!).getHours()).toBe(17);
  });

  it("reads estimated duration and defaults to 30 minutes", () => {
    expect(service.fastParseThaiTask("พรุ่งนี้ 9 โมงนัดหมอ 45 นาที", now)?.estimatedMinutes).toBe(45);
    expect(service.fastParseThaiTask("อ่านหนังสือสอบ 3 ชั่วโมง", now)?.estimatedMinutes).toBe(180);
    expect(service.fastParseThaiTask("พรุ่งนี้ส่งการบ้าน", now)?.estimatedMinutes).toBe(30);
  });

  it("does not invent a task when the message contains no task keywords", async () => {
    const result = await service.parseTaskIntent("สวัสดี Nudge AI", now);
    expect(result.intent).toBe("UNKNOWN");
    expect(result.replyMessage).toBeDefined();
  });
});

describe("Intent routing for chat commands", () => {
  it("routes every 'show my tasks' phrasing to VIEW_TASKS", async () => {
    const commands = [
      "งานทั้งหมด",
      "งานทั้งหมดค่ะ", // polite particle
      "งาน ทั้งหมด", // stray space
      "งานทังหมด", // missing tone mark
      "งานทั้งมด", // missing ห
      "\u200Bงานทั้งหมด", // zero-width space
      "ดูงานทั้งหมดครับ",
      "ขอดูงานทั้งหมด",
      "งานทั้งหมดมีอะไรบ้าง",
      "มีงานอะไรบ้าง",
      "งานค้าง",
      "งานวันนี้",
      "รายการงาน",
      "งานของฉัน",
      "all tasks",
      "todo",
    ];

    for (const text of commands) {
      const result = await service.parseTaskIntent(text, now);
      expect({ text, intent: result.intent }).toEqual({ text, intent: "VIEW_TASKS" });
    }
  });

  it("keeps routing the other commands", async () => {
    expect((await service.parseTaskIntent("แนะนำ", now)).intent).toBe("GET_RECOMMENDATION");
    expect((await service.parseTaskIntent("เริ่มงานไหนดี", now)).intent).toBe("GET_RECOMMENDATION");
    expect((await service.parseTaskIntent("ช่วยเหลือ", now)).intent).toBe("HELP");
    expect((await service.parseTaskIntent("id", now)).intent).toBe("GET_ID");
    expect((await service.parseTaskIntent("ไลน์ไอดี", now)).intent).toBe("GET_ID");
  });

  it("does not mistake a task message for a list command", async () => {
    const result = await service.parseTaskIntent("พรุ่งนี้ส่งงานทั้งหมด 3 ชิ้น", now);
    expect(result.intent).toBe("CREATE_TASK");
    expect(result.title).toContain("งานทั้งหมด");
  });
});

describe("Lifecycle commands: complete & delete", () => {
  it("parses a completion command with the name the user used", async () => {
    const result = await service.parseTaskIntent("ทำการบ้านเสร็จแล้ว", now);
    expect(result.intent).toBe("COMPLETE_TASK");
    expect(result.taskQuery).toBe("ทำการบ้าน");
  });

  it("parses delete commands and their confirmation", async () => {
    expect(await service.parseTaskIntent("ลบงานอ่านหนังสือ", now)).toMatchObject({
      intent: "DELETE_TASK",
      taskQuery: "อ่านหนังสือ",
    });
    expect(await service.parseTaskIntent("ยืนยันลบ #12", now)).toMatchObject({
      intent: "DELETE_TASK",
      taskId: 12,
    });
    expect((await service.parseTaskIntent("ยกเลิก", now)).intent).toBe("UNKNOWN");
  });

  it("understands a task picked by number", async () => {
    expect(await service.parseTaskIntent("ลบงาน #12", now)).toMatchObject({
      intent: "DELETE_TASK",
      taskId: 12,
    });
    expect(await service.parseTaskIntent("ปิดงาน #7", now)).toMatchObject({
      intent: "COMPLETE_TASK",
      taskId: 7,
    });
  });

  it("never turns a question or a future task into a command", async () => {
    expect((await service.parseTaskIntent("ทำงานเสร็จหรือยัง", now)).intent).not.toBe("COMPLETE_TASK");
    expect((await service.parseTaskIntent("พรุ่งนี้ 9 โมงส่งรายงาน", now)).intent).toBe("CREATE_TASK");
    expect((await service.parseTaskIntent("พรุ่งนี้ลบไฟล์งานเก่า", now)).intent).toBe("CREATE_TASK");
  });
});

describe("Explicit postpone command", () => {
  it("parses 'เลื่อนไปก่อน' with and without a task name", async () => {
    expect(await service.parseTaskIntent("เลื่อนไปก่อน", now)).toMatchObject({ intent: "POSTPONE_TASK" });
    expect(await service.parseTaskIntent("เลื่อนงานอ่านหนังสือ", now)).toMatchObject({
      intent: "POSTPONE_TASK",
      taskQuery: "อ่านหนังสือ",
    });
    expect(await service.parseTaskIntent("เลื่อนงาน #12", now)).toMatchObject({
      intent: "POSTPONE_TASK",
      taskId: 12,
    });
  });

  it("does not postpone on a question", async () => {
    expect((await service.parseTaskIntent("เลื่อนได้ไหม", now)).intent).not.toBe("POSTPONE_TASK");
  });
});

describe("Duplicate save confirmation (parser)", () => {
  it("recognizes the 'save it anyway' confirmation and strips it", async () => {
    const result = await service.parseTaskIntent("ยืนยันบันทึกงาน พรุ่งนี้ 9 โมงส่งรายงาน 3 ดาว", now);
    expect(result.intent).toBe("CREATE_TASK");
    expect(result.confirmed).toBe(true);
    expect(result.title).toBe("ส่งรายงาน");
    expect(result.importance).toBe(3);
  });

  it("leaves ordinary messages unconfirmed", async () => {
    const result = await service.parseTaskIntent("พรุ่งนี้ 9 โมงส่งรายงาน", now);
    expect(result.intent).toBe("CREATE_TASK");
    expect(result.confirmed).toBeUndefined();
  });
});

describe("Spam guard: messages with no intent to create a task", () => {
  const chatty = [
    "งานเยอะจัง",
    "งานเยอะมากเลย",
    "ทำงานเหนื่อยมาก",
    "เหนื่อยจัง ไม่อยากทำการบ้าน",
    "ขอบคุณสำหรับงานดีๆ",
    "งานดีมากเลย",
    "ทำงานเสร็จแล้ว",
    "เพิ่งส่งงานไปแล้ว",
    "พรุ่งนี้สอบกี่โมง",
    "ต้องส่งอะไรบ้าง",
    "ทำไมงานเยอะจัง",
    "5555",
    "อยากพักผ่อน",
  ];

  it("never stores chat, questions, complaints or done-reports as tasks", async () => {
    for (const text of chatty) {
      expect({ text, intent: service.fastParseThaiTask(text, now) }).toEqual({ text, intent: null });
      expect({ text, intent: (await service.parseTaskIntent(text, now)).intent }).not.toEqual({
        text,
        intent: "CREATE_TASK",
      });
    }
  });

  it("asks for a clearer description when a task is mentioned but too vague", async () => {
    const result = await service.parseTaskIntent("งานเยอะจัง", now);
    expect(result.intent).toBe("UNKNOWN");
    expect(result.replyMessage).toContain("วัน/เวลา");
  });

  it("still keeps the task when a complaint wraps a real one", async () => {
    const result = await service.parseTaskIntent("เหนื่อยจัง แต่พรุ่งนี้ต้องส่งงาน", now);
    expect(result.intent).toBe("CREATE_TASK");
    expect(result.title).toBe("ส่งงาน");
  });

  it("still saves tasks that have an action but no date", async () => {
    expect((await service.parseTaskIntent("ส่งการบ้านไม่สำคัญ", now)).intent).toBe("CREATE_TASK");
    expect((await service.parseTaskIntent("ช่วยเตือนอ่านหนังสือสอบ", now)).intent).toBe("CREATE_TASK");
    expect((await service.parseTaskIntent("ติวสอบคณิต", now)).intent).toBe("CREATE_TASK");
  });

  it("vetoes an over-eager CREATE_TASK coming back from Gemini", () => {
    expect(service.isClearlyNotTaskRequest("งานเยอะจัง")).toBe(true);
    expect(service.isClearlyNotTaskRequest("พรุ่งนี้สอบกี่โมง")).toBe(true);
    expect(service.isClearlyNotTaskRequest("เหนื่อยจัง แต่พรุ่งนี้ต้องส่งงาน")).toBe(false);
    expect(service.isClearlyNotTaskRequest("พรุ่งนี้ 9 โมงส่งรายงาน")).toBe(false);
  });
});

class StubUserService extends UserService {
  override async getOrCreateUserByLineUserId(lineUserId: string): Promise<User> {
    return {
      id: 1,
      deviceUuid: "device-1",
      lineUserId,
      timezone: "Asia/Bangkok",
      lastNudgeAt: null,
      createdAt: new Date(),
    };
  }
}

const makeTask = (
  id: number,
  title: string,
  status: TaskStatus = "NOT_STARTED",
  overrides: Partial<TaskWithDerived> = {}
): TaskWithDerived => ({
  id,
  userId: 1,
  title,
  deadline: new Date("2026-09-23T02:00:00.000Z"),
  importance: 3,
  estimatedMinutes: 30,
  status,
  postponeCount: 0,
  lastNudgedAt: null,
  nudgeCount: 0,
  createdAt: new Date("2026-09-22T08:00:00.000Z"),
  deletedAt: null,
  daysRemaining: 1,
  avoidanceScore: 0,
  isPotentiallyAvoided: false,
  adaptiveNudgeMessage: "ลองเริ่ม 10 นาทีไหม?",
  ...overrides,
});

class StubTaskService extends TaskService {
  public createdInputs: CreateTaskInput[] = [];
  public tasks: TaskWithDerived[] = [];
  public completedIds: number[] = [];
  public postponedIds: number[] = [];
  public deletedIds: number[] = [];

  override async createTask(_userId: number, input: CreateTaskInput): Promise<TaskWithDerived> {
    this.createdInputs.push(input);
    return makeTask(99, input.title);
  }

  override async getTasksForUser(_userId: number): Promise<TaskWithDerived[]> {
    return this.tasks;
  }

  override async getTaskById(_userId: number, taskId: number): Promise<TaskWithDerived> {
    const found = this.tasks.find((task) => task.id === taskId);
    if (!found) {
      throw new Error("Task not found");
    }
    return found;
  }

  override async updateTaskStatus(
    _userId: number,
    taskId: number,
    status: TaskStatus
  ): Promise<TaskWithDerived> {
    const task = this.tasks.find((t) => t.id === taskId);
    if (!task) {
      throw new Error("Task not found");
    }
    task.status = status;
    if (status === "COMPLETED") {
      this.completedIds.push(taskId);
    }
    return task;
  }

  override async postponeTask(_userId: number, taskId: number): Promise<TaskWithDerived> {
    const task = this.tasks.find((t) => t.id === taskId);
    if (!task) {
      throw new Error("Task not found");
    }
    task.postponeCount += 1;
    task.nudgeCount = 0;
    this.postponedIds.push(taskId);
    return task;
  }

  override async softDeleteTask(_userId: number, taskId: number): Promise<void> {
    if (!this.tasks.some((task) => task.id === taskId)) {
      throw new Error("Task not found");
    }
    this.deletedIds.push(taskId);
    this.tasks = this.tasks.filter((task) => task.id !== taskId);
  }

  override async getRecommendedTask(_userId: number): Promise<RecommendationResult | null> {
    const active = this.tasks.filter((task) => task.status !== "COMPLETED");
    if (active.length === 0) {
      return null;
    }
    return {
      task: active[0],
      suggestedAction: "START_10_MINUTES",
      recommendationReason: "งานสำคัญที่สุดที่ควรทำในตอนนี้",
      adaptiveNudgeMessage: "ลองเริ่ม 10 นาทีไหม?",
    } as unknown as RecommendationResult;
  }
}

describe("LINE webhook routing (real parser, no Gemini API key)", () => {
  const buildService = () => {
    const users = new StubUserService();
    const tasks = new StubTaskService();
    // Empty access token => no real LINE API calls are attempted
    const line = new LineService(users, tasks, new GeminiService(""), "", "", "liff-test");

    const replies: any[] = [];
    const pushes: any[] = [];
    line.replyMessage = async (_token, messages) => {
      replies.push(...messages);
      return true;
    };
    line.pushMessages = async (_to, messages) => {
      pushes.push(...messages);
      return true;
    };

    return { line, tasks, replies, pushes };
  };

  const messageEvent = (text: string) => ({
    type: "message",
    replyToken: "reply-1",
    source: { userId: "Uline1" },
    message: { type: "text", text },
    timestamp: Date.now(),
  });

  it("answers a list command with the task list and creates nothing", async () => {
    const { line, tasks, replies, pushes } = buildService();

    await line.handleWebhookEvents([messageEvent("งานทั้งหมดค่ะ")]);

    expect(tasks.createdInputs).toEqual([]);
    expect(pushes).toEqual([]);
    expect(replies.length).toBe(1);
    expect(replies[0].type).toBe("flex");
  });

  it("does not save chatty messages as tasks", async () => {
    const { line, tasks, replies, pushes } = buildService();

    await line.handleWebhookEvents([messageEvent("งานเยอะจัง")]);

    expect(tasks.createdInputs).toEqual([]);
    expect(pushes).toEqual([]);
    expect(replies[0].type).toBe("text");
    expect(replies[0].text).toContain("ยังไม่แน่ใจ");
  });

  it("marks the named task as done when the user says they finished it", async () => {
    const { line, tasks, replies } = buildService();
    tasks.tasks = [makeTask(1, "อ่านหนังสือสอบ"), makeTask(2, "ส่งรายงาน")];

    await line.handleWebhookEvents([messageEvent("อ่านหนังสือสอบเสร็จแล้ว")]);

    expect(tasks.completedIds).toEqual([1]);
    expect(replies[0].text).toContain("ปิดงาน");
  });

  it("closes the recommended task when no name is given", async () => {
    const { line, tasks, replies } = buildService();
    tasks.tasks = [makeTask(7, "อ่านหนังสือสอบ"), makeTask(8, "ส่งรายงาน")];

    await line.handleWebhookEvents([messageEvent("ทำงานเสร็จแล้ว")]);

    expect(tasks.completedIds).toEqual([7]);
    expect(replies[0].text).toContain("อ่านหนังสือสอบ");
  });

  it("accepts the action when the user used a shortened name", async () => {
    const { line, tasks } = buildService();
    tasks.tasks = [makeTask(1, "ส่งการบ้านแคลคูลัส"), makeTask(2, "อ่านหนังสือสอบ")];

    await line.handleWebhookEvents([messageEvent("ทำการบ้านเสร็จแล้ว")]);

    expect(tasks.completedIds).toEqual([1]);
  });

  it("asks which task instead of guessing when several match", async () => {
    const { line, tasks, replies } = buildService();
    tasks.tasks = [makeTask(1, "รายงานคณิต"), makeTask(2, "รายงานวิทย์")];

    await line.handleWebhookEvents([messageEvent("ลบงานรายงาน")]);

    expect(tasks.deletedIds).toEqual([]);
    expect(replies[0].text).toContain("เจอหลายงาน");
  });

  it("never deletes before the user confirms", async () => {
    const { line, tasks, replies } = buildService();
    tasks.tasks = [makeTask(3, "อ่านหนังสือสอบ")];

    await line.handleWebhookEvents([messageEvent("ลบงานอ่านหนังสือ")]);

    expect(tasks.deletedIds).toEqual([]);
    expect(replies[0].text).toContain('ลบงาน "อ่านหนังสือสอบ"');
    expect(replies[0].quickReply.items[0].action.text).toBe("ยืนยันลบ #3");

    // The quick reply / typed confirmation is what actually removes the task
    await line.handleWebhookEvents([messageEvent("ยืนยันลบ #3")]);

    expect(tasks.deletedIds).toEqual([3]);
    expect(replies[1].text).toContain("ลบงาน");
  });

  it("leaves the task alone when the user cancels", async () => {
    const { line, tasks, replies } = buildService();
    tasks.tasks = [makeTask(3, "อ่านหนังสือสอบ")];

    await line.handleWebhookEvents([messageEvent("ยกเลิก")]);

    expect(tasks.deletedIds).toEqual([]);
    expect(replies[0].text).toContain("ยกเลิกแล้ว");
  });

  it("reports back when the named task cannot be found", async () => {
    const { line, tasks, replies } = buildService();
    tasks.tasks = [makeTask(1, "อ่านหนังสือสอบ")];

    await line.handleWebhookEvents([messageEvent("ลบงานทำกับข้าว")]);

    expect(tasks.deletedIds).toEqual([]);
    expect(replies[0].text).toContain("ไม่พบงานที่ชื่อใกล้เคียง");
  });

  it("lets the user pick one of several tasks sharing the same name", async () => {
    const { line, tasks, replies } = buildService();
    tasks.tasks = [makeTask(11, "ส่งมินิโปรเจกต์"), makeTask(12, "ส่งมินิโปรเจกต์")];

    await line.handleWebhookEvents([messageEvent("ลบงานมินิโปรเจกต์")]);

    expect(tasks.deletedIds).toEqual([]);
    expect(replies[0].text).toContain("#11");
    expect(replies[0].text).toContain("#12");
    expect(replies[0].quickReply.items.map((item: any) => item.action.text)).toEqual([
      "ลบงาน #11",
      "ลบงาน #12",
    ]);

    // Picking by number still asks for confirmation before deleting
    await line.handleWebhookEvents([messageEvent("ลบงาน #12")]);
    expect(tasks.deletedIds).toEqual([]);
    expect(replies[1].text).toContain('ลบงาน "ส่งมินิโปรเจกต์" (#12');

    await line.handleWebhookEvents([messageEvent("ยืนยันลบ #12")]);
    expect(tasks.deletedIds).toEqual([12]);
  });

  it("closes the task the user picked by number", async () => {
    const { line, tasks, replies } = buildService();
    tasks.tasks = [makeTask(7, "อ่านหนังสือสอบ"), makeTask(8, "อ่านหนังสือสอบ")];

    await line.handleWebhookEvents([messageEvent("อ่านหนังสือสอบเสร็จแล้ว")]);
    expect(tasks.completedIds).toEqual([]);
    expect(replies[0].text).toContain("เจอหลายงาน");
    expect(replies[0].quickReply.items[0].action.text).toBe("ปิดงาน #7");

    await line.handleWebhookEvents([messageEvent("ปิดงาน #7")]);
    expect(tasks.completedIds).toEqual([7]);
  });

  it("warns before saving a task that duplicates an existing one", async () => {
    const { line, tasks, replies, pushes } = buildService();
    tasks.tasks = [makeTask(4, "ส่งรายงาน")];

    await line.handleWebhookEvents([messageEvent("พรุ่งนี้ 9 โมงส่งรายงาน 3 ดาว")]);

    expect(tasks.createdInputs).toEqual([]);
    expect(pushes).toEqual([]);
    expect(replies[0].text).toContain('มีงานชื่อ "ส่งรายงาน"');
    expect(replies[0].quickReply.items[0].action.text).toBe("ยืนยันบันทึกงาน พรุ่งนี้ 9 โมงส่งรายงาน 3 ดาว");
    expect(replies[0].quickReply.items[1].action.text).toBe("ยกเลิก");
  });

  it("saves the duplicate once the user confirms it is a separate task", async () => {
    const { line, tasks, pushes } = buildService();
    tasks.tasks = [makeTask(4, "ส่งรายงาน")];

    await line.handleWebhookEvents([messageEvent("พรุ่งนี้ 9 โมงส่งรายงาน 3 ดาว")]);
    await line.handleWebhookEvents([messageEvent("ยืนยันบันทึกงาน พรุ่งนี้ 9 โมงส่งรายงาน 3 ดาว")]);

    expect(tasks.createdInputs.length).toBe(1);
    expect(tasks.createdInputs[0].title).toBe("ส่งรายงาน");
    expect(pushes[0].type).toBe("flex");
  });

  it("saves nothing when the user cancels at the duplicate warning", async () => {
    const { line, tasks, replies } = buildService();
    tasks.tasks = [makeTask(4, "ส่งรายงาน")];

    await line.handleWebhookEvents([messageEvent("พรุ่งนี้ 9 โมงส่งรายงาน 3 ดาว")]);
    await line.handleWebhookEvents([messageEvent("ยกเลิก")]);

    expect(tasks.createdInputs).toEqual([]);
    expect(replies[1].text).toContain("ยกเลิกแล้ว");
  });

  it("catches near-duplicates written a little differently", async () => {
    const { line, tasks, replies } = buildService();
    tasks.tasks = [makeTask(11, "ส่งมินิโปรเจกต์")];

    await line.handleWebhookEvents([messageEvent("พรุ่งนี้ 9 โมงมีสมินโปรเจกต์ 3 ดาว")]);

    expect(tasks.createdInputs).toEqual([]);
    expect(replies[0].text).toContain('มีงานชื่อ "ส่งมินิโปรเจกต์"');
  });

  it("does not warn for genuinely different work", async () => {
    const { line, tasks } = buildService();
    tasks.tasks = [makeTask(4, "ติวสอบฟิสิกส์"), makeTask(5, "อ่านหนังสือสอบ")];

    // Same subject area, different topic
    await line.handleWebhookEvents([messageEvent("ติวสอบคณิต")]);
    expect(tasks.createdInputs.length).toBe(1);

    // Unrelated task
    await line.handleWebhookEvents([messageEvent("ช่วยเตือนซ้อมบาสเกตบอล")]);
    expect(tasks.createdInputs.length).toBe(2);
  });

  it("records an explicit postpone when the user postpones from the nudge card", async () => {
    const { line, tasks, replies } = buildService();
    tasks.tasks = [makeTask(7, "อ่านหนังสือสอบ")];

    await line.handleWebhookEvents([messageEvent("เลื่อนงาน #7")]);

    expect(tasks.postponedIds).toEqual([7]);
    expect(replies[0].text).toContain('เลื่อนงาน "อ่านหนังสือสอบ"');
  });

  it("makes the Action Nudge card answerable without opening the app", () => {
    const { line } = buildService();

    const card = line.createActionNudgeFlexMessage(makeTask(3, "ส่งรายงาน"));
    const actions = card.quickReply?.items.map((item: any) => item.action) ?? [];

    expect(actions.map((action: any) => action.label)).toEqual(["เริ่ม 10 นาที", "เลื่อนไปก่อน", "ทำเสร็จแล้ว"]);
    expect(actions[0].type).toBe("message");
    expect(actions[0].text).toBe("เริ่ม 10 นาที #3");
    expect(actions[1].text).toBe("เลื่อนงาน #3");
    expect(actions[2].text).toBe("ปิดงาน #3");
  });

  it("still creates a task for a real task message", async () => {
    const { line, tasks, replies, pushes } = buildService();

    await line.handleWebhookEvents([messageEvent("พรุ่งนี้ 9 โมงส่งรายงาน 3 ดาว")]);

    expect(tasks.createdInputs.length).toBe(1);
    expect(tasks.createdInputs[0].title).toBe("ส่งรายงาน");
    expect(tasks.createdInputs[0].importance).toBe(3);
    expect(tasks.createdInputs[0].estimatedMinutes).toBe(30);
    expect(replies[0].text).toContain("กำลังบันทึก");
    expect(pushes[0].type).toBe("flex");
  });
});
