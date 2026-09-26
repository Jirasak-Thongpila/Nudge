import { getRandomRotatedNudge } from "../lib/nudge";

export type TaskIntentType =
  | "CREATE_TASK"
  | "VIEW_TASKS"
  | "COMPLETE_TASK"
  | "POSTPONE_TASK"
  | "DELETE_TASK"
  | "GET_RECOMMENDATION"
  | "GET_ID"
  | "HELP"
  | "UNKNOWN";

export interface TaskIntentResult {
  intent: TaskIntentType;
  title?: string;
  deadline?: string; // ISO-8601 string
  importance?: number; // 1 to 5
  estimatedMinutes?: number; // e.g. 15, 30, 45, 60
  /** Name the user used to point at an existing task ("ลบงานอ่านหนังสือ" -> "อ่านหนังสือ"). */
  taskQuery?: string;
  /** Exact task id the user pointed at, e.g. from "ลบงาน #12". */
  taskId?: number;
  /** True only when the user explicitly confirmed a destructive action. */
  confirmed?: boolean;
  replyMessage?: string;
}

export interface AudioTaskIntentResult extends TaskIntentResult {
  transcription?: string;
}

/** Questions are never treated as an instruction to complete or delete a task. */
const CANCEL_MESSAGE = "รับทราบครับ ยกเลิกแล้ว ไม่มีการเปลี่ยนแปลงใด ๆ นะครับ 🌱";

//
// Spam guard signals. All of these run against a normalized message (no spaces,
// no polite particles) so they match the way people actually type in chat.
//

/** Words that hint the message is about something to do. */
export const TASK_KEYWORD_PATTERN =
  /(ส่ง|ทำ|สอบ|การบ้าน|โปรเจ|โครงงาน|งาน|รายงาน|อ่านหนังสือ|นัด|ประชุม|มีตติ้ง|มีทติ้ง|สัมมนา|สมินา|อบรม|ติว|เรียน|นำเสนอ|เตือน|บันทึก|present|meeting|exam|assignment|submit|project)/;

/** A date/time/duration the user mentioned — strong evidence of a real request. */
const TASK_TIME_CUE =
  /(วันนี้|พรุ่งนี้|มะรืน|วัน(จันทร์|อังคาร|พุธ|พฤหัส|ศุกร์|เสาร์|อาทิตย์)|\d{1,2}(โมง|ทุ่ม)|เที่ยง|บ่าย|\d{1,2}[:.]\d{2}|\d{1,2}\/\d{1,2}|นาที|ชั่วโมง|สัปดาห์|อาทิตย์หน้า|เดือนหน้า|สิ้นเดือน|ต้นเดือน|deadline|due)/;

/** The user asked Nudge to remind them. */
const TASK_REMINDER_CUE = /(เตือน|อย่าลืม|ไม่ลืม|remember|remind)/;

/** An action verb the user plans to do. */
const TASK_ACTION_CUE =
  /(ส่ง|ทำ|อ่าน|ทบทวน|ซ้อม|เตรียม|สอบ|ประชุม|นัด|มีตติ้ง|มีทติ้ง|เคลียร์|เขียน|จ่าย|โทร|ยื่น|นำเสนอ|อบรม|ติว|เรียน|ล้าง|ซื้อ|เก็บ|finish|submit|prepare|review|meeting|call|pay)/;

/** Greetings, thanks, praise, jokes — not tasks. */
const SMALL_TALK_PATTERN =
  /(สวัสดี|หวัดดี|ขอบคุณ|ขอบใจ|ขอบคุน|thanks|thankyou|ยอดเยี่ยม|ดีมาก|เก่งมาก|สุดยอด|เยี่ยมเลย|บาย|goodnight|goodmorning|555|ฮ่า|haha|lol)/;

/** Venting and complaints. A task may still hide inside one, see below. */
const COMPLAINT_PATTERN =
  /(เหนื่อย|เพลีย|ท้อ|ไม่มีแรง|ขี้เกียจ|ไม่อยาก|ทรมาน|เครียด|ปวดหัว|ร้องไห้|เยอะจัง|งานเยอะ|ล้นมือ|ไม่มีเวลา|โหด|burnout)/;

/** Status updates about work that is already finished. */
const DONE_REPORT_PATTERN = /(เสร็จแล้ว|เรียบร้อย|เสร็จหมด|ทำแล้ว|ส่งแล้ว|จ่ายแล้ว|ไปแล้ว|done|finished)/;

/** Question words — the user is asking something, not asking us to save a task. */
const QUESTION_PATTERN =
  /(\?|？|ไหม|มั้ย|มั๊ย|หรือเปล่า|รึเปล่า|หรือไม่|หรือยัง|รึยัง|เหรอ|หรอ|ทำไม|อะไร|ยังไง|เป็นไง|ที่ไหน|เมื่อไหร่|เมื่อไร|ใคร|เท่าไหร่|เท่าไร|กี่|บ้าง)/;

/** Ways of saying "I finished it". */
const COMPLETE_COMMAND_PATTERN =
  /(เสร็จแล้ว|เสร็จเรียบร้อย|ทำเสร็จ|ปิดงาน|จบงาน|งานเสร็จ|เสร็จหมด|เรียบร้อยแล้ว|done|finished|completed?)/g;

