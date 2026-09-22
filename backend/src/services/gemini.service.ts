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
    if (lower === "id" || lower === "uid" || lower === "userid") {
      return { intent: "GET_ID" };
    }
    if (lower === "งาน" || lower === "งานวันนี้" || lower === "tasks" || lower === "list") {
      return { intent: "VIEW_TASKS" };
    }
    if (lower === "แนะนำ" || lower === "nudge" || lower === "focus" || lower === "เริ่ม") {
      return { intent: "GET_RECOMMENDATION" };
    }
    if (lower === "help" || lower === "ช่วยเหลือ" || lower === "วิธีใช้") {
      return {
        intent: "HELP",
        replyMessage:
          "🌱 Nudge Assistant พร้อมช่วยคุณเริ่มต้นงานสำคัญ:\n\n" +
          "• พิมพ์บอกงาน เช่น 'พรุ่งนี้ 9 โมงส่งมินิโปรเจกต์ สำคัญมาก'\n" +
          "• พิมพ์ 'งานวันนี้' เพื่อดูรายการงานทั้งหมด\n" +
          "• พิมพ์ 'แนะนำ' เพื่อดูงานที่ควรเริ่มทำ 10 นาทีแรก\n" +
          "• พิมพ์ 'id' เพื่อดู LINE User ID ของคุณ",
      };
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
   * Fallback rule-based parser when Gemini API is unavailable.
   */
  private fallbackHeuristicParser(text: string, now: Date): TaskIntentResult {
    // Basic detection for task creation pattern
    const isCreate =
      text.includes("งาน") ||
      text.includes("ส่ง") ||
      text.includes("ทำ") ||
      text.includes("สอบ") ||
      text.includes("การบ้าน") ||
      text.includes("โปรเจกต์");

    if (isCreate) {
      // Default to tomorrow 23:59:59
      const tomorrow = new Date(now.getTime() + 24 * 60 * 60 * 1000);
      tomorrow.setHours(23, 59, 59, 0);

      let importance = 3;
      if (text.includes("ด่วน") || text.includes("สำคัญมาก") || text.includes("5")) {
        importance = 5;
      } else if (text.includes("สำคัญ") || text.includes("4")) {
        importance = 4;
      }

      return {
        intent: "CREATE_TASK",
        title: text.replace(/^(เพิ่มงาน|ช่วยเตือน|สร้างงาน)\s*/i, "").trim() || "งานใหม่",
        deadline: tomorrow.toISOString(),
        importance,
        estimatedMinutes: 30,
      };
    }

    return {
      intent: "UNKNOWN",
      replyMessage: `สวัสดีครับ! สามารถพิมพ์บอกงาน เช่น "พรุ่งนี้ส่งโปรเจกต์" หรือพิมพ์ "งานวันนี้" เพื่อดูงานได้เลยครับ 🌱`,
    };
  }
}

export const geminiService = new GeminiService();
