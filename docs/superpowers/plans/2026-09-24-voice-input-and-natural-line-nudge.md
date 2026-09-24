# Voice Input & Natural Chat-First LINE Nudge Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable users to create tasks via LINE voice messages with direct Gemini multimodal audio transcription & confirmation, interact with 10-minute focus sessions directly inside LINE chat without opening the mobile app, and receive dynamic, non-repetitive, zero-shaming Action Nudges.

**Architecture:** Extend `LineService` to download `.m4a` audio binaries and handle in-chat focus sessions. Extend `GeminiService` with direct audio multimodal comprehension (`parseTaskFromAudio`) and dynamic Thai nudge copy generation (`generateDynamicNudge`). Connect with `TaskService` and `NudgeService` with sensible defaults and zero-shaming guardrails.

**Tech Stack:** Bun, Elysia, TypeScript, Gemini 1.5/2.0 Flash (Multimodal Audio & Structured Output), LINE Messaging API, PostgreSQL, Drizzle ORM.

## Global Constraints

- **Language & Persona:** Natural conversational Thai, polite (`ครับ`), buddy persona (เพื่อนคู่คิด).
- **Zero-Shaming:** Zero words of guilt, scolding, or blaming (`ขี้เกียจ`, `ทำไมยังไม่ทำ`, `เดี๋ยวไม่ทัน`).
- **Sensible Defaults:** Missing importance defaults to 3; missing estimated minutes defaults to 30; missing deadline time defaults to 23:59.
- **Pure Chat Usability:** All flows (voice task creation, action nudging, 10-minute focus session, completion) must work standalone in LINE chat without requiring mobile app installation.

---

### Task 1: Gemini Service Multimodal Audio Task Parsing (`parseTaskFromAudio`)

**Files:**
- Modify: `backend/src/services/gemini.service.ts`
- Test: `backend/tests/voice_parsing.test.ts`

**Interfaces:**
- Consumes: Audio `Buffer`, `mimeType: string`, `now: Date`.
- Produces:
  ```typescript
  export interface AudioTaskIntentResult extends TaskIntentResult {
    transcription?: string;
  }
  ```
  `geminiService.parseTaskFromAudio(audioBuffer: Buffer, mimeType: string, now?: Date): Promise<AudioTaskIntentResult>`

- [ ] **Step 1: Write the failing test for `parseTaskFromAudio`**

Create `backend/tests/voice_parsing.test.ts`:
```typescript
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
    globalThis.fetch = mock(async (url: string | URL | Request) => {
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
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bun test tests/voice_parsing.test.ts`  
Expected: FAIL (`parseTaskFromAudio is not a function`).

- [ ] **Step 3: Implement `parseTaskFromAudio` in `backend/src/services/gemini.service.ts`**

Add `AudioTaskIntentResult` interface and method:
```typescript
export interface AudioTaskIntentResult extends TaskIntentResult {
  transcription?: string;
}

// Inside GeminiService class:
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
  const systemPrompt = `You are an intelligent multimodal voice assistant for Nudge, a behavioral productivity app.
Listen carefully to the user's spoken audio (primarily in Thai or English).
First, accurately transcribe what the user said in "transcription".
Second, analyze their intent and extract structured task details if they are asking to add or track a task.
The current date and time is: ${now.toISOString()} (Timezone: Asia/Bangkok, UTC+7).

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
7. If casual talk or unclear audio, set intent to "UNKNOWN" with an empathetic Thai "replyMessage".`;

  try {
    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${this.model}:generateContent?key=${this.apiKey}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
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
      }
    );

    if (!response.ok) {
      console.error(`Gemini audio API error: ${response.status} ${await response.text()}`);
      return {
        intent: "UNKNOWN",
        replyMessage: "ขออภัยครับ เกิดข้อผิดพลาดในการประมวลผลเสียง กรุณาลองใหม่อีกครั้งนะครับ",
      };
    }

    const data = await response.json();
    const contentText = data.candidates?.[0]?.content?.parts?.[0]?.text;
    if (!contentText) {
      return {
        intent: "UNKNOWN",
        replyMessage: "ฟังเสียงไม่ค่อยชัดเจนเลยครับ รบกวนลองส่งใหม่อีกครั้งนะครับ",
      };
    }

    const parsed = JSON.parse(contentText) as AudioTaskIntentResult;
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bun test tests/voice_parsing.test.ts`  
Expected: PASS (2 tests pass).

- [ ] **Step 5: Commit**

