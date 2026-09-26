# 🎯 Nudge

> **"A task-management and behavioral productivity system that doesn't just tell you what to do — it helps you start."**  
> *"ระบบจัดการงานและผลิตภาพเชิงพฤติกรรม ที่ไม่ได้แค่บอกว่าควรทำอะไร แต่ช่วยตรวจจับว่าเรากำลังเลี่ยงงานไหน และช่วยให้เราเริ่มลงมือทำ"*

---

[![Backend Tests](https://img.shields.io/badge/Bun_Tests-16_Passing-success?style=flat-square&logo=bun)](./backend/tests)
[![Flutter](https://img.shields.io/badge/Frontend-Flutter_3.x-02569B?style=flat-square&logo=flutter)](./frontend)
[![Backend Framework](https://img.shields.io/badge/API-Elysia.js-FF5C00?style=flat-square&logo=elysia)](./backend)
[![Database](https://img.shields.io/badge/Database-PostgreSQL_|_Neon-4169E1?style=flat-square&logo=postgresql)](./backend/src/db)
[![ORM](https://img.shields.io/badge/ORM-Drizzle_ORM-C5F74F?style=flat-square&logo=drizzle)](https://orm.drizzle.team)
[![AI Engine](https://img.shields.io/badge/AI-Google_Gemini-4285F4?style=flat-square&logo=google)](https://ai.google.dev)
[![LINE Integration](https://img.shields.io/badge/LINE-Messaging_API_+_LIFF-00B900?style=flat-square&logo=line)](https://developers.line.biz)

---

## 📖 สารบัญ (Table of Contents)

- [💡 ที่มาและแนวคิดของ Nudge (The Problem & Philosophy)](#-ที่มาและแนวคิดของ-nudge-the-problem--philosophy)
- [✨ ฟีเจอร์หลัก (Core Features)](#-ฟีเจอร์หลัก-core-features)
- [🏗️ สถาปัตยกรรมระบบ (System Architecture)](#️-สถาปัตยกรรมระบบ-system-architecture)
- [🛠️ เทคโนโลยีที่ใช้ (Tech Stack)](#️-เทคโนโลยีที่ใช้-tech-stack)
- [📂 โครงสร้างโปรเจกต์ (Project Structure)](#-โครงสร้างโปรเจกต์-project-structure)
- [🚀 การเริ่มต้นใช้งานในเครื่อง (Getting Started)](#-การเริ่มต้นใช้งานในเครื่อง-getting-started)
  - [ความต้องการพื้นฐาน (Prerequisites)](#ความต้องการพื้นฐาน-prerequisites)
  - [1. Backend & Database Setup](#1-backend--database-setup)
  - [2. Frontend Setup (Flutter)](#2-frontend-setup-flutter)
  - [3. รันผ่าน Docker Compose](#3-รันผ่าน-docker-compose)
- [🔐 ค่าคอนฟิกูเรชัน (Environment Variables)](#-ค่าคอนฟิกูเรชัน-environment-variables)
- [🧪 การทดสอบ (Testing)](#-การทดสอบ-testing)
- [📚 เอกสารสถาปัตยกรรมและคู่มือการ Deploy (Documentation & ADRs)](#-เอกสารสถาปัตยกรรมและคู่มือการ-deploy-documentation--adrs)
- [🗣️ คำศัพท์เฉพาะในระบบ (Domain Language & Glossary)](#️-คำศัพท์เฉพาะในระบบ-domain-language--glossary)
- [👥 ทีมผู้จัดทำ (Contributors)](#-ทีมผู้จัดทำ)

---

## 💡 ที่มาและแนวคิดของ Nudge (The Problem & Philosophy)

แอปพลิเคชัน To-Do List ทั่วไปมักจัดการเฉพาะ **"การจัดลำดับความสำคัญ (Prioritization)"** แต่ปัญหาที่แท้จริงของคนส่วนใหญ่ไม่ใช่ *ไม่รู้ว่าต้องทำอะไรก่อน* แต่คือ:

> **"เรารู้ดีว่างานไหนสำคัญ แต่เรามักเลือกทำงานง่ายๆ ก่อน แล้วผัดวันประกันพรุ่งงานยากๆ ไปเรื่อยๆ จนถึงเดดไลน์"**

**Nudge** เข้ามาแก้ปัญหานี้ด้วยมุมมองทางจิตวิทยาและพฤติกรรมศาสตร์:
1. **ลดแรงเสียดทาน (Low-friction start):** แทนที่จะบังคับให้ทำงานชิ้นใหญ่ให้เสร็จ ระบบจะแนะนำ "ก้าวแรกที่เล็กและทำได้ง่ายที่สุด"
2. **ไม่ตัดสินหรือตีตรา (Empathetic & Non-judgmental):** ระบบจะใช้คำว่า **"อาจกำลังหลีกเลี่ยง (Potentially Avoided)"** โดยวิเคราะห์จากพฤติกรรมจริง (เช่น การกดเลื่อนงานอย่างตั้งใจ) และไม่เคยตีตราผู้ใช้ว่า "ขี้เกียจ"
3. **คำนวณแบบ Real-time:** ระยะเวลาคงเหลือ (Days Remaining), คะแนนความเร่งด่วน (Priority Score) และคะแนนการหลีกเลี่ยง (Avoidance Score) จะคำนวณแบบพลวัต ไม่เก็บค่าตายตัวลงฐานข้อมูล

---

## ✨ ฟีเจอร์หลัก (Core Features)

### 1. 🎯 Dynamic Priority & Deadline Awareness
- แสดง **Days Remaining** นับถอยหลังสู่ Deadline ตามเวลาจริง
- อัลกอริทึมคำนวณ **Priority Score** ผสมผสานระหว่างความสำคัญ (Importance), ความเร่งด่วน (Urgency) และประวัติการเลื่อนงาน

### 2. 🧠 Avoidance Detection & Action Nudge
- ตรวจจับพฤติกรรม **Explicit Postpone** (การกดเลื่อนวันกำหนดส่งอย่างตั้งใจ)
- เมื่อตรวจพบว่างานสำคัญเข้าข่าย **Potentially Avoided** ระบบจะส่ง **Action Nudge** เสนอให้เริ่มทำเพียงก้าวสั้นๆ เช่น เปิดอ่านไฟล์ 1 หน้า หรือเขียนโค้ด 5 บรรทัด

### 3. ⏱️ Micro-Action Focus Session
- ฟีเจอร์จับเวลาโฟกัสเริ่มต้นที่ **10 นาที** (Focus Session) เพื่อทำลายกำแพงความกังวล (Psychological Barrier)
- เมื่อจบ 10 นาที ผู้ใช้สามารถเลือกต่อเวลา หรือบันทึกความคืบหน้าได้ทันที

### 4. 🤖 AI Natural Language & Voice Task Parser (Google Gemini)
- เพิ่มงานง่ายๆ เพียงพิมพ์หรือส่งเสียง เช่น *"ส่งโปรเจกต์โมบายล์วันพฤหัสบดีหน้าตอน 5 โมงเย็น สำคัญมาก ใช้เวลา 3 ชั่วโมง"*
- Gemini AI จะแยกข้อมูล Title, Deadline, Importance (LOW/MEDIUM/HIGH/URGENT) และ Estimated Duration ให้อัตโนมัติ

### 5. 📲 LINE Official Account & LIFF Integration
- เชื่อมต่อกับ LINE ผ่าน **LINE Messaging API** ส่งแจ้งเตือน Action Nudge ถึงแชตส่วนตัว
- เปิดแอปผ่าน **LINE Front-end Framework (LIFF)** ล็อกอินแบบ Seamless และกดเริ่ม Focus Session ผ่าน Deep Link ได้ทันทีในแอป LINE

### 6. 📊 Overview Dashboard
- หน้าสรุปภาพรวมงานที่ต้องทำ, งานที่เสร็จแล้ว, เวลาโฟกัสสะสม และรายการงานที่ระบบตรวจพบว่า *"อาจต้องการความช่วยเหลือในการเริ่มต้น"*

---

## 🏗️ สถาปัตยกรรมระบบ (System Architecture)

```mermaid
flowchart TB
    subgraph Clients["Clients"]
        Mobile["📱 Flutter Mobile App (Android / iOS)"]
        WebLIFF["🌐 Flutter Web / LINE LIFF (In-Chat)"]
        LineChat["💬 LINE Official Account (Chatbot)"]
    end

    subgraph Gateway["Backend (Bun + Elysia.js)"]
        Router["Elysia Router / CORS"]
        subgraph Services["Core Services"]
            TaskSvc["Task & Priority Engine"]
            AvoidSvc["Avoidance Detection & Nudge"]
            FocusSvc["Focus Session Manager"]
            LineSvc["LINE Webhook & Push Service"]
            GeminiSvc["Gemini AI Natural Language Parser"]
        end
    end

    subgraph External["External Services"]
        GeminiAPI["Google Gemini API (Flash 1.5/2.0)"]
        LineAPI["LINE Messaging API"]
        NeonDB[("🐘 PostgreSQL / Neon Database")]
    end

    subgraph Cron["Automation"]
        Scheduler["⏱️ Nudge Dispatcher (Cron / Worker)"]
    end

    Mobile -->|REST API / Device-UUID| Router
    WebLIFF -->|REST API / LINE User ID| Router
    LineChat -->|Webhook Events| Router

    Scheduler -->|POST /nudges/dispatch| Router

    Router --> TaskSvc
    Router --> AvoidSvc
    Router --> FocusSvc
    Router --> LineSvc
    Router --> GeminiSvc

    GeminiSvc --> GeminiAPI
    LineSvc --> LineAPI
    TaskSvc --> NeonDB
    AvoidSvc --> NeonDB
    FocusSvc --> NeonDB
```

---

## 🛠️ เทคโนโลยีที่ใช้ (Tech Stack)

### **Backend**
- **Runtime:** [Bun](https://bun.sh/) (Fast all-in-one JavaScript/TypeScript runtime)
- **Framework:** [Elysia.js](https://elysiajs.com/) (High-performance web framework for Bun)
- **Database & ORM:** [PostgreSQL 16](https://www.postgresql.org/) / [Neon Serverless](https://neon.tech/) พร้อม [Drizzle ORM](https://orm.drizzle.team/)
- **AI / LLM:** [Google Gemini API](https://ai.google.dev/) (`@google/genai` & REST)
- **Testing:** Bun Test Runner (16 Comprehensive Unit & Integration Suites)

### **Frontend**
- **Framework:** [Flutter](https://flutter.dev/) (SDK `>=3.0.0 <4.0.0`)
- **Language:** Dart
- **Design System:** Material 3 with Custom Color Palette (Focus on empathy and readability)
- **State & Storage:** `shared_preferences`, UUID Device Auth
- **LINE Integration:** `flutter_line_liff` (LIFF v2 SDK)

### **Infrastructure & DevOps**
- **Containerization:** Docker & Docker Compose
- **Serverless & Hosting:** Vercel (Backend Serverless + Frontend Web), Render Ready

---

## 📂 โครงสร้างโปรเจกต์ (Project Structure)

```text
Nudge/
├── backend/                       # Backend API (Bun + Elysia.js)
│   ├── api/                       # Production bundle output
│   ├── drizzle/                   # Database migrations generated by drizzle-kit
│   ├── src/
│   │   ├── db/                    # Drizzle schema definitions & client connection
│   │   ├── lib/                   # Utility helpers (date helpers, crypto, etc.)
│   │   ├── plugins/               # Elysia plugins (auth, error handler)
│   │   ├── routes/                # Endpoints (tasks, users, focus, dashboard, line, nudges)
│   │   ├── scripts/               # CLI / Scheduled scripts (dispatch-nudges.ts)
│   │   ├── services/              # Core business logic (priority, avoidance, gemini, line)
│   │   ├── app.ts                 # Elysia application instance setup
│   │   └── index.ts               # Server entry point
│   ├── tests/                     # 16 Unit and integration test suites
│   ├── Dockerfile                 # Multi-stage Bun Dockerfile
│   └── vercel.json                # Vercel deployment configuration
│
├── frontend/                      # Mobile & Web client (Flutter)
│   ├── lib/
│   │   ├── models/                # Data models (Task, FocusSession, Recommendation)
│   │   ├── screens/               # Screens (Dashboard, TaskList, TaskDetail, FocusTimer, AddTask)
│   │   ├── services/              # API Client, LIFF Service, LocalStorage
│   │   ├── theme/                 # App Colors, Typography & Theme Controller
│   │   ├── widgets/               # Reusable UI components & Task Cards
│   │   └── main.dart              # Flutter application entry point
│   ├── test/                      # Flutter widget & unit tests
│   └── pubspec.yaml               # Flutter package configuration
│
├── docs/                          # Project Documentation
│   ├── adr/                       # Architecture Decision Records (ADRs)
│   │   ├── 0001-anonymous-device-uuid-auth.md
│   │   ├── 0002-dynamic-score-calculation.md
│   │   ├── 0003-client-driven-focus-timer.md
│   │   ├── 0004-soft-delete-for-tasks.md
│   │   └── 0005-action-nudge-delivery.md
│   └── deployment/                # Comprehensive deployment guides
│       ├── DEPLOYMENT_GUIDE.md    # Production deployment step-by-step
│       └── flutter-web-vercel.md  # Flutter Web deployment on Vercel
│
├── docker-compose.yml             # Local full-stack container orchestration
├── CONTEXT.md                     # Domain Terminology & Ubiquitous Language
└── Nudge_Project_Specification.md # Full detailed project specification
```

---

## 🚀 การเริ่มต้นใช้งานในเครื่อง (Getting Started)

### ความต้องการพื้นฐาน (Prerequisites)
- [Bun](https://bun.sh/) (v1.1+ ขึ้นไป)
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (v3.19+ ขึ้นไป)
- [Docker](https://www.docker.com/) และ Docker Compose (สำหรับ Database หรือรันผ่าน Container)

---

### 1. Backend & Database Setup

1. เข้าไปที่โฟลเดอร์ `backend`:
   ```bash
   cd backend
   ```

2. ติดตั้ง Dependencies:
   ```bash
   bun install
   ```

3. คัดลอกและตั้งค่า Environment Variables:
   ```bash
   cp .env.example .env
   ```
   *ตรวจสอบและระบุ `DATABASE_URL` (สามารถใช้ Neon DB หรือ Local Postgres)*

4. สั่ง Push Schema สู่ฐานข้อมูล:
   ```bash
   bun run db:push
   ```

5. รันเซิร์ฟเวอร์ในโหมด Development:
   ```bash
   bun run dev
   ```
   *เซิร์ฟเวอร์จะเริ่มทำงานที่ `http://localhost:3000` (Health Check: `http://localhost:3000/health`)*

---

### 2. Frontend Setup (Flutter)

1. เข้าไปที่โฟลเดอร์ `frontend`:
   ```bash
   cd frontend
   ```

2. ติดตั้ง Flutter Packages:
   ```bash
   flutter pub get
   ```

3. รันบน Chrome (Web) หรือ Emulator:
   ```bash
   # สำหรับ Web
   flutter run -d chrome

   # สำหรับ Mobile (ต่อ Device / Emulator)
   flutter run
   ```

---

### 3. รันผ่าน Docker Compose

หากต้องการรัน Backend และ PostgreSQL พร้อมกันในคำสั่งเดียว:

```bash
# จาก root ของโปรเจกต์
docker compose up -d --build
```
ระบบจะเปิดบริการ:
- **Backend API:** `http://localhost:3000`
- **PostgreSQL Database:** `localhost:5432`

---

## 🔐 ค่าคอนฟิกูเรชัน (Environment Variables)

กำหนดค่าเหล่านี้ในไฟล์ `backend/.env`:

| ตัวแปร | ความจำเป็น | คำอธิบาย | ตัวอย่าง |
| :--- | :---: | :--- | :--- |
| `PORT` | Optional | พอร์ตการทำงานของเซิร์ฟเวอร์ (Default: 3000) | `3000` |
| `DATABASE_URL` | **Required** | PostgreSQL connection URL | `postgresql://postgres:postgres@localhost:5432/nudge` |
| `LINE_CHANNEL_ACCESS_TOKEN` | Optional | LINE Messaging API Channel Access Token | `ey...` |
| `LINE_CHANNEL_SECRET` | Optional | LINE Channel Secret สำหรับ verify webhook signature | `3a9f...` |
| `LINE_LIFF_ID` | Optional | LINE LIFF ID สำหรับเปิด Webview ในแอป LINE | `2007802875-9W231x4e` |
| `GEMINI_API_KEY` | Optional | Google Gemini API Key สำหรับแปลงภาษาธรรมชาติ/เสียงเป็น Task | `AIzaSy...` |
| `NUDGE_DISPATCH_KEY` | Optional | คีย์ลับสำหรับ Cron ป้องกันคนภายนอกยิง `/nudges/dispatch` | `random_secret_hash` |

---

## 🧪 การทดสอบ (Testing)

โปรเจกต์นี้มี Test Coverage ทั้งฝั่ง Backend และ Frontend:

### รัน Backend Tests
```bash
cd backend
bun test
```
*ครอบคลุมการทดสอบ Avoidance Detection, Priority Calculation, Focus Session, Date Manipulation, LINE Webhook, AI Model Fallback และ Quick Add*

### รัน Typecheck
```bash
cd backend
bun run typecheck
```

### รัน Frontend Tests
```bash
cd frontend
flutter test
```

---

## 📚 เอกสารสถาปัตยกรรมและคู่มือการ Deploy (Documentation & ADRs)

- **[คู่มือการ Deploy สู่ Production (DEPLOYMENT_GUIDE.md)](./docs/deployment/DEPLOYMENT_GUIDE.md)**: คำแนะนำละเอียดในการ Deploy Backend ขึ้น Vercel/Render, Database ขึ้น Neon, และการเชื่อมต่อ LINE Messaging API / LIFF
- **[Flutter Web บน Vercel](./docs/deployment/flutter-web-vercel.md)**: คำแนะนำ Build Flutter Web สู่ Production
- **Architecture Decision Records (ADRs):**
  - [ADR 0001: Anonymous Device UUID Authentication](./docs/adr/0001-anonymous-device-uuid-auth.md)
  - [ADR 0002: Dynamic Score Calculation](./docs/adr/0002-dynamic-score-calculation.md)
  - [ADR 0003: Client-Driven Focus Timer](./docs/adr/0003-client-driven-focus-timer.md)
  - [ADR 0004: Soft Delete for Tasks](./docs/adr/0004-soft-delete-for-tasks.md)
  - [ADR 0005: Action Nudge Delivery Architecture](./docs/adr/0005-action-nudge-delivery.md)
- **[ข้อกำหนดระบบฉบับเต็ม (Nudge Project Specification)](./Nudge_Project_Specification.md)**

---

## 🗣️ คำศัพท์เฉพาะในระบบ (Domain Language & Glossary)

เพื่อความเข้าใจและสื่อสารที่ตรงกันทั้งโค้ดและดีไซน์ (Ubiquitous Language):

| คำศัพท์ที่ใช้ | ความหมาย | คำที่ควรหลีกเลี่ยง (_Avoid_) |
| :--- | :--- | :--- |
| **Task** | หน่วยของงานที่มี Deadline, Importance และ Estimated Duration | Todo, Item, Job, Chore |
| **Deadline** | วันและเวลาเป้าหมายที่ต้องส่งงาน | Due Date, Target Date, Expiry |
| **Explicit Postpone** | พฤติกรรมที่ผู้ใช้กดเลื่อนกำหนดส่งอย่างตั้งใจ ไม่ใช่ปล่อยให้หมดอายุเฉยๆ | Snooze, Delay, Reschedule, Procrastinate |
| **Potentially Avoided** | การอนุมานเชิงพฤติกรรมว่างานกำลังถูกหลีกเลี่ยง โดยไม่ตีตราผู้ใช้ | Lazy, Procrastinated, Failed Task |
| **Action Nudge** | ข้อความกระตุ้นที่แนะนำก้าวแรกที่เล็กและทำง่ายเพื่อเริ่มงาน | Reminder, Alert, Notification, Warning |
| **Focus Session** | ช่วงเวลาทำงานสั้นๆ (ค่าเริ่มต้น 10 นาที) เพื่อทำลายกำแพงการเริ่มต้น | Pomodoro, Study Sprint, Work Block |
| **Days Remaining** | จำนวนวันคงเหลือก่อนถึง Deadline (คำนวณแบบ Dynamic เสมอ) | Time Left, Days Left, Countdown |
| **Avoidance Score** | คะแนนตัวเลขที่สะท้อนความถี่ในการเลื่อนงาน | Procrastination Score, Laziness Index |
| **Priority Score** | คะแนนรวมที่ใช้จัดลำดับความสำคัญของงานที่ควรทำต่อไป | Rank, Task Weight |

---

## 👥 ทีมผู้จัดทำ

<div align="center">

| ชื่อ-นามสกุล | รหัสนักศึกษา |
| :--- | :---: |
| นาย จิรศักดิ์ ทองพิละ | 6712732103 |
| นาย ฐิติพงศ์ อิงสันเทียะ | 6712732104 |
| นางสาว จีรนันท์ เกิดกล้า | 6712732121 |

<br/>

### 🎓 สถาบันการศึกษา

**สาขาวิชาวิทยาการคอมพิวเตอร์**<br/>
**คณะศิลปศาสตร์และวิทยาศาสตร์**<br/>
**มหาวิทยาลัยราชภัฏศรีสะเกษ**

</div>

---

<div align="center">
  <sub>Developed with ❤️ for behavioral productivity & mindful task management.</sub>
</div>

