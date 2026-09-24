# คู่มือการ Deploy ระบบ Nudge สู่ Production (Production Deployment Guide)

เอกสารนี้รวบรวมขั้นตอนทั้งหมดในการ Deploy ระบบ **Nudge** ทั้งฝั่ง **Backend (Bun / Elysia / Docker)**, **Frontend (Flutter Web / LINE LIFF)**, **Database (Neon PostgreSQL)**, **Action Nudge Cron Scheduler**, และ **LINE Developers Console**

---

## 📋 ข้อมูลสำคัญสำหรับ Environment Variables

### 1. Backend Environment Variables (`.env`)

| Variable | Description | Example / Note |
| :--- | :--- | :--- |
| `PORT` | พอร์ตสำหรับเซิร์ฟเวอร์ | `3000` (Cloud PaaS จะกำหนดให้อัตโนมัติ) |
| `HOST` | IP Host ในการดักฟังการเชื่อมต่อ | `0.0.0.0` (รองรับ Docker / Cloud Container) |
| `DATABASE_URL` | Neon PostgreSQL connection string (Transaction pooler) | `postgresql://user:pass@ep-xyz.ap-southeast-1.aws.neon.tech/nudge?sslmode=require` |
| `LINE_CHANNEL_ACCESS_TOKEN` | LINE Messaging API Channel Access Token | ออกจาก LINE Developers Console (Messaging API tab) |
| `LINE_CHANNEL_SECRET` | LINE Messaging API Channel Secret | ออกจาก LINE Developers Console (Basic settings tab) |
| `LINE_LIFF_ID` | LINE LIFF ID สำหรับเปิด Action Focus และ Deep Link | เช่น `2007802875-9W231x4e` |
| `GEMINI_API_KEY` | Google Gemini API Key สำหรับ AI NLP & Voice Parsing | ออกจาก Google AI Studio (`https://aistudio.google.com`) |
| `NUDGE_DISPATCH_KEY` | Shared secret key สำหรับ Cron Scheduler เรียกยิง Nudge | สุ่ม secret เช่น `openssl rand -hex 32` |

---

## 🗄️ ขั้นตอนที่ 1: เตรียมฐานข้อมูล Neon PostgreSQL

