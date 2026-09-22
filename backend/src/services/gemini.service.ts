export type TaskIntentType =
  | "CREATE_TASK"
  | "VIEW_TASKS"
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
  replyMessage?: string;
}

export class GeminiService {
  private apiKey: string;
  private model: string;

  constructor(apiKey?: string, model: string = "gemini-2.5-flash") {
    this.apiKey = apiKey ?? process.env.GEMINI_API_KEY ?? "";
    this.model = model;
  }

  /**
   * Parses natural language Thai user messages into structured task actions or intents using Gemini API.
   */
  async parseTaskIntent(message: string, now: Date = new Date()): Promise<TaskIntentResult> {
    const trimmed = message.trim();
    if (!trimmed) {
      return { intent: "UNKNOWN", replyMessage: "กรุณาระบุข้อความที่ต้องการให้ Nudge ช่วยเหลือครับ" };
    }

    // Quick regex fast-path for common single keywords
    const lower = trimmed.toLowerCase();
    if (lower === "id" || lower === "uid" || lower === "userid" || lower === "ไอดี" || lower === "ขอไอดี") {
      return { intent: "GET_ID" };
    }
    if (
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
      lower.startsWith("รายการ")
    ) {
      return { intent: "VIEW_TASKS" };
    }
    if (
      lower === "แนะนำ" ||
      lower === "nudge" ||
      lower === "focus" ||
      lower === "เริ่ม" ||
      lower === "ทำอะไรดี" ||
      lower === "เริ่มงานไหนดี" ||
      lower.includes("แนะนำ")
    ) {
      return { intent: "GET_RECOMMENDATION" };
    }
    if (lower === "help" || lower === "ช่วยเหลือ" || lower === "วิธีใช้" || lower === "คำสั่ง" || lower === "ทำอะไรได้บ้าง") {
      return {
        intent: "HELP",
        replyMessage:
          "🌱 Nudge Assistant พร้อมช่วยคุณเริ่มต้นงานสำคัญ:\n\n" +
          "• พิมพ์บอกงาน เช่น 'พรุ่งนี้ 9 โมงส่งมินิโปรเจกต์ สำคัญมาก'\n" +
          "• พิมพ์ 'งานทั้งหมด' เพื่อดูรายการงานทั้งหมด\n" +
          "• พิมพ์ 'แนะนำ' เพื่อดูงานที่ควรเริ่มทำ 10 นาทีแรก\n" +
          "• พิมพ์ 'id' เพื่อดู LINE User ID ของคุณ",
      };
    }

    // Fast path: Ultra-fast Thai regex parser for instantaneous response (0ms)
    const fastParsed = this.fastParseThaiTask(trimmed, now);
    if (fastParsed) {
      return fastParsed;
    }

    // If Gemini API Key is not set, use heuristic fallback
    if (!this.apiKey) {
      return this.fallbackHeuristicParser(trimmed, now);
    }

    try {
      const systemPrompt = `You are an intelligent task parsing assistant for Nudge, a behavioral productivity app.
Analyze the user's Thai or English message and extract the user's intent and structured task details.
The current date and time is: ${now.toISOString()} (Timezone: Asia/Bangkok, UTC+7).

Rules:
1. If the user wants to add or create a task (e.g. "พรุ่งนี้ส่งงาน...", "มีสอบวันศุกร์...", "ช่วยเตือนทำการบ้าน..."), set intent to "CREATE_TASK".
   - Extract "title": clean task title.
   - Extract "deadline": compute full ISO-8601 string based on the current time and user's requested time (default to 23:59:59 if only date is specified).
   - Extract "importance": integer from 1 to 5 (default to 3 if unspecified; 5 if urgent/very important).
   - Extract "estimatedMinutes": estimated duration in minutes (default to 30 if unspecified).
2. If the user asks to see their tasks or check what to do, set intent to "VIEW_TASKS".
3. If the user asks for a recommendation or what to start now, set intent to "GET_RECOMMENDATION".
4. If it's a general greeting or unrelated query, set intent to "UNKNOWN" and provide a helpful, friendly replyMessage in Thai.`;

      const response = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/${this.model}:generateContent?key=${this.apiKey}`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
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
                    enum: ["CREATE_TASK", "VIEW_TASKS", "GET_RECOMMENDATION", "GET_ID", "HELP", "UNKNOWN"],
                  },
                  title: { type: "string" },
                  deadline: { type: "string" },
                  importance: { type: "integer" },
                  estimatedMinutes: { type: "integer" },
                  replyMessage: { type: "string" },
                },
                required: ["intent"],
              },
            },
          }),
        }
      );

      if (!response.ok) {
        console.error("Gemini API Error:", response.status, await response.text());
        return this.fallbackHeuristicParser(trimmed, now);
      }

      const data = (await response.json()) as any;
      const contentText = data?.candidates?.[0]?.content?.parts?.[0]?.text;
      if (!contentText) {
        return this.fallbackHeuristicParser(trimmed, now);
      }

      const parsed = JSON.parse(contentText) as TaskIntentResult;
      return parsed;
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

    const hasTaskKeyword =
      trimmed.includes("ส่ง") ||
      trimmed.includes("ทำ") ||
      trimmed.includes("สอบ") ||
      trimmed.includes("การบ้าน") ||
      trimmed.includes("โปรเจกต์") ||
      trimmed.includes("งาน") ||
      trimmed.includes("อ่านหนังสือ") ||
      trimmed.includes("นัด") ||
      trimmed.includes("ประชุม") ||
      trimmed.includes("เตือน");

    if (!hasTaskKeyword) {
      return null;
    }

    // 1. Extract Importance (1 to 5)
    let importance = 3;
    if (/5\s*ดาว|5\/5|สำคัญมาก|ด่วนที่สุด|ด่วนมาก|urgent/i.test(trimmed)) {
      importance = 5;
    } else if (/4\s*ดาว|4\/5|สำคัญ/i.test(trimmed)) {
      importance = 4;
    } else if (/1\s*ดาว|1\/5|ไม่ด่วน|ไม่สำคัญ/i.test(trimmed)) {
      importance = 1;
    } else if (/2\s*ดาว|2\/5/i.test(trimmed)) {
      importance = 2;
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
    } else if (trimmed.includes("พรุ่งนี้") || trimmed.includes("พรุ่งนี")) {
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
    const mongMatch = trimmed.match(/(\d{1,2})\s*โมง/);
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
      targetHour = h <= 5 ? h + 12 : h;
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
      .replace(/(\d+\s*ดาว|\d+\/5|สำคัญมาก|สำคัญ|ด่วนที่สุด|ด่วน|urgent)/g, "")
      .replace(/(\d+\s*(นาที|ชั่วโมง|ชม|min|mins|hr|hrs))/g, "")
      .trim();

    title = title
      .replace(/^(ช่วยเตือน|สร้างงาน|เพิ่มงาน)\s*/i, "")
      .replace(/^มีส่ง\s*/i, "ส่ง")
      .replace(/^ต้องส่ง\s*/i, "ส่ง")
      .replace(/^มี\s*/i, "")
      .replace(/^ต้อง\s*/i, "")
      .trim();

    if (!title || title.length < 2) {
      if (trimmed.includes("โปรเจกต์")) title = "ส่งมินิโปรเจกต์";
      else if (trimmed.includes("การบ้าน")) title = "ส่งการบ้าน";
      else if (trimmed.includes("สอบ")) title = "เตรียมตัวสอบ";
      else title = trimmed;
    }

    if (trimmed.includes("ส่ง") && !title.startsWith("ส่ง") && !title.startsWith("การบ้าน")) {
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
  private fallbackHeuristicParser(text: string, now: Date): TaskIntentResult {
    const fast = this.fastParseThaiTask(text, now);
    if (fast) return fast;

    return {
      intent: "UNKNOWN",
      replyMessage: `สวัสดีครับ! สามารถพิมพ์บอกงาน เช่น "พรุ่งนี้ส่งโปรเจกต์" หรือพิมพ์ "งานวันนี้" เพื่อดูงานได้เลยครับ 🌱`,
    };
  }
}

export const geminiService = new GeminiService();