```bash
git add backend/src/services/gemini.service.ts backend/tests/voice_parsing.test.ts
git commit -m "feat(backend): add parseTaskFromAudio with Gemini multimodal in GeminiService"
```

---

### Task 2: Dynamic Non-Repetitive AI Persona & Nudge Copy (`generateDynamicNudge`)

**Files:**
- Modify: `backend/src/services/gemini.service.ts`
- Modify: `backend/src/lib/nudge.ts`
- Test: `backend/tests/dynamic_nudge.test.ts`

**Interfaces:**
- Consumes: `task: Pick<Task, "title" | "postponeCount" | "deadline" | "importance">`, `timeOfDay: "morning" | "afternoon" | "evening"`.
- Produces: `geminiService.generateDynamicNudge(task, timeOfDay): Promise<string>`.
- Fallback: `getRandomRotatedNudge(taskTitle: string, postponeCount: number, timeOfDay: string): string`.

- [ ] **Step 1: Write the failing test for dynamic nudge generation and zero-shaming audit**

Create `backend/tests/dynamic_nudge.test.ts`:
```typescript
import { describe, expect, it, mock } from "bun:test";
import { GeminiService } from "../src/services/gemini.service";
import { getRandomRotatedNudge } from "../src/lib/nudge";

describe("Dynamic Nudge Copy & Persona Audit", () => {
  it("should generate contextual dynamic Thai copy from Gemini", async () => {
    const service = new GeminiService();
    (service as any).apiKey = "test-api-key";

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
                      nudgeMessage: "บ่ายนี้ลองเปิดสไลด์สัมมนามาดูหัวข้อสัก 10 นาทีไหมครับ สบายๆ เริ่มก้าวแรกกันนะ",
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
      const message = await service.generateDynamicNudge(
        { title: "สไลด์สัมมนา", postponeCount: 2, deadline: new Date(), importance: 4 },
        "afternoon"
      );
      expect(message).toContain("สไลด์สัมมนา");
      expect(message).toContain("10 นาที");
      // Zero-shaming audit
      expect(message).not.toMatch(/ขี้เกียจ|ทำไมยังไม่ทำ|เดี๋ยวไม่ทัน|แย่/);
    } finally {
      globalThis.fetch = originalFetch;
    }
  });

  it("should rotate varied fallback messages without shame terms when API is offline", () => {
    const forbiddenWords = ["ขี้เกียจ", "ทำไมยังไม่ทำ", "เดี๋ยวไม่ทัน", "แย่"];
    for (let i = 0; i < 20; i++) {
      const msg = getRandomRotatedNudge("มินิโปรเจกต์", i % 5, "morning");
      expect(msg).toContain("มินิโปรเจกต์");
      for (const forbidden of forbiddenWords) {
        expect(msg.includes(forbidden)).toBe(false);
      }
    }
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bun test tests/dynamic_nudge.test.ts`  
Expected: FAIL (`generateDynamicNudge` or `getRandomRotatedNudge` not defined).

- [ ] **Step 3: Implement `generateDynamicNudge` in `gemini.service.ts` and fallback pool in `lib/nudge.ts`**

In `backend/src/lib/nudge.ts`, add varied fallback pool:
```typescript
export const FALLBACK_NUDGE_TEMPLATES = [
  (title: string) => `เช้านี้ลองเปิดดู ${title} สัก 10 นาทีไหมครับ สบายๆ เริ่มก้าวแรกกันนะ`,
  (title: string) => `บ่ายนี้แวบมาเริ่ม ${title} สักยก 10 นาทีดีไหมครับ เผื่อสมองแล่นลุยต่อได้`,
  (title: string) => `ก่อนพักผ่อนเย็นนี้ มาลองเคาะ ${title} ก้าวแรก 10 นาที จะได้สบายใจขึ้นครับ`,
  (title: string) => `งาน ${title} ก้อนนี้อาจจะดูเยอะ ลองวางโครงสั้นๆ 10 นาทีพอนะครับ`,
  (title: string) => `ไม่ต้องกดดันตัวเองเรื่องที่ผ่านมาครับ แค่เริ่มใหม่กับ ${title} ตอนนี้สัก 10 นาที ลุยไปด้วยกันนะ`,
  (title: string) => `แค่เปิดไฟล์ ${title} ทิ้งไว้สัก 10 นาทีก็ถือว่าได้เริ่มแล้วครับ สู้ๆ นะ`,
];

let lastFallbackIndex = -1;
export function getRandomRotatedNudge(title: string, postponeCount: number, timeOfDay: string): string {
  let nextIndex = (lastFallbackIndex + 1) % FALLBACK_NUDGE_TEMPLATES.length;
  lastFallbackIndex = nextIndex;
  return FALLBACK_NUDGE_TEMPLATES[nextIndex](title);
}
```

