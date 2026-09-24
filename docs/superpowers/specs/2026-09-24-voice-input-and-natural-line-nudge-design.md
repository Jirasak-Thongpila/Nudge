# Design Specification: Voice Input & Natural Chat-First LINE Nudge System

**Date:** 2026-09-24  
**Status:** Approved  
**Author:** Pair Programming with Tle  
**Related Specs & ADRs:**  
- [Nudge_Project_Specification.md](../../../Nudge_Project_Specification.md)
- [CONTEXT.md](../../../CONTEXT.md)
- [ADR-0005: Action Nudge Delivery](../../adr/0005-action-nudge-delivery.md)

---

## 1. Overview & Problem Statement

Users of Nudge frequently communicate via LINE OA. For many users in Thailand:
1. **Typing on mobile is high friction**: Speaking a quick voice note (e.g., *"พรุ่งนี้ 4 โมงเย็นส่งโปรเจกต์คอม สำคัญมาก"*) is dramatically faster and easier than typing and setting dates manually.
2. **App download creates a high barrier to entry**: Many users prefer staying 100% inside LINE chat without downloading or opening a mobile application. The entire core loop (Task creation, Action Nudge, 10-minute focus session, completion) must be fully functional inside LINE.
3. **Repetitive robotic messages cause banner blindness**: Hardcoded nudge text (e.g., *"ลองเริ่ม 10 นาทีไหม?"*) becomes repetitive and easily ignored. The AI must sound like a warm, supportive accountability buddy (เพื่อนคู่คิด) who writes fresh, natural Thai messages that never shame or guilt the user.

---

## 2. Core Decisions & User Flows

### 2.1 Voice Input Processing Flow (LINE OA)
1. **Audio Webhook**: When a user sends a voice note in LINE OA, LINE sends an `audio` message event (`event.message.type === 'audio'`).
2. **Binary Download**: Backend downloads the `.m4a` audio stream from LINE Content API (`https://api-data.line.me/v2/bot/message/{messageId}/content`).
3. **Direct Multimodal AI**: Backend sends the audio buffer directly to Gemini Flash (`audio/m4a`), which transcribes the audio and extracts the structured intent in a single call.
4. **Confirmation Gate**:
   - If the intent is `CREATE_TASK`, the bot does **not** save immediately. Instead, it replies with a confirmation card:
     - The exact words heard (`transcription`)
     - Inferred task fields (`title`, `deadline`, `importance`, `estimatedMinutes`)
     - Quick reply buttons: `[ ยืนยันบันทึกงาน ]` and `[ ยกเลิก ]`
   - If the user confirms, the task is saved to PostgreSQL and an acknowledgement is sent.
   - If the intent is `VIEW_TASKS`, `COMPLETE_TASK`, `GET_RECOMMENDATION`, or conversational, it executes immediately just like text messages.

### 2.2 Sensible Defaults for Unspecified Fields
Spoken requests often omit details (e.g., *"พรุ่งนี้ส่งรายงานภาษาอังกฤษ"*):
- **Importance**: Defaults to `3/5 (ปกติ)`. If words like "ด่วน", "สำคัญมาก" are present, set to `4` or `5`.
- **Estimated Minutes**: Defaults to `30 นาที`.
- **Deadline**: If only the date is specified, defaults to `23:59` of that day.
- **Card Transparency**: The confirmation card explicitly marks these as `*(ค่าเริ่มต้น)*` so the user knows what was assumed.

### 2.3 Standalone In-Chat 10-Minute Focus Session
Users without the Flutter app can execute their focus session directly inside LINE:
1. **Action Nudge Card**: Contains `[ เริ่ม 10 นาทีเลย ]` and `[ เลื่อนไปก่อน ]`.
2. **In-Chat Timer Initiation**: When the user taps `[ เริ่ม 10 นาทีเลย ]`:
   - Bot responds: *"⏱️ เริ่มช่วงเวลาโฟกัส 10 นาทีสำหรับ: [ชื่องาน] วางมือถือแล้วลุยได้เลย! อีก 10 นาทีบอทจะกลับมาทักครับ 💪"*
   - Backend records the session start timestamp.
3. **10-Minute Follow-up**:
   - After 10 minutes, the bot automatically messages the user in LINE:
     *"🔔 ครบ 10 นาทีแล้วครับ! สำหรับงาน [ชื่องาน] รู้สึกเป็นยังไงบ้าง?"*
     With quick replies: `[ ทำงานนี้เสร็จแล้ว ]`, `[ ขอทำต่ออีกนิด ]`, `[ พักก่อนดีกว่า ]`.

