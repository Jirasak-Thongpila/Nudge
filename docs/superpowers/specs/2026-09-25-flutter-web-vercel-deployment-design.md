# Design Specification: Flutter Web Deployment on Vercel

- **Date:** 2026-09-25
- **Author:** Antigravity & เติ้ล (Tle)
- **Status:** Approved

## 1. Overview & Objectives

Deploy the Flutter Web frontend ([`frontend/`](file:///d:/JWS/project/mobile/Nudge/frontend)) of the Nudge application to Vercel with automatic CI/CD on Git push. The backend is located in [`backend/`](file:///d:/JWS/project/mobile/Nudge/backend) within the same monorepo, requiring a dedicated Vercel project with a configured Root Directory.

### Goals
- Fully automated build and deployment on push to the repository on Vercel.
- Support Single Page Application (SPA) routing for deep links and page refreshes.
- Support dynamic injection of environment variables (`API_URL`, `LINE_LIFF_ID`) during the Flutter build step via `--dart-define`.
- Ensure headers support LINE LIFF authentication popups and interactions.

---

## 2. Architecture & Monorepo Setup

```
Nudge (Repository Root)
├── backend/                  # Fastify / Elysia backend (Separate Vercel Project)
│   └── vercel.json
└── frontend/                 # Flutter Web app (Target Vercel Project)
    ├── build.sh              # Custom build script for Vercel Linux container
    ├── vercel.json           # Vercel project routing, build, and headers config
    ├── web/
    │   ├── index.html        # Entry HTML with LIFF SDK script
    │   └── manifest.json
    └── lib/
        └── services/
            ├── api_client.dart   # Reads API_URL from environment
            └── liff_service.dart # Reads LINE_LIFF_ID from environment
```

### Vercel Project Settings
* **Project Name:** `nudge-frontend` (or user choice)
* **Framework Preset:** `Other`
* **Root Directory:** `frontend`
* **Build Command:** `bash build.sh` (or defined in `vercel.json`)
* **Output Directory:** `build/web`

---

## 3. Detailed Component Design

### 3.1 Build Script (`frontend/build.sh`)
The Vercel Linux build environment does not include Flutter by default. The build script must:
1. Ensure `set -e` so failures abort the build immediately.
2. Check if Flutter is already present in `$HOME/flutter` or in PATH.
3. If absent, download Flutter SDK stable channel via shallow clone (`git clone --depth 1 -b stable https://github.com/flutter/flutter.git $HOME/flutter`).
4. Add Flutter to `PATH` (`export PATH="$HOME/flutter/bin:$PATH"`).
5. Disable analytics and enable web (`flutter config --no-analytics --enable-web`).
6. Run `flutter pub get`.
7. Extract `--dart-define` parameters dynamically:
   - If `$API_URL` is set, append `--dart-define=API_URL=$API_URL`.
   - If `$LINE_LIFF_ID` is set, append `--dart-define=LINE_LIFF_ID=$LINE_LIFF_ID`.
8. Execute `flutter build web --release $DART_DEFINES`.
9. Verify that `build/web/index.html` exists.

### 3.2 Vercel Configuration (`frontend/vercel.json`)
The configuration defines:
- **Build & Output:**
  ```json
  {
    "buildCommand": "bash build.sh",
    "outputDirectory": "build/web"
  }
  ```
- **Rewrites (SPA Routing):**
  Route all non-file traffic to `/index.html` so Flutter Navigator handles URL routing without 404s on page refresh:
  ```json
  "rewrites": [
    { "source": "/(.*)", "destination": "/index.html" }
  ]
  ```
- **Headers (Cross-Origin & Cache Control):**
  Add headers allowing LINE LIFF OAuth popups and smooth iframe / popups integration:
  ```json
  "headers": [
    {
      "source": "/(.*)",
      "headers": [
        {
          "key": "Cross-Origin-Opener-Policy",
          "value": "same-origin-allow-popups"
        }
      ]
    }
  ]
  ```

---

## 4. Environment Variables Mapping

| Variable Name | Purpose | Default / Fallback |
| :--- | :--- | :--- |
| `API_URL` | Base URL of Nudge Backend API | `http://localhost:3000` |
| `LINE_LIFF_ID` | LINE LIFF Application ID | `2011693149-NldwbAUx` |

These variables are defined in Vercel's Project Settings > Environment Variables, and passed during `flutter build web --release` as `--dart-define`.

---

## 5. Verification Plan

1. **Local Flutter Release Build Verification**:
   - Run `flutter build web --release` locally to ensure the web bundle compiles without errors.
2. **Configuration Validation**:
   - Validate `vercel.json` format and syntax.
   - Verify `build.sh` is executable (`chmod +x build.sh`) and contains valid bash syntax.
3. **Commit & Push Readiness**:
   - Ensure `.gitignore` ignores `frontend/build/` and `.dart_tool/`.