In `backend/src/services/gemini.service.ts`, add `generateDynamicNudge`:
```typescript
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
    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${this.model}:generateContent?key=${this.apiKey}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [{ role: "user", parts: [{ text: prompt }] }],
          generationConfig: {
            responseMimeType: "application/json",
            responseSchema: {
              type: "object",
              properties: { nudgeMessage: { type: "string" } },
              required: ["nudgeMessage"],
            },
          },
        }),
      }
    );

    if (response.ok) {
      const data = await response.json();
      const text = data.candidates?.[0]?.content?.parts?.[0]?.text;
      if (text) {
        const parsed = JSON.parse(text);
        if (parsed.nudgeMessage) return parsed.nudgeMessage;
      }
    }
  } catch (err) {
    console.error("Gemini dynamic nudge generation error:", err);
  }

  return getRandomRotatedNudge(task.title, task.postponeCount, timeOfDay);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bun test tests/dynamic_nudge.test.ts`  
Expected: PASS (2 tests pass).

- [ ] **Step 5: Commit**

```bash
git add backend/src/services/gemini.service.ts backend/src/lib/nudge.ts backend/tests/dynamic_nudge.test.ts
git commit -m "feat(backend): implement generateDynamicNudge with persona guidelines and fallback pool"
```

---

### Task 3: LINE Audio Download & Voice Confirmation Flow in `LineService`

**Files:**
- Modify: `backend/src/services/line.service.ts`
- Modify: `backend/src/routes/line.ts`
- Test: `backend/tests/line_voice.test.ts`

**Interfaces:**
- Consumes: Audio message event from LINE webhook.
- Produces:
  `lineService.downloadAudioContent(messageId: string): Promise<Buffer>`
  `lineService.sendVoiceConfirmationCard(replyToken: string, audioResult: AudioTaskIntentResult): Promise<void>`
  Support confirmation message `ยืนยันบันทึกงาน <title> ...` to create task.

- [ ] **Step 1: Write the failing test for LINE Audio Webhook & Confirmation Flow**

Create `backend/tests/line_voice.test.ts`:
```typescript
import { describe, expect, it, mock } from "bun:test";
import { LineService } from "../src/services/line.service";
import { GeminiService } from "../src/services/gemini.service";
import { TaskService } from "../src/services/task.service";

describe("LINE Voice Message & Confirmation Flow", () => {
  it("should handle audio message event, call downloadAudioContent, and reply with confirmation card", async () => {
    const lineService = new LineService();
    (lineService as any).channelAccessToken = "test-token";

    // Mock downloadAudioContent
    const mockAudioBuffer = Buffer.from("audio-bytes");
    lineService.downloadAudioContent = mock(async () => mockAudioBuffer);

    // Mock Gemini parseTaskFromAudio
    lineService.geminiService.parseTaskFromAudio = mock(async () => ({
      intent: "CREATE_TASK",
      transcription: "พรุ่งนี้ส่งการบ้านคณิต",
      title: "ส่งการบ้านคณิต",
      deadline: "2026-09-25T23:59:59.000Z",
      importance: 3,
      estimatedMinutes: 30,
    }));

    // Mock replyToUser
    let sentMessages: any[] = [];
    lineService.replyToUser = mock(async (token: string, msgs: any[]) => {
      sentMessages = msgs;
    });

    await lineService.handleAudioMessage({
      replyToken: "reply-token-123",
      messageId: "msg-456",
      userId: 1,
      lineUserId: "U12345",
    });

    expect(lineService.downloadAudioContent).toHaveBeenCalledWith("msg-456");
    expect(sentMessages.length).toBeGreaterThan(0);
    expect(sentMessages[0].type).toBe("flex");
    expect(JSON.stringify(sentMessages[0])).toContain("ส่งการบ้านคณิต");
    expect(JSON.stringify(sentMessages[0])).toContain("พรุ่งนี้ส่งการบ้านคณิต");
  });

  it("should confirm and create task when user taps confirmation action", async () => {
    const lineService = new LineService();
    lineService.taskService.createTask = mock(async (userId, data) => ({
      id: 99,
      userId,
      ...data,
      status: "NOT_STARTED",
      postponeCount: 0,
      createdAt: new Date(),
      deletedAt: null,
      lastNudgedAt: null,
      nudgeCount: 0,
    })) as any;

    let sentReply = "";
    lineService.replyToUser = mock(async (token, msgs: any[]) => {
      sentReply = JSON.stringify(msgs);
    });

    await lineService.handleConfirmedVoiceTask({
      replyToken: "token-99",
      userId: 1,
      title: "ส่งการบ้านคณิต",
      deadline: "2026-09-25T23:59:59.000Z",
      importance: 3,
      estimatedMinutes: 30,
    });

    expect(lineService.taskService.createTask).toHaveBeenCalled();
    expect(sentReply).toContain("บันทึกงานเรียบร้อยแล้ว");
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bun test tests/line_voice.test.ts`  
Expected: FAIL (`downloadAudioContent` or `handleAudioMessage` not defined).