### 2.4 Natural, Non-Repetitive AI Persona (Prompt Guidelines)
- **Persona**: Warm accountability buddy (เพื่อนคู่คิด).
- **Tone**: Conversational, polite (`ครับ`), encouraging, maximum 1–2 emojis.
- **Zero-Shaming & Anti-Guilt**: Never scold, pressure, guilt-trip, or ask why a task was postponed.
- **Contextual Nuances**:
  - Time of day: Morning (gentle kickstart), Afternoon (anti-slump focus), Evening (wrap-up before rest).
  - Postponement tiers: 0–1 postponements (gentle invitation), 2–3 postponements (break into a smaller micro-step), 4+ postponements (compassionate, zero pressure).
- **Fallback Pool**: 20+ pre-curated varied messages rotated without consecutive repetition if the Gemini API call fails.

---

## 3. Architecture & Service Layer

```text
 LINE OA (User speaks / taps)
          │
          ▼
   LINE Webhook Router (routes/line.ts)
          │
          ├── Audio Event ──► LineService.downloadAudioContent(messageId)
          │                          │ (Buffer)
          │                          ▼
          │                   GeminiService.parseTaskFromAudio(buffer, mimeType, now)
          │                          │
          │                          ▼
          │                   TaskIntentResult (Transcription + Task Data)
          │                          │
          │                   LineService.sendVoiceTaskConfirmation(...)
          │
          ├── Confirmation ─► TaskService.createTask(...)
          │
          └── Start 10 Min ─► FocusService / LineService.startChatFocusSession(...)
```

### 3.1 LineService Enhancements
- `downloadAudioContent(messageId: string): Promise<Buffer>`: Calls LINE content API with `Authorization: Bearer {channelAccessToken}`.
- `sendVoiceConfirmationCard(userId, replyToken, audioResult)`: Sends Flex card displaying transcribed speech and task preview with confirmation buttons.
- `handleChatFocusSession(userId, taskId)`: Handles in-chat focus timer and schedules a 10-minute check-in notification.

### 3.2 GeminiService Enhancements
- `parseTaskFromAudio(audioBuffer: Buffer, mimeType: string, now: Date): Promise<TaskIntentResult & { transcription?: string }>`:
  - Base64-encodes the audio buffer.
  - Sends multimodal request to Gemini 1.5/2.0 Flash with JSON schema.
- `generateDynamicNudge(task: Task, timeOfDay: string, postponeCount: number): Promise<string>`:
  - Generates a fresh 1-2 sentence Thai nudge message following persona and zero-shaming rules.

---

## 4. Error Handling & Safety

1. **Audio Download Failure**: If LINE content API fails (e.g. expired media or network issue), reply politely: *"ขออภัยครับ ไม่สามารถดาวน์โหลดไฟล์เสียงได้ กรุณาลองส่งใหม่อีกครั้งนะครับ"*
2. **Audio Too Long / Large**: Audio messages longer than 60 seconds or larger than 10MB receive a polite note asking for a shorter voice note.
3. **No Speech Detected / Inaudible**: If Gemini detects no intelligible speech, respond warmly: *"ฟังเสียงไม่ค่อยชัดเจนเลยครับ รบกวนพูดใหม่อีกครั้ง หรือพิมพ์บอกก็ได้นะครับ"*
4. **Fallback Mechanism**: If Gemini API is unreachable, fall back to the randomized rotation template pool for nudges, and prompt the user to type for task creation.

---

## 5. Verification & Testing Plan

1. **Unit Tests (`backend/tests/voice.test.ts`)**:
   - Verify audio content download handling with mocked LINE binary stream.
   - Verify multimodal Gemini parser output serialization (transcription + structured task).
   - Verify sensible defaults (missing importance = 3, missing minutes = 30, deadline = 23:59).
   - Verify confirmation flow (pending voice task -> confirmation message -> task created).
2. **Language & Persona Audit**:
   - Test generated dynamic nudges against banned words (`ขี้เกียจ`, `ทำไมยังไม่ทำ`, `เดี๋ยวไม่ทัน`).
   - Verify 0 shaming / guilt in all prompt output variations.
3. **In-Chat Timer Tests**:
   - Test start of 10-minute session from chat button without calling mobile deep links.
4. **Regression Testing**:
   - Run `bun test` (all existing 135 tests must continue to pass).
   - Run `tsc --noEmit` (0 TypeScript errors).