/** Reply used when a message is about a task but too vague to save automatically. */
export const CLARIFY_TASK_MESSAGE =
  "🤔 ยังไม่แน่ใจว่าเป็นงานที่ต้องบันทึกหรือเปล่าครับ\n" +
  "ลองพิมพ์ให้มีวัน/เวลา เช่น 'พรุ่งนี้ 9 โมงส่งรายงาน 3 ดาว' แล้ว Nudge จะบันทึกให้ทันทีครับ\n" +
  "หรือพิมพ์ 'งานทั้งหมด' เพื่อดูรายการงานที่บันทึกไว้ก็ได้ครับ";

export class GeminiService {
  private apiKey: string;
  private model: string;
  private fallbackModels: string[];

  constructor(
    apiKey?: string,
    model: string = process.env.GEMINI_MODEL || "gemini-2.5-flash-lite",
    fallbackModels: string[] = ["gemini-3-flash-preview", "gemini-2.5-flash"]
  ) {
    this.apiKey = apiKey ?? process.env.GEMINI_API_KEY ?? "";
    this.model = model;
    this.fallbackModels = fallbackModels.filter((m) => m !== model);
  }

  /**
   * Normalizes a message so intent matching survives the way people actually type:
   * invisible characters, stray spaces, polite particles ("ค่ะ", "ครับ") and the
   * common misspellings of "ทั้งหมด". Only used for intent detection, never for titles.
   */
  normalizeMessage(text: string): string {
    let normalized = text
      .replace(/[\u200B-\u200D\u2060\uFEFF]/g, "")
      .replace(/[\u00A0\u2007\u202F]/g, " ")
      .toLowerCase()
      .replace(/ทั้?งห?มด/g, "ทั้งหมด")
      .replace(/\s+/g, "");

    let previous = "";
    while (normalized !== previous) {
      previous = normalized;
      normalized = normalized
        .replace(/(ครับ|ค่ะ|คะ|คับ|จ้า|จ๊ะ|ค่า|นะ|ด้วย|หน่อย|ที)$/, "")
        .replace(/(ของ)?(ฉัน|ผม|เรา|กู|หนู)$/, "");
    }

    return normalized;
  }

  private isIdIntent(normalized: string): boolean {
    return ["id", "uid", "userid", "lineid", "ไลน์ไอดี", "ไอดี", "ขอไอดี"].includes(normalized);
  }

  private isViewIntent(normalized: string): boolean {
    const core = normalized
      .replace(/^(ขอดู|ดู|ขอ|เช็ค|เช็ก|แสดง|เปิดดู|โชว์|บอก|สรุป)/, "")
      .replace(/(มี)?อะไร(บ้าง)?$|เป็นไง(บ้าง)?$|เป็นยังไง(บ้าง)?$|มีไร(บ้าง)?$/, "");

    return [
      "งาน",
      "งานวันนี้",
      "งานทั้งหมด",
      "งานค้าง",
      "งานที่ต้องทำ",
      "งานอะไร",
      "มีงาน",
      "มีงานอะไร",
      "รายการ",
      "รายการงาน",
      "ตารางงาน",
      "tasks",
      "task",
      "alltasks",
      "list",
      "todo",
      "mytasks",
    ].includes(core);
  }

  private isRecommendationIntent(normalized: string): boolean {
    return (
      normalized.includes("แนะนำ") ||
      ["nudge", "focus", "เริ่ม", "ทำอะไรดี", "เริ่มงานไหนดี", "ทำอะไรก่อนดี", "งานไหนก่อน"].includes(
        normalized
      )
    );
  }

  private isHelpIntent(normalized: string): boolean {
    return ["help", "helpme", "ช่วยเหลือ", "วิธีใช้", "วิธีใช้งาน", "ใช้งานยังไง", "คำสั่ง", "ทำอะไรได้บ้าง"].includes(
      normalized
    );
  }