1. เข้าสู่ระบบ [Neon Console](https://console.neon.tech)
2. สร้างโปรเจกต์ใหม่ (แนะนำ Region: `AWS Singapore` เพื่อ Latency ต่ำที่สุดกับผู้ใช้ในไทย)
3. คัดลอก Connection String รูปแบบ:
   ```
   postgresql://[user]:[password]@[neon-host]/nudge?sslmode=require
   ```
4. ระบบ Migration จะรันอัตโนมัติเมื่อ Container เริ่มทำงาน (`drizzle-kit push`) หรือสามารถรันแบบ Manual จากเครื่อง Local ได้ทันที:
   ```bash
   cd backend
   DATABASE_URL="<your_neon_url>" bun run db:push
   ```

---

## 🚀 ขั้นตอนที่ 2: Deploy Backend

สามารถเลือกใช้วิธีใดวิธีหนึ่งด้านล่าง:

### วิธีที่ A: Deploy บน Vercel (แนะนำ - เร็วที่สุด รองรับ Serverless Bun + Vercel Cron)

Elysia รองรับการรันบน Vercel แบบ Serverless และเราได้เตรียม [backend/vercel.json](file:///d:/JWS/project/mobile/Nudge/backend/vercel.json) ไว้ให้เรียบร้อยแล้ว:

1. **ผ่าน Vercel CLI:**
   ```bash
   cd backend
   vercel
   # เลือกตั้งค่าโปรเจกต์ และ deploy ขึ้น production ด้วย:
   vercel --prod
   ```
2. **ผ่าน Vercel Dashboard (เชื่อม GitHub):**
   - ไปที่ [Vercel Dashboard](https://vercel.com/new) -> **Import Git Repository**
   - **Root Directory:** ให้เลือกโฟลเดอร์ `backend`
   - **Framework Preset:** เลือก `Other`
   - **Environment Variables:** ใส่ค่า:
     - `DATABASE_URL` (Neon PostgreSQL)
     - `LINE_CHANNEL_ACCESS_TOKEN`
     - `LINE_CHANNEL_SECRET`
     - `LINE_LIFF_ID`
     - `GEMINI_API_KEY`
     - `NUDGE_DISPATCH_KEY` (หรือ Vercel จะสร้าง `CRON_SECRET` ให้)
   - กด **Deploy** จะได้โดเมน HTTPS ทันที เช่น `https://nudge-backend.vercel.app`
3. **Vercel Cron:** ระบบจะเปิดใช้งาน Cron Job เรียก `/nudges/dispatch` ตามเวลาใน `vercel.json` ให้อัตโนมัติ!

### วิธีที่ B: Deploy บน Render (Docker Container)
1. Fork หรือ Push โค้ดขึ้น GitHub
2. เข้าสู่ [Render Dashboard](https://dashboard.render.com)
3. เลือก **New +** -> **Blueprint** แล้วเลือก Repository นี้ (ระบบจะอ่านไฟล์ [render.yaml](file:///d:/JWS/project/mobile/Nudge/render.yaml) อัตโนมัติ)
4. กรอกค่า Environment Variables แล้วกด Apply

### วิธีที่ C: Deploy บน Railway
1. เข้าสู่ [Railway Dashboard](https://railway.app)
2. เลือก **New Project** -> **Deploy from GitHub repo** -> เลือกโฟลเดอร์ `backend`
3. ในแท็บ **Variables** ใส่ค่า Environment Variables แล้วรับโดเมน HTTPS

### วิธีที่ D: Deploy บน VPS / Docker Compose
1. อัปโหลดโค้ดไปยังเซิร์ฟเวอร์
2. รัน `docker compose up -d --build`

---

## ⏰ ขั้นตอนที่ 3: ตั้งเวลา Action Nudge Cron Scheduler

ตามข้อกำหนด ADR-0005 ระบบต้องมี Scheduler คอยเรียกส่ง Action Nudge ให้ผู้ใช้:

- **Endpoint:** `POST https://<your-backend-domain>/nudges/dispatch`
- **Header:** `x-nudge-dispatch-key: <NUDGE_DISPATCH_KEY>`
- **รอบเวลาแนะนำ:** ทุกๆ 1 ชั่วโมง ระหว่างเวลา 08:00 - 21:00 น. ตามเวลาไทย (UTC 01:00 - 14:00)

### ทางเลือกในการตั้ง Cron:
1. **Render Cron Job:** ตั้งค่าไว้แล้วใน `render.yaml`
2. **cron-job.org (ฟรี):**
   - URL: `https://<your-backend-domain>/nudges/dispatch`
   - Method: `POST`
   - Headers: `x-nudge-dispatch-key: <key>`
   - Schedule: ทุก 1 ชั่วโมง
3. **GitHub Actions Scheduled Workflow:** สามารถสร้าง `.github/workflows/nudge-cron.yml` เรียก `curl -X POST` ได้เช่นกัน

---

## 🌐 ขั้นตอนที่ 4: Build & Deploy Frontend (Flutter Web สำหรับ LINE LIFF)

LINE LIFF ต้องการเว็บแอปที่เป็น HTTPS เพื่อรันภายใน LINE In-App Browser

### 1. Build Production Web Bundle
รันคำสั่ง Build โดยส่ง URL ของ Backend จริง และ LIFF ID ผ่าน `--dart-define`:

```bash
cd frontend
flutter build web --release \
  --dart-define=API_URL=https://<your-backend-domain> \
  --dart-define=LINE_LIFF_ID=<your-liff-id> \
  --no-tree-shake-icons
```
ไฟล์ที่ Build สำเร็จจะอยู่ในโฟลเดอร์ `frontend/build/web/`

### 2. Deploy Web ขึ้น Hosting (เลือกอย่างใดอย่างหนึ่ง)

#### ทางเลือก A: Vercel (ฟรี & รวดเร็ว)
1. ติดตั้ง Vercel CLI: `npm i -g vercel`
2. ไปที่โฟลเดอร์ build:
   ```bash
   cd frontend/build/web
   vercel --prod
   ```
3. นำ URL ที่ได้ (เช่น `https://nudge-app.vercel.app`) ไปตั้งใน LINE Developers Console

#### ทางเลือก B: Cloudflare Pages (ฟรี & CDN เร็วที่สุดในไทย)
1. ไปที่ Cloudflare Dashboard -> **Workers & Pages** -> **Create Application** -> **Pages**
2. อัปโหลดโฟลเดอร์ `frontend/build/web` หรือเชื่อมกับ GitHub

---

## 📱 ขั้นตอนที่ 5: การตั้งค่า LINE Developers Console

### 1. Messaging API (LINE OA Webhook)
1. เข้าไปที่ [LINE Developers Console](https://developers.line.biz/console/)
2. เลือก Provider และ Messaging API Channel ของคุณ
3. ไปที่แท็บ **Messaging API**:
   - **Webhook URL:** ใส่ `https://<your-backend-domain>/line/webhook`
   - กดปุ่ม **Verify** เพื่อทดสอบการเชื่อมต่อ (ระบบต้องตอบกลับ 200 OK)
   - เปิดสวิตช์ **Use webhook** เป็น **ON**
   - ใน **Auto-reply messages** ให้กดเข้าไปปิดการตอบกลับอัตโนมัติของ LINE Official Account Manager เพื่อให้ Nudge AI ตอบกลับเพียงผู้เดียว

### 2. LINE LIFF (LIFF App Setting)
1. ใน LINE Developers Console ไปที่แท็บ **LIFF**
2. กด **Add** หรือแก้ไข LIFF App ที่มีอยู่:
   - **LIFF app name:** `Nudge`
   - **Size:** `Full` หรือ `Tall`
   - **Endpoint URL:** ใส่ URL ของเว็บที่ Deploy ในขั้นตอนที่ 4 เช่น `https://nudge-app.vercel.app/`
   - **Scopes:** เลือก `profile`, `openid`
   - **Bot prompt:** เลือก `Aggressive` หรือ `Normal`
3. คัดลอก **LIFF ID** (เช่น `2007802875-9W231x4e`) มาใส่ใน Environment Variable ของ Backend และ Frontend

---

## ✅ การทดสอบการทำงานหลัง Deploy (Verification Checklist)

1. [ ] **Health Check:** เปิดเบราว์เซอร์ไปที่ `https://<your-backend-domain>/health` ต้องได้สถานะ `{"status":"ok","service":"nudge-backend"}`
2. [ ] **LINE Webhook:** ใน LINE Developers Console กดปุ่ม "Verify" ของ Webhook ต้องขึ้น Success
3. [ ] **LINE Bot Interactivity:**
   - ส่งข้อความเสียง (Voice Message) สั่งงาน เช่น "พรุ่งนี้ส่งรายงานโปรเจกต์ตอนห้าโมงเย็น"
   - บอทต้องตอบกลับด้วย Flex Card ยืนยันการสร้างงาน
   - ลองพิมพ์ "งานของฉัน" หรือ "เริ่ม 10 นาที"
4. [ ] **LIFF Opening:** เมื่อกดปุ่ม "เริ่ม 10 นาที" ใน LINE ต้องเปิดหน้า Focus Timer Screen แบบเต็มจอและเชื่อมต่อข้อมูลกับ Backend ได้สำเร็จ
5. [ ] **Nudge Dispatch:** ยิง curl ทดสอบ:
   ```bash
   curl -X POST https://<your-backend-domain>/nudges/dispatch \
     -H "x-nudge-dispatch-key: <your-key>"
   ```
