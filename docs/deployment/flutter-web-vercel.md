# คู่มือการ Deploy Flutter Web บน Vercel แบบ CI/CD อัตโนมัติ

คู่มือนี้อธิบายขั้นตอนการตั้งค่าโปรเจกต์ **Flutter Web (`frontend/`)** บน **Vercel** ให้ทำการ Build และ Deploy อัตโนมัติทุกครั้งที่มีการ `git push` เข้าสู่ GitHub

---

## 🛠️ โครงสร้างไฟล์ที่เตรียมไว้ในโปรเจกต์

ระบบได้จัดเตรียมไฟล์คอนฟิกสำหรับการ Deploy ไว้ที่โฟลเดอร์ `frontend/` เรียบร้อยแล้ว:

1. **[`frontend/build.sh`](file:///d:/JWS/project/mobile/Nudge/frontend/build.sh)**:
   - ตรวจสอบและดาวน์โหลด Flutter SDK (channel stable) อัตโนมัติใน Vercel Build Container
   - สั่งเปิดใช้งาน Web (`flutter config --enable-web --no-analytics`)
   - ดาวน์โหลด dependencies (`flutter pub get`)
   - นำค่าตัวแปร `$API_URL` และ `$LINE_LIFF_ID` จาก Environment Variables ของ Vercel ไปใส่ในคำสั่ง Build ผ่าน `--dart-define`
   - Build ไฟล์ Production Release ออกมาที่ `build/web/`
2. **[`frontend/vercel.json`](file:///d:/JWS/project/mobile/Nudge/frontend/vercel.json)**:
   - กำหนด `buildCommand`: `"bash build.sh"`
   - กำหนด `outputDirectory`: `"build/web"`
   - กำหนด SPA `rewrites`: ทุก URL จะถูกส่งไปยัง `/index.html` เพื่อให้ Flutter Web Routing ทำงานได้ถูกต้องเมื่อผู้ใช้กดรีเฟรชหน้าเว็บ
   - กำหนด `headers`: รองรับ `Cross-Origin-Opener-Policy: same-origin-allow-popups` สำหรับ LINE LIFF Authentication

---

## 🚀 ขั้นตอนการตั้งค่าบน Vercel Dashboard

### 1. นำเข้าโปรเจกต์ (Import Project)
1. ไปที่ [Vercel Dashboard](https://vercel.com/new)
2. เลือก **Import** Repository นี้จาก GitHub
3. ในหน้าตั้งค่าโปรเจกต์:
   - **Project Name:** ตั้งชื่อโปรเจกต์ เช่น `nudge-frontend`
   - **Framework Preset:** เลือก **Other**
   - **Root Directory:** กดปุ่ม **Edit** แล้วเลือกโฟลเดอร์ `frontend` *(สำคัญมาก! เพราะเป็น Monorepo)*

### 2. ตั้งค่า Build and Output Settings
โดยปกติ Vercel จะอ่านค่าจาก [`frontend/vercel.json`](file:///d:/JWS/project/mobile/Nudge/frontend/vercel.json) ให้อัตโนมัติ แต่สามารถตรวจสอบให้แน่ใจได้:
- **Build Command:** เปิด Override แล้วระบุ `bash build.sh` (หรือปล่อยให้อ่านจาก `vercel.json`)
- **Output Directory:** เปิด Override แล้วระบุ `build/web`
- **Install Command:** ปล่อยว่างไว้ (เนื่องจาก `build.sh` จัดการการติดตั้ง Flutter และ dependencies เองทั้งหมด)

### 3. กำหนดค่า Environment Variables
ในส่วน **Environment Variables** เพิ่มตัวแปรดังนี้:

| Key | Value ตัวอย่าง | คำอธิบาย |
| :--- | :--- | :--- |
| `API_URL` | `https://nudge-backend.vercel.app` | URL ของ Backend API ที่ deploy แล้ว |
| `LINE_LIFF_ID` | `2011693149-NldwbAUx` | LINE LIFF ID ของคุณ |

> **หมายเหตุ:** หากไม่กำหนดค่า `API_URL` หรือ `LINE_LIFF_ID` ใน Vercel ระบบจะใช้ค่าเริ่มต้นที่กำหนดไว้ในโค้ด Dart

### 4. กด Deploy
กดปุ่ม **Deploy** Vercel จะเริ่มรันสคริปต์ `build.sh`:
- ดาวน์โหลด Flutter SDK stable
- รัน `flutter pub get`
- Build Flutter Web release bundle
- Deploy ขึ้น CDN ระดับโลก พร้อมได้โดเมน HTTPS (เช่น `https://nudge-frontend.vercel.app`)

---

## 📱 การอัปเดต LINE Developers Console

เมื่อได้โดเมนจาก Vercel เรียบร้อยแล้ว ให้นำ URL ไปอัปเดตใน LINE:
1. เข้าไปที่ [LINE Developers Console](https://developers.line.biz/console/)
2. เลือก Provider และ Channel ของคุณ -> ไปที่แท็บ **LIFF**
3. แก้ไข LIFF App:
   - **Endpoint URL:** ใส่ URL ของ Vercel เช่น `https://nudge-frontend.vercel.app/`
4. บันทึกการเปลี่ยนแปลง

---

## 🔍 การทดสอบและตรวจสอบผล (Verification)

1. **ทดสอบเปิดเว็บตรงๆ ผ่านเบราว์เซอร์:**
   - เข้า URL Vercel ของคุณ (เช่น `https://nudge-frontend.vercel.app`)
   - ควรโหลดหน้า Dashboard ของ Nudge ได้อย่างรวดเร็ว
2. **ทดสอบ SPA Routing & Refresh:**
   - นำทางไปยังหน้าย่อยหรือ Focus Timer Screen
   - กดปุ่ม Refresh (F5) หน้านั้นต้องไม่ขึ้น 404 (รองรับด้วย rewrite ใน `vercel.json`)
3. **ทดสอบเปิดผ่าน LINE LIFF:**
   - เปิดลิงก์ `https://liff.line.me/<LINE_LIFF_ID>` บนมือถือ
   - ระบบต้องดึงข้อมูล Profile ของ LINE ผู้ใช้ และเชื่อมต่อกับ Backend ได้สำเร็จ

---

## 💡 เคล็ดลับและการแก้ไขปัญหา (Troubleshooting)

* **Build Timeout:** Vercel Hobby plan ให้เวลา Build สูงสุด 45 นาที การ shallow clone (`--depth 1`) ใน `build.sh` ใช้เวลาดาวน์โหลดเพียง ~1-2 นาที และ build เสร็จสิ้นในเวลาไม่เกิน 3-4 นาที
* **อัปเดตโค้ดในอนาคต:** เพียงแค่ `git push` โค้ดใหม่ขึ้น GitHub ระบบ Vercel จะ trigger build และ deploy เวอร์ชันใหม่ให้โดยอัตโนมัติ
* **ทดสอบ Build บนเครื่อง Local:**
  ```bash
  cd frontend
  flutter build web --release --dart-define=API_URL=http://localhost:3000
  ```
