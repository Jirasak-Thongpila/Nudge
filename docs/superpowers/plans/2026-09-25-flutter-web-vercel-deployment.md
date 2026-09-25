# Flutter Web Vercel Deployment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Configure and automate the deployment of Flutter Web to Vercel via Git integration and custom build scripting in the `frontend/` directory.

**Architecture:** A standalone Vercel project with Root Directory set to `frontend/`. A dedicated `build.sh` script downloads Flutter SDK stable in Vercel's Linux build container, injects runtime variables (`API_URL`, `LINE_LIFF_ID`) into the Flutter bundle via `--dart-define`, and outputs to `build/web`. `vercel.json` defines SPA routing and CORS/COOP headers for LINE LIFF compatibility.

**Tech Stack:** Flutter Web 3.x, Bash, Vercel Build Container, JSON.

## Global Constraints
- Target platform: Flutter Web on Vercel Linux container (Amazon Linux / AL2023).
- Repository type: Monorepo with `frontend/` and `backend/`. Vercel root directory must be `frontend`.
- Environment variable injection: `--dart-define=API_URL=$API_URL` and `--dart-define=LINE_LIFF_ID=$LINE_LIFF_ID`.
- Routing requirement: All routes rewritten to `/index.html` for client-side Flutter routing.
- Security headers: `Cross-Origin-Opener-Policy: same-origin-allow-popups` to support LINE LIFF.

---

### Task 1: Create Flutter Web Build Script (`frontend/build.sh`)

**Files:**
- Create: `frontend/build.sh`

**Interfaces:**
- Consumes: Environment variables `$API_URL` and `$LINE_LIFF_ID` (if set in Vercel)
- Produces: Compiled Flutter Web assets in `frontend/build/web/`

- [ ] **Step 1: Write `frontend/build.sh`**

```bash
#!/bin/bash
set -e

echo "=== Starting Flutter Web Build on Vercel ==="

# 1. Setup Flutter SDK
FLUTTER_DIR="$HOME/flutter"
if [ ! -d "$FLUTTER_DIR" ]; then
  echo "Downloading Flutter SDK (channel stable)..."
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 "$FLUTTER_DIR"
fi

export PATH="$FLUTTER_DIR/bin:$PATH"

echo "Checking Flutter version..."
flutter --version

echo "Configuring Flutter..."
flutter config --no-analytics
flutter config --enable-web

# 2. Get dependencies
echo "Running flutter pub get..."
flutter pub get

# 3. Prepare dart-define parameters
DART_DEFINES=""
if [ -n "$API_URL" ]; then
  echo "Passing API_URL=$API_URL"
  DART_DEFINES="$DART_DEFINES --dart-define=API_URL=$API_URL"
fi

if [ -n "$LINE_LIFF_ID" ]; then
  echo "Passing LINE_LIFF_ID=$LINE_LIFF_ID"
  DART_DEFINES="$DART_DEFINES --dart-define=LINE_LIFF_ID=$LINE_LIFF_ID"
fi

# 4. Build Flutter Web release
echo "Building Flutter Web release bundle..."
flutter build web --release $DART_DEFINES

# 5. Verify output
if [ ! -f "build/web/index.html" ]; then
  echo "Error: build/web/index.html not found!"
  exit 1
fi

echo "=== Flutter Web Build Completed Successfully! ==="
```

- [ ] **Step 2: Verify script syntax and set execution permission**

Run in terminal:
```bash
git update-index --chmod=+x frontend/build.sh
```

- [ ] **Step 3: Commit Task 1**

```bash
git add frontend/build.sh
git commit -m "feat(frontend): add build script for vercel deployment"
```

---

### Task 2: Configure `frontend/vercel.json`

**Files:**
- Modify: `frontend/vercel.json`

**Interfaces:**
- Consumes: `frontend/build.sh`
- Produces: Vercel project configuration for build commands, output directory, SPA rewrites, and security headers.

- [ ] **Step 1: Update `frontend/vercel.json`**

Replace content of `frontend/vercel.json`:
```json
{
  "buildCommand": "bash build.sh",
  "outputDirectory": "build/web",
  "rewrites": [
    {
      "source": "/(.*)",
      "destination": "/index.html"
    }
  ],
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
}
```

- [ ] **Step 2: Validate JSON syntax**

Run:
```powershell
Get-Content frontend/vercel.json | ConvertFrom-Json
```
Expected: Parses successfully with no error.

- [ ] **Step 3: Commit Task 2**

```bash
git add frontend/vercel.json
git commit -m "feat(frontend): configure vercel.json with build command and headers"
```

---

### Task 3: Local Build Validation

**Files:**
- Test local build generation in `frontend/`

**Interfaces:**
- Consumes: Flutter SDK, `frontend/pubspec.yaml`, `frontend/lib/main.dart`
- Produces: `frontend/build/web/index.html`

- [ ] **Step 1: Run Flutter build web release locally**

Run:
```powershell
cd d:\JWS\project\mobile\Nudge\frontend
flutter build web --release --dart-define=API_URL=http://localhost:3000 --dart-define=LINE_LIFF_ID=2011693149-NldwbAUx
```
Expected: `✓ Built build/web`

- [ ] **Step 2: Verify existence of output artifacts**

Check that `frontend/build/web/index.html` exists and `frontend/.gitignore` ignores `build/`.
Run:
```powershell
Test-Path frontend/build/web/index.html
```
Expected: `True`

- [ ] **Step 3: Verify git status is clean of built assets**

Run:
```bash
git status
```
Expected: `build/` is untracked/ignored by `.gitignore`.

---

### Task 4: Add Deployment Guide Runbook

**Files:**
- Create: `docs/deployment/flutter-web-vercel.md`

**Interfaces:**
- Consumes: Architecture decisions and Vercel project settings
- Produces: Clear, step-by-step instructions for dashboard setup on Vercel

- [ ] **Step 1: Write `docs/deployment/flutter-web-vercel.md`**

Include:
- Project creation in Vercel (Root Directory: `frontend`)
- Framework preset (`Other`)
- Environment variable configuration (`API_URL`, `LINE_LIFF_ID`)
- LINE Developer Console LIFF Endpoint URL update (pointing to Vercel domain)
- Troubleshooting tips (build timeout, caching, CORS/COOP)

- [ ] **Step 2: Commit Task 4**

```bash
git add docs/deployment/flutter-web-vercel.md
git commit -m "docs: add vercel flutter web deployment guide"
```