- [ ] **Step 3: Implement LINE Audio download and confirmation card in `LineService`**

In `backend/src/services/line.service.ts`:
1. Add `downloadAudioContent(messageId: string): Promise<Buffer>`:
```typescript
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
```

2. Add `handleAudioMessage` and `sendVoiceConfirmationCard`:
```typescript
async handleAudioMessage({
  replyToken,
  messageId,
  userId,
  lineUserId,
}: {
  replyToken: string;
  messageId: string;
  userId: number;
  lineUserId: string;
}): Promise<void> {
  try {
    const audioBuffer = await this.downloadAudioContent(messageId);
    const result = await this.geminiService.parseTaskFromAudio(audioBuffer, "audio/m4a");

    if (result.intent === "CREATE_TASK" && result.title) {
      await this.sendVoiceConfirmationCard(replyToken, result);
      return;
    }

    if (result.intent === "VIEW_TASKS") {
      const tasks = await this.taskService.getTasksForUser(userId);
      await this.replyWithTaskList(replyToken, tasks);
      return;
    }

    if (result.intent === "GET_RECOMMENDATION") {
      const rec = await this.taskService.getRecommendedTask(userId);
      await this.replyWithRecommendation(replyToken, rec);
      return;
    }

    // Default friendly response
    await this.replyToUser(replyToken, [
      {
        type: "text",
        text: result.replyMessage || `🎙️ ได้ยินว่า: "${result.transcription || ""}"`,
      },
    ]);
  } catch (error) {
    console.error("Error processing LINE audio message:", error);
    await this.replyToUser(replyToken, [
      {
        type: "text",
        text: "ขออภัยครับ ไม่สามารถประมวลผลไฟล์เสียงได้ในขณะนี้ กรุณาลองใหม่อีกครั้งนะครับ",
      },
    ]);
  }
}
```

3. Construct the Flex confirmation card with quick reply actions `ยืนยันบันทึกงาน` and `ยกเลิก`.
4. Update `routes/line.ts` webhook event dispatcher: if `event.message.type === 'audio'`, invoke `lineService.handleAudioMessage`.

- [ ] **Step 4: Run test to verify it passes**

Run: `bun test tests/line_voice.test.ts`  
Expected: PASS (2 tests pass).

- [ ] **Step 5: Commit**

```bash
git add backend/src/services/line.service.ts backend/src/routes/line.ts backend/tests/line_voice.test.ts
git commit -m "feat(backend): add LINE audio download and voice task confirmation card flow"
```

---

### Task 4: In-Chat 10-Minute Focus Session & Auto Check-in

**Files:**
- Modify: `backend/src/services/line.service.ts`
- Modify: `backend/src/routes/line.ts`
- Test: `backend/tests/chat_focus.test.ts`

**Interfaces:**
- Consumes: Action button `[ เริ่ม 10 นาทีเลย ]` or message `เริ่ม 10 นาที` from user.
- Produces:
  `lineService.startChatFocusSession(userId: number, taskId: number, replyToken: string): Promise<void>`
  `lineService.sendFocusSessionCheckIn(userId: number, taskId: number): Promise<void>`

- [ ] **Step 1: Write the failing test for In-Chat Focus Session**