  /**
   * Recognizes chat commands that act on an existing task: completing it
   * ("ทำการบ้านเสร็จแล้ว") or deleting it ("ลบงานอ่านหนังสือ", "ยืนยันลบ #12").
   * Returns null when the message is not such a command.
   */
  parseTaskLifecycleIntent(text: string): TaskIntentResult | null {
    const normalized = this.normalizeMessage(text);
    if (!normalized) {
      return null;
    }

    // Confirmation of a delete prompt, typed or tapped from the quick reply
    const confirmDelete = normalized.match(/^(ยืนยันลบ|ยืนยันการลบ|ลบเลย|ยืนยัน)(งาน)?#?(\d+)$/);
    if (confirmDelete) {
      return { intent: "DELETE_TASK", taskId: parseInt(confirmDelete[3], 10), confirmed: true };
    }

    if (["ยกเลิก", "cancel", "ไม่ลบ", "ไม่ต้องลบ"].includes(normalized)) {
      return { intent: "UNKNOWN", replyMessage: CANCEL_MESSAGE };
    }

    // "ทำงานเสร็จหรือยัง" is a question, not an instruction
    if (QUESTION_PATTERN.test(normalized)) {
      return null;
    }

    // Delete must be phrased as a command at the start, otherwise a real task
    // such as "พรุ่งนี้ลบไฟล์ชั่วคราว" would be swallowed.
    const deleteMatch = normalized.match(/^(ลบงานทิ้ง|ลบงาน|ยกเลิกงาน|เอาออกงาน|ลบ|delete|remove)(.*)$/);
    if (deleteMatch) {
      const rest = this.cleanTaskQuery(deleteMatch[2]);
      const taskId = this.parseTaskId(rest);
      return taskId ? { intent: "DELETE_TASK", taskId } : { intent: "DELETE_TASK", taskQuery: rest };
    }

    // "เลื่อนไปก่อน" is the explicit postpone action: a deliberate choice, which the
    // avoidance detection counts (unlike a passed deadline).
    const postponeMatch = normalized.match(/^(เลื่อนงาน|ขอเลื่อนงาน|เลื่อน|ขอเลื่อน|postpone|snooze)(.*)$/);
    if (postponeMatch) {
      const rest = this.cleanTaskQuery(postponeMatch[2]);
      const taskId = this.parseTaskId(rest);
      if (taskId) {
        return { intent: "POSTPONE_TASK", taskId };
      }

      return { intent: "POSTPONE_TASK", taskQuery: rest.replace(/(ไปก่อน|ออกไป|ก่อน|หน่อย|เลย|ที)/g, "") };
    }

    if (normalized.match(COMPLETE_COMMAND_PATTERN)) {
      // Strip every command word, then any leftover "แล้ว":
      // "อ่านหนังสือสอบเสร็จแล้ว" -> "อ่านหนังสือสอบ", "ทำงานเสร็จแล้ว" -> "ทำ"
      const query = this.cleanTaskQuery(normalized.replace(COMPLETE_COMMAND_PATTERN, " ").replace(/แล้ว/g, " "));
      const taskId = this.parseTaskId(query);
      return taskId ? { intent: "COMPLETE_TASK", taskId } : { intent: "COMPLETE_TASK", taskQuery: query };
    }

    return null;
  }

  private cleanTaskQuery(query: string): string {
    return query.replace(/[\s"'“”]/g, "");
  }

  /**
   * Task references by number ("ลบงาน #12", "ปิดงาน 12") let a user pick one task
   * out of several with the same name.
   */
  private parseTaskId(query: string): number | undefined {
    const digits = query.replace(/^#/, "");
    return /^\d{1,9}$/.test(digits) ? parseInt(digits, 10) : undefined;
  }

  /**
   * Whether a message actually asks Nudge to track something, rather than being
   * small talk, a question, a complaint or a "finished it already" status report.
   * The fast parser only stores tasks that pass this gate.
   */
  looksLikeTaskRequest(text: string): boolean {
    const normalized = this.normalizeMessage(text);
    if (!normalized || !TASK_KEYWORD_PATTERN.test(normalized)) {
      return false;
    }

    if (this.isHardSpamSignal(normalized)) {
      return false;
    }

    // A date, a time or an explicit "remind me" is enough on its own.
    if (TASK_TIME_CUE.test(normalized) || TASK_REMINDER_CUE.test(normalized)) {
      return true;
    }

    // Otherwise we need an action to do, with no venting around it.
    if (SMALL_TALK_PATTERN.test(normalized) || COMPLAINT_PATTERN.test(normalized)) {
      return false;
    }

    return TASK_ACTION_CUE.test(normalized);
  }

  /**
   * Whether a message has no business being stored as a task at all. Used to veto
   * an over-eager CREATE_TASK decision coming back from Gemini.
   */
  isClearlyNotTaskRequest(text: string): boolean {
    const normalized = this.normalizeMessage(text);
    if (!normalized) {
      return true;
    }

    if (this.isHardSpamSignal(normalized)) {
      return true;
    }

    if (SMALL_TALK_PATTERN.test(normalized) || COMPLAINT_PATTERN.test(normalized)) {
      // Venting that still names a deadline is a real task:
      // "เหนื่อยจัง แต่พรุ่งนี้ต้องส่งงาน"
      return !(TASK_TIME_CUE.test(normalized) || TASK_REMINDER_CUE.test(normalized));
    }

    return false;
  }

  private isHardSpamSignal(normalized: string): boolean {
    return QUESTION_PATTERN.test(normalized) || DONE_REPORT_PATTERN.test(normalized);
  }

  /**
   * Parses natural language Thai user messages into structured task actions or intents using Gemini API.
   */
  /**
   * Calls Gemini generateContent with automatic fallback across multiple models
   * if the current model encounters quota limits (429), temporary unavailability (503), or server errors.
   */
  private async callGeminiWithFallback(
    payloadBuilder: () => any,
    candidateModels: string[] = [this.model, ...this.fallbackModels]
  ): Promise<{ ok: boolean; status: number; text?: string; data?: any; usedModel?: string }> {
    const modelsToTry = Array.from(new Set(candidateModels));
    let lastStatus = 0;
    let lastErrorText = "";

    for (let i = 0; i < modelsToTry.length; i++) {
      const currentModel = modelsToTry[i];
      try {
        const response = await fetch(
          `https://generativelanguage.googleapis.com/v1beta/models/${currentModel}:generateContent?key=${this.apiKey}`,
          {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
            },
            body: JSON.stringify(payloadBuilder()),
          }
        );

        if (response.ok) {
          const data = (await response.json()) as any;
          return { ok: true, status: response.status, data, usedModel: currentModel };
        }

        const errText = await response.text();
        lastStatus = response.status;
        lastErrorText = errText;

        const nextModel = modelsToTry[i + 1];
        if (nextModel && (response.status === 429 || response.status >= 500 || response.status === 404)) {
          console.warn(
            `[GeminiService] Model '${currentModel}' failed with status ${response.status}. Falling back to '${nextModel}'...`
          );
          continue;
        } else {
          console.error(
            `[GeminiService] Model '${currentModel}' failed with status ${response.status}: ${errText.slice(0, 160)}`
          );
        }
      } catch (err) {
        lastStatus = 500;
        lastErrorText = String(err);
        const nextModel = modelsToTry[i + 1];
        if (nextModel) {
          console.warn(
            `[GeminiService] Network/fetch error on model '${currentModel}'. Falling back to '${nextModel}'...`,
            err
          );
          continue;
        }
      }
    }

    return { ok: false, status: lastStatus, text: lastErrorText };
  }

  /**
   * Enforces Nudge's consistent male buddy persona by normalizing polite particles to "ครับ" / "นะครับ".
   */
  normalizePoliteParticles(text?: string): string | undefined {
    if (!text) return text;
    return text
      .replace(/ค่ะ\/ครับ|ครับ\/ค่ะ|คะ\/ครับ|ครับ\/คะ/g, "ครับ")
      .replace(/(นะค่ะ|นะคะ)/g, "นะครับ")
      .replace(/ค่ะ/g, "ครับ")
      .replace(/(ไหม|มั้ย|หรือเปล่า|เหรอ|หรอ|หรือ|ล่ะ|เล่า|จ๊ะ)คะ/g, "$1ครับ")
      .replace(/(^|\s|[.,!?])คะ(?=\s|[.,!?]|$)/g, "$1ครับ");
  }

  async parseTaskIntent(message: string, now: Date = new Date()): Promise<TaskIntentResult> {
    const raw = message.trim();
    if (!raw) {
      return { intent: "UNKNOWN", replyMessage: "กรุณาระบุข้อความที่ต้องการให้ Nudge ช่วยเหลือครับ" };
    }

    // "ยืนยันบันทึกงาน <ข้อความเดิม>" comes from the duplicate warning quick reply:
    // the user chose to save a second copy anyway.
    const saveConfirmation = this.stripSaveConfirmation(raw);
    const confirmed = saveConfirmation.confirmed;
    const trimmed = saveConfirmation.text || raw;

    // Quick regex fast-path for common single keywords. Matching runs on a
    // normalized form so that "งานทั้งหมดค่ะ", "งาน ทังหมด" and "\u200Bงานทั้งหมด"
    // are recognized as the same command instead of falling through to task creation.
    const normalized = this.normalizeMessage(trimmed);

    if (this.isIdIntent(normalized)) {
      return { intent: "GET_ID" };
    }
    if (this.isViewIntent(normalized)) {
      return { intent: "VIEW_TASKS" };
    }
    if (this.isRecommendationIntent(normalized)) {
      return { intent: "GET_RECOMMENDATION" };
    }
    if (this.isHelpIntent(normalized)) {
      return {
        intent: "HELP",
        replyMessage:
          "🌱 Nudge Assistant พร้อมช่วยคุณเริ่มต้นงานสำคัญ:\n\n" +
          "• พิมพ์บอกงาน เช่น 'พรุ่งนี้ 9 โมงส่งมินิโปรเจกต์ สำคัญมาก'\n" +
          "• พิมพ์ 'งานทั้งหมด' เพื่อดูรายการงานทั้งหมด\n" +
          "• พิมพ์ 'แนะนำ' เพื่อดูงานที่ควรเริ่มทำ 10 นาทีแรก\n" +
          "• พิมพ์ 'ทำการบ้านเสร็จแล้ว' เพื่อปิดงานที่ทำเสร็จ\n" +
          "• พิมพ์ 'ลบงานอ่านหนังสือ' เพื่อลบงานที่ไม่ต้องการแล้ว\n" +
          "• พิมพ์ 'id' เพื่อดู LINE User ID ของคุณ",
      };
    }

    // "I finished it" / "delete this" commands are resolved before task creation,
    // so "ทำงานเสร็จแล้ว" never becomes a brand new task.
    const lifecycle = this.parseTaskLifecycleIntent(trimmed);
    if (lifecycle) {
      return lifecycle;
    }

    // Fast path: Ultra-fast Thai regex parser for instantaneous response (0ms)
    const fastParsed = this.fastParseThaiTask(trimmed, now);
    if (fastParsed) {
      return this.withSaveConfirmation(fastParsed, confirmed);
    }

    // If Gemini API Key is not set, use heuristic fallback
    if (!this.apiKey) {
      return this.fallbackHeuristicParser(trimmed, now);
    }

    try {
      const systemPrompt = `You are Nudge, an empathetic, supportive, and friendly Thai productivity buddy (เพื่อนคู่คิด).
Analyze the user's Thai or English message and extract the user's intent and structured task details.
The current date and time is: ${now.toISOString()} (Timezone: Asia/Bangkok, UTC+7).

Persona & Tone:
- Always speak as a warm, friendly, and supportive male buddy using polite ending particles "ครับ" / "นะครับ".
- Strictly NEVER use "ค่ะ" or "นะคะ".

Rules:
1. If the user wants to add or create a task (e.g. "พรุ่งนี้ส่งงาน...", "มีสอบวันศุกร์...", "ช่วยเตือนทำการบ้าน..."), set intent to "CREATE_TASK":
   - Extract "title": clean task title built only from words the user actually wrote. Never add an action verb or noun that is not in the message — for example, if the user says "มีมินิโปรเจกต์" do not return "ส่งมินิโปรเจกต์".
   - Extract "deadline": compute full ISO-8601 string based on the current time and user's requested time in Asia/Bangkok (+07:00). If the user specifies "พรุ่งนี้" (tomorrow), the deadline MUST be the next calendar day in Bangkok (+07:00). Default time to 23:59:59 if only date is specified (e.g. if today is 2026-09-26, tomorrow is "2026-09-27T23:59:59+07:00"). Never set a tomorrow task to today.
   - Extract "importance": integer from 1 to 5. If the user typed an explicit rating such as "3 ดาว", "3/5", or "ระดับ 3", use that exact number — it overrides descriptive words like "สำคัญมาก"/"ด่วน". Otherwise default to 3 (5 if urgent/very important).
   - Extract "estimatedMinutes": estimated duration in minutes (default to 30 if unspecified).
2. If the user asks to see their tasks or check what to do, set intent to "VIEW_TASKS".
3. If the user asks for a recommendation or what to start now, set intent to "GET_RECOMMENDATION".
3.1. If the user says they finished something ("ทำการบ้านเสร็จแล้ว", "อ่านหนังสือจบแล้ว"), set intent to "COMPLETE_TASK" and put the name they used in "taskQuery".
3.2. If the user wants to remove a task ("ลบงานอ่านหนังสือ", "ยกเลิกงานสอบ"), set intent to "DELETE_TASK" and put the name they used in "taskQuery".
3.3. If the user says they are putting something off ("เลื่อนไปก่อน", "ขอเลื่อนอ่านหนังสือ"), set intent to "POSTPONE_TASK" and put the name they used in "taskQuery".
4. If it's a general greeting, casual talk, small talk, or unrelated query, set intent to "UNKNOWN" and provide a helpful, friendly, and empathetic replyMessage in Thai using "ครับ" / "นะครับ" (never "ค่ะ" / "นะคะ").
5. Never use "CREATE_TASK" for small talk, thanks, praise, complaints or venting ("งานเยอะจัง", "เหนื่อยมาก"), questions about a schedule, or messages saying something is already done. Use "UNKNOWN" with a short, empathetic replyMessage using "ครับ" / "นะครับ" that invites the user to state a concrete task with a day or time.`;

      const responseResult = await this.callGeminiWithFallback(() => ({
        contents: [
          {
            role: "user",
            parts: [{ text: `${systemPrompt}\n\nUser Message: "${trimmed}"` }],
          },
        ],
        generationConfig: {
          responseMimeType: "application/json",
          responseSchema: {
            type: "object",
            properties: {
              intent: {
                type: "string",
                enum: [
                  "CREATE_TASK",
                  "VIEW_TASKS",
                  "COMPLETE_TASK",
                  "POSTPONE_TASK",
                  "DELETE_TASK",
                  "GET_RECOMMENDATION",
                  "GET_ID",
                  "HELP",
                  "UNKNOWN",
                ],
              },
              title: { type: "string" },
              deadline: { type: "string" },
              importance: { type: "integer" },
              estimatedMinutes: { type: "integer" },
              taskQuery: { type: "string" },
              replyMessage: { type: "string" },
            },
            required: ["intent"],
          },
        },
      }));

      if (!responseResult.ok || !responseResult.data) {
        return this.fallbackHeuristicParser(trimmed, now);
      }

      const contentText = responseResult.data?.candidates?.[0]?.content?.parts?.[0]?.text;
      if (!contentText) {
        return this.fallbackHeuristicParser(trimmed, now);
      }

      const parsed = JSON.parse(contentText) as TaskIntentResult;
      if (parsed.replyMessage) {
        parsed.replyMessage = this.normalizePoliteParticles(parsed.replyMessage);
      }
      if (parsed.intent === "CREATE_TASK" && !confirmed && this.isClearlyNotTaskRequest(trimmed)) {
        return { intent: "UNKNOWN", replyMessage: CLARIFY_TASK_MESSAGE };
      }
      return this.withSaveConfirmation(parsed, confirmed);
    } catch (error) {
      console.error("Gemini parsing error:", error);
      return this.fallbackHeuristicParser(trimmed, now);
    }
  }

  /**
   * Ultra-fast Thai regex parser for common task creation sentences (0ms execution).
   */
  fastParseThaiTask(text: string, now: Date = new Date()): TaskIntentResult | null {
    const trimmed = text.trim();

    // Tolerates common Thai spellings and typos ("โปรเจค" without the final ต์,
    // "สมินา" for seminar) so real task messages are not silently dropped.
    const hasTaskKeyword = TASK_KEYWORD_PATTERN.test(this.normalizeMessage(trimmed));

    if (!hasTaskKeyword) {
      return null;
    }

    // Spam guard: never turn small talk, questions, complaints or "done already"
    // status reports into tasks just because they mention the word "งาน".
    if (!this.looksLikeTaskRequest(trimmed)) {
      return null;
    }

    // 1. Extract Importance (1 to 5).
    // A rating the user typed explicitly ("3 ดาว", "3/5") always wins over
    // descriptive words, otherwise "สำคัญมาก" silently overwrites the number
    // the user actually chose.
    let importance = 3;
    const starMatch = trimmed.match(/([1-5])\s*(?:ดาว|\/\s*5)/);
    if (starMatch) {
      importance = parseInt(starMatch[1], 10);
    } else if (/สำคัญมาก|ด่วนที่สุด|ด่วนมาก|urgent/i.test(trimmed)) {
      importance = 5;
    } else if (/ไม่ด่วน|ไม่สำคัญ/i.test(trimmed)) {
      importance = 1;
    } else if (/สำคัญ/i.test(trimmed)) {
      importance = 4;
    }

    // 2. Extract Estimated Minutes
    let estimatedMinutes = 30;
    const minMatch = trimmed.match(/(\d+)\s*(นาที|min|mins)/i);
    const hourMatch = trimmed.match(/(\d+)\s*(ชั่วโมง|ชม|hour|hours|hr|hrs)/i);
    if (minMatch) {
      estimatedMinutes = parseInt(minMatch[1], 10);
    } else if (hourMatch) {
      estimatedMinutes = parseInt(hourMatch[1], 10) * 60;
    }

    // 3. Extract Date & Time
    let targetDate = new Date(now);
    let hasSpecificDate = false;

    if (trimmed.includes("วันนี้")) {
      hasSpecificDate = true;
    } else if (trimmed.includes("มะรืน")) {
      targetDate.setDate(targetDate.getDate() + 2);
      hasSpecificDate = true;
    } else if (trimmed.includes("พรุ่งนี้") || trimmed.includes("พรุ่งนี") || trimmed.includes("พรุ่งตอน") || trimmed.includes("พรุ่ง")) {
      targetDate.setDate(targetDate.getDate() + 1);
      hasSpecificDate = true;
    } else {
      const days = [
        { name: "อาทิตย์", day: 0 },
        { name: "จันทร์", day: 1 },
        { name: "อังคาร", day: 2 },
        { name: "พุธ", day: 3 },
        { name: "พฤหัส", day: 4 },
        { name: "ศุกร์", day: 5 },
        { name: "เสาร์", day: 6 },
      ];
      for (const d of days) {
        if (trimmed.includes(`วัน${d.name}`)) {
          const currentDay = targetDate.getDay();
          let diff = d.day - currentDay;
          if (diff <= 0) diff += 7;
          targetDate.setDate(targetDate.getDate() + diff);
          hasSpecificDate = true;
          break;
        }
      }
    }

    if (!hasSpecificDate) {
      targetDate.setDate(targetDate.getDate() + 1);
    }

    // 4. Extract Hour & Minute
    let targetHour = 23;
    let targetMinute = 59;

    const time12Match = trimmed.match(/(\d{1,2})[:.](\d{2})/);
    const mongMatch = trimmed.match(/(\d{1,2})\s*โมง\s*(เช้า|เย็น|ค่ำ)?/);
    const toomMatch = trimmed.match(/(\d{1,2})\s*ทุ่ม/);
    const baiMatch = trimmed.match(/บ่าย\s*(\d{1,2})/);

    if (time12Match) {
      targetHour = parseInt(time12Match[1], 10);
      targetMinute = parseInt(time12Match[2], 10);
    } else if (toomMatch) {
      targetHour = 18 + parseInt(toomMatch[1], 10);
      targetMinute = 0;
    } else if (baiMatch) {
      targetHour = 12 + parseInt(baiMatch[1], 10);
      targetMinute = 0;
    } else if (mongMatch) {
      const h = parseInt(mongMatch[1], 10);
      const period = mongMatch[2];
      if (period === "เย็น" || period === "ค่ำ") {
        targetHour = h < 12 ? h + 12 : h;
      } else {
        targetHour = h <= 5 ? h + 12 : h;
      }
      targetMinute = 0;
    } else if (trimmed.includes("เที่ยงคืน")) {
      targetHour = 23;
      targetMinute = 59;
    } else if (trimmed.includes("เที่ยงวัน") || trimmed.includes("เที่ยง")) {
      targetHour = 12;
      targetMinute = 0;
    }

    targetDate.setHours(targetHour, targetMinute, 0, 0);

    // 5. Clean Title
    let title = trimmed
      .replace(/(วันนี้|พรุ่งนี้|มะรืนนี้|วันจันทร์|วันอังคาร|วันพุธ|วันพฤหัสบดี|วันพฤหัส|วันศุกร์|วันเสาร์|วันอาทิตย์)/g, "")
      .replace(/(\d{1,2}[:.]\d{2}\s*(น\.|น)?|\d{1,2}\s*โมง(เช้า|เย็น)?|\d{1,2}\s*ทุ่ม|บ่าย\s*\d{1,2}(\s*โมง)?|เที่ยงคืน|เที่ยง)/g, "")
      .replace(/(\d+\s*ดาว|\d+\s*\/\s*5|ไม่สำคัญ|ไม่ด่วน|สำคัญมาก|สำคัญ|ด่วนที่สุด|ด่วน|urgent)/g, "")
      .replace(/(\d+\s*(นาที|ชั่วโมง|ชม|min|mins|hr|hrs))/g, "")
      .trim();

    const strippedTitle = title;

    // Venting often wraps the real task ("เหนื่อยจัง แต่พรุ่งนี้ต้องส่งงาน"):
    // keep the part the user actually asked for.
    if (COMPLAINT_PATTERN.test(this.normalizeMessage(title)) && title.includes("แต่")) {
      title = title.slice(title.lastIndexOf("แต่") + "แต่".length).trim();
    }

    title = title
      .replace(/^(ช่วยเตือน|สร้างงาน|เพิ่มงาน|ช่วยบันทึก|บันทึก)\s*/i, "")
      .replace(/^มีส่ง\s*/i, "ส่ง")
      .replace(/^ต้องส่ง\s*/i, "ส่ง")
      .replace(/^มี\s*/i, "")
      .replace(/^ต้อง\s*/i, "")
      .trim();

    // Fall back to the user's own words instead of inventing a title: recording a
    // slightly noisy title beats recording one the user never said.
    if (!title || title.length < 2) {
      title = strippedTitle || trimmed;
    }

    if (
      trimmed.includes("ส่ง") &&
      !title.startsWith("ส่ง") &&
      !title.includes("ส่ง") &&
      !title.startsWith("การบ้าน")
    ) {
      title = `ส่ง${title}`;
    }

    return {
      intent: "CREATE_TASK",
      title,
      deadline: targetDate.toISOString(),
      importance,
      estimatedMinutes,
    };
  }

  /**
   * Fallback rule-based parser when Gemini API is unavailable.
   */
  /**
   * Splits the "save it anyway" confirmation prefix off a message.
   */
  private stripSaveConfirmation(text: string): { text: string; confirmed: boolean } {
    const match = text.match(/^(ยืนยันบันทึกงาน|ยืนยันบันทึก|ยืนยันสร้างงาน|ยืนยันสร้าง|บันทึกซ้ำ|สร้างซ้ำ)\s*/);
    if (!match) {
      return { text, confirmed: false };
    }

    return { text: text.slice(match[0].length).trim(), confirmed: true };
  }

  private withSaveConfirmation(result: TaskIntentResult, confirmed: boolean): TaskIntentResult {
    return confirmed && result.intent === "CREATE_TASK" ? { ...result, confirmed: true } : result;
  }

  private fallbackHeuristicParser(text: string, now: Date): TaskIntentResult {
    const fast = this.fastParseThaiTask(text, now);
    if (fast) return fast;

    // The message mentioned a task but was blocked by the spam guard — ask for a
    // clear date/time instead of silently storing nothing.
    if (TASK_KEYWORD_PATTERN.test(this.normalizeMessage(text))) {
      return { intent: "UNKNOWN", replyMessage: CLARIFY_TASK_MESSAGE };
    }

    return {
      intent: "UNKNOWN",
      replyMessage: `สวัสดีครับ! สามารถพิมพ์บอกงาน เช่น "พรุ่งนี้ส่งโปรเจกต์" หรือพิมพ์ "งานวันนี้" เพื่อดูงานได้เลยครับ 🌱`,
    };
  }

  /**
   * Multimodal audio parser using Gemini 1.5/2.0 Flash.
   * Transcribes Thai speech and extracts structured task intent in a single call.
   */
  async parseTaskFromAudio(
    audioBuffer: Buffer,
    mimeType: string = "audio/m4a",
    now: Date = new Date()
  ): Promise<AudioTaskIntentResult> {
    if (!this.apiKey) {
      return {
        intent: "UNKNOWN",
        replyMessage: "ระบบบันทึกเสียงต้องการ Gemini API Key ในการประมวลผลครับ",
      };
    }

    const base64Audio = audioBuffer.toString("base64");
    const systemPrompt = `You are Nudge, an intelligent multimodal voice assistant and supportive productivity buddy (เพื่อนคู่คิด).
Listen carefully to the user's spoken audio (primarily in Thai or English).
First, accurately transcribe what the user said in "transcription".
Second, analyze their intent and extract structured task details if they are asking to add or track a task.
The current date and time is: ${now.toISOString()} (Timezone: Asia/Bangkok, UTC+7).

Persona & Tone:
- Always speak as a warm, friendly, and supportive male buddy using polite ending particles "ครับ" / "นะครับ".
- Strictly NEVER use "ค่ะ" or "นะคะ".

Rules:
1. "transcription": verbatim transcription of user speech in Thai.
2. If the user wants to add/create a task, set intent to "CREATE_TASK":
   - "title": clean, concise title in Thai (from the user's spoken words).
   - "deadline": ISO-8601 string. If the user only specifies a day (e.g. "พรุ่งนี้", "วันศุกร์"), default time to 23:59:59.
   - "importance": integer 1-5 (default to 3 if not specified, 4 or 5 if "สำคัญ"/"ด่วน").
   - "estimatedMinutes": integer minutes (default to 30 if not specified).
3. If the user asks what tasks they have, set intent to "VIEW_TASKS".
4. If the user asks for a recommendation or what to start now, set intent to "GET_RECOMMENDATION".
5. If the user says they completed a task, set intent to "COMPLETE_TASK".
6. If the user asks to postpone, set intent to "POSTPONE_TASK".
7. If casual talk, unclear audio, or venting, set intent to "UNKNOWN" with an empathetic Thai "replyMessage" using "ครับ" / "นะครับ" (never "ค่ะ" / "นะคะ").`;

    const audioCandidates = [
      this.model,
      ...this.fallbackModels,
    ].filter((m) => m !== "gemini-3-flash-preview");
    if (!audioCandidates.includes("gemini-2.5-flash-lite")) {
      audioCandidates.push("gemini-2.5-flash-lite");
    }

    try {
      const responseResult = await this.callGeminiWithFallback(
        () => ({
          contents: [
            {
              role: "user",
              parts: [
                { text: systemPrompt },
                {
                  inlineData: {
                    mimeType,
                    data: base64Audio,
                  },
                },
              ],
            },
          ],
          generationConfig: {
            responseMimeType: "application/json",
            responseSchema: {
              type: "object",
              properties: {
                transcription: { type: "string" },
                intent: {
                  type: "string",
                  enum: [
                    "CREATE_TASK",
                    "VIEW_TASKS",
                    "COMPLETE_TASK",
                    "POSTPONE_TASK",
                    "DELETE_TASK",
                    "GET_RECOMMENDATION",
                    "GET_ID",
                    "HELP",
                    "UNKNOWN",
                  ],
                },
                title: { type: "string" },
                deadline: { type: "string" },
                importance: { type: "integer" },
                estimatedMinutes: { type: "integer" },
                taskQuery: { type: "string" },
                replyMessage: { type: "string" },
              },
              required: ["intent", "transcription"],
            },
          },
        }),
        audioCandidates
      );

      if (!responseResult.ok || !responseResult.data) {
        if (responseResult.status === 429) {
          return {
            intent: "UNKNOWN",
            replyMessage:
              "ขออภัยครับ โควตาการประมวลผลเสียงของระบบเต็มชั่วคราว กรุณาลองใหม่อีกครั้ง หรือพิมพ์เป็นข้อความแทนได้นะครับ 🌱",
          };
        }
        return {
          intent: "UNKNOWN",
          replyMessage: "ขออภัยครับ เกิดข้อผิดพลาดในการประมวลผลเสียง กรุณาลองใหม่อีกครั้งนะครับ",
        };
      }

      const contentText = responseResult.data.candidates?.[0]?.content?.parts?.[0]?.text;
      if (!contentText) {
        return {
          intent: "UNKNOWN",
          replyMessage: "ฟังเสียงไม่ค่อยชัดเจนเลยครับ รบกวนลองส่งใหม่อีกครั้งนะครับ",
        };
      }

      const parsed = JSON.parse(contentText) as AudioTaskIntentResult;
      if (parsed.replyMessage) {
        parsed.replyMessage = this.normalizePoliteParticles(parsed.replyMessage);
      }
      // Apply sensible defaults if CREATE_TASK
      if (parsed.intent === "CREATE_TASK") {
        if (!parsed.importance) parsed.importance = 3;
        if (!parsed.estimatedMinutes) parsed.estimatedMinutes = 30;
        if (!parsed.deadline) {
          const defaultDeadline = new Date(now);
          defaultDeadline.setHours(23, 59, 59, 999);
          parsed.deadline = defaultDeadline.toISOString();
        }
      }
      return parsed;
    } catch (error) {
      console.error("Gemini audio parsing error:", error);
      return {
        intent: "UNKNOWN",
        replyMessage: "ขออภัยครับ ไม่สามารถถอดความเสียงได้ในขณะนี้ กรุณาลองใหม่อีกครั้งนะครับ",
      };
    }
  }

  /**
   * Generates a fresh, non-repetitive Thai action nudge tailored to the task and context.
   * Adheres strictly to the warm accountability buddy persona and zero-shaming principles.
   */
  async generateDynamicNudge(
    task: { title: string; postponeCount: number; deadline: Date; importance: number },
    timeOfDay: "morning" | "afternoon" | "evening" = "afternoon"
  ): Promise<string> {
    if (!this.apiKey) {
      return getRandomRotatedNudge(task.title, task.postponeCount, timeOfDay);
    }

    const prompt = `You are Nudge, an empathetic and supportive Thai productivity buddy (เพื่อนคู่คิด).
Write a fresh, natural Thai nudge message (1-2 short sentences) inviting the user to start working on: "${task.title}" for just 10 minutes.

Context:
- Task: "${task.title}"
- Importance rating: ${task.importance}/5
- Times postponed so far: ${task.postponeCount}
- Current time of day: ${timeOfDay}

Rules:
1. Warm, conversational Thai with polite ending particle (ครับ).
2. ZERO GUILT / ZERO SHAMING: Never judge, scold, pressure, or ask why they haven't done it.
3. Suggest a tiny, low-friction micro-step (open the file, sketch an outline, just 10 mins).
4. Integrate the task name naturally. Max 1-2 emojis.
Output strictly JSON: { "nudgeMessage": "..." }`;

    try {
      const responseResult = await this.callGeminiWithFallback(() => ({
        contents: [{ role: "user", parts: [{ text: prompt }] }],
        generationConfig: {
          responseMimeType: "application/json",
          responseSchema: {
            type: "object",
            properties: { nudgeMessage: { type: "string" } },
            required: ["nudgeMessage"],
          },
        },
      }));

      if (responseResult.ok && responseResult.data) {
        const text = responseResult.data.candidates?.[0]?.content?.parts?.[0]?.text;
        if (text) {
          const parsed = JSON.parse(text);
          if (parsed.nudgeMessage) {
            return this.normalizePoliteParticles(parsed.nudgeMessage) || parsed.nudgeMessage;
          }
        }
      }
    } catch (err) {
      console.error("Gemini dynamic nudge generation error:", err);
    }

    return getRandomRotatedNudge(task.title, task.postponeCount, timeOfDay);
  }
}

export const geminiService = new GeminiService();