Create `backend/tests/chat_focus.test.ts`:
```typescript
import { describe, expect, it, mock } from "bun:test";
import { LineService } from "../src/services/line.service";

describe("In-Chat 10-Minute Focus Session", () => {
  it("should start in-chat focus session and acknowledge in LINE without requiring app deep link", async () => {
    const lineService = new LineService();
    lineService.taskService.getTaskById = mock(async () => ({
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

    let replies: any[] = [];
    lineService.replyToUser = mock(async (token, msgs: any[]) => {
      replies = msgs;
    });

    await lineService.startChatFocusSession(1, 10, "reply-token-focus");

    expect(replies.length).toBeGreaterThan(0);
    expect(replies[0].text).toContain("ทำสรุปรายงาน");
    expect(replies[0].text).toContain("10 นาที");
    expect(replies[0].text).toContain("วางมือถือ");
  });

  it("should send completion check-in message with quick replies after focus period", async () => {
    const lineService = new LineService();
    lineService.taskService.getTaskById = mock(async () => ({
      id: 10,
      title: "ทำสรุปรายงาน",
      userId: 1,
    })) as any;

    let sentPush: any = null;
    lineService.pushMessage = mock(async (lineUserId, msgs) => {
      sentPush = msgs;
    });

    await lineService.sendFocusSessionCheckIn("U123456", 10);

    expect(sentPush).not.toBeNull();
    const pushStr = JSON.stringify(sentPush);
    expect(pushStr).toContain("ครบ 10 นาทีแล้ว");
    expect(pushStr).toContain("ทำงานนี้เสร็จแล้ว");
    expect(pushStr).toContain("ขอทำต่ออีกนิด");
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bun test tests/chat_focus.test.ts`  
Expected: FAIL (`startChatFocusSession` not defined).

- [ ] **Step 3: Implement In-Chat Focus Session and Check-in in `LineService`**

Implement `startChatFocusSession` and `sendFocusSessionCheckIn`:
```typescript
async startChatFocusSession(userId: number, taskId: number, replyToken: string): Promise<void> {
  const task = await this.taskService.getTaskById(userId, taskId);
  if (!task) {
    await this.replyToUser(replyToken, [{ type: "text", text: "ไม่พบงานที่ต้องการเริ่มโฟกัสครับ" }]);
    return;
  }

  // Update status to IN_PROGRESS
  await this.taskService.updateTask(userId, taskId, { status: "IN_PROGRESS" });

  await this.replyToUser(replyToken, [
    {
      type: "text",
      text: `⏱️ เริ่มช่วงเวลาโฟกัส 10 นาทีสำหรับ:\n📌 "${task.title}"\n\nวางมือถือแล้วเริ่มก้าวแรกสั้นๆ ได้เลยครับ! อีก 10 นาทีบอทจะกลับมาทักถามนะ สู้ๆ ครับ 💪`,
    },
  ]);
}

async sendFocusSessionCheckIn(lineUserId: string, taskId: number): Promise<void> {
  await this.pushMessage(lineUserId, [
    {
      type: "text",
      text: `🔔 ครบ 10 นาทีแล้วครับ! รู้สึกเป็นยังไงบ้าง? ยอดเยี่ยมมากที่เริ่มก้าวแรกได้สำเร็จ 🎉`,
      quickReply: {
        items: [
          {
            type: "action",
            action: {
              type: "message",
              label: "✅ ทำงานนี้เสร็จแล้ว",
              text: `ทำงานเสร็จแล้ว #${taskId}`,
            },
          },
          {
            type: "action",
            action: {
              type: "message",
              label: "💪 ขอทำต่ออีกนิด",
              text: `ขอทำต่อ #${taskId}`,
            },
          },
          {
            type: "action",
            action: {
              type: "message",
              label: "☕ พักก่อนดีกว่า",
              text: "พักก่อนดีกว่า",
            },
          },
        ],
      },
    },
  ]);
}
```

Update Action Nudge Flex template:
Add action button:
- `label: "เริ่ม 10 นาทีเลย"`
- `data: action=start_focus&taskId=${task.id}` or message `เริ่ม 10 นาที #${task.id}`.

- [ ] **Step 4: Run test to verify it passes**

Run: `bun test tests/chat_focus.test.ts`  
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add backend/src/services/line.service.ts backend/src/routes/line.ts backend/tests/chat_focus.test.ts
git commit -m "feat(backend): implement standalone in-chat 10-minute focus session and auto check-in"
```

---

### Task 5: End-to-End Regression & Verification

**Files:**
- Test: All tests in `backend/tests/`

- [ ] **Step 1: Run full backend test suite**

Run: `bun test`  
Expected: All tests pass (>140 tests pass, 0 fail).

- [ ] **Step 2: Run backend TypeScript typecheck**

Run: `bun run typecheck`  
Expected: `tsc --noEmit` exits 0 with 0 errors.

- [ ] **Step 3: Run frontend tests for peace of mind**

Run: `flutter test` in `frontend`  
Expected: 16/16 tests pass.

- [ ] **Step 4: Final commit and verification summary**

```bash
git status
```
Working tree clean, all commits in order.
