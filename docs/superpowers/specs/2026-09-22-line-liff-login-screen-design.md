# LINE LIFF Login Screen Design Specification

- **Date:** 2026-09-22
- **Author:** Jirasak Thongpila & AI Pair Assistant
- **Project:** Nudge (Flutter Frontend + Elysia Backend)
- **Status:** Approved

---

## 1. Overview & Goals

Nudge is a task-management and behavioral productivity app focused on overcoming avoidance through low-friction starting actions and empathetic "Action Nudges".

This specification defines the dedicated **LINE LIFF Login Screen** (`LoginScreen`) in the Flutter frontend. It serves as the primary authentication and onboarding gateway for users, supporting:
1. **Seamless LINE LIFF Authentication on Web**: Instant auto-login inside LINE In-App Browser, syncing profile details (LINE User ID, display name, avatar) with backend via `POST /line/auth`.
2. **Anonymous / Guest Mode**: Device UUID authentication (ADR-0001) for users exploring without linking LINE or when offline.
3. **Developer / Test Mode**: A dedicated test panel to simulate LINE logins on local environments (Chrome localhost, Windows, Android) without requiring HTTPS/LINE console registration.
4. **Deep Link Continuity**: Seamless routing of incoming queries (e.g. `?taskId=...` from LINE Action Nudge Flex messages) to the Focus Timer upon successful login.

---

## 2. Architecture & Components

```text
┌───────────────────────────────────────────────────────────┐
│                    Flutter App Root                       │
│                       (main.dart)                         │
└─────────────────────────────┬─────────────────────────────┘
                              │
                              ▼
┌───────────────────────────────────────────────────────────┐
│              LoginScreen (lib/screens/login_screen.dart)  │
│                                                           │
│  [Hero / Branding]                                        │
│  - App Icon (Indigo gradient #6366F1)                     │
│  - App Title "Nudge" & Slogan                             │
│                                                           │
│  [Actions]                                                │
│  - Primary: "เข้าสู่ระบบด้วย LINE" (LINE Green #06C755)   │
│  - Secondary: "ใช้งานแบบไม่ผูกบัญชี (Guest Mode)"          │
│                                                           │
│  [Developer Panel (Collapsible)]                          │
│  - Quick simulate buttons (Test User 01 / 02)             │
│  - Custom LINE User ID input                              │
└──────────────┬─────────────────────────────┬──────────────┘
               │                             │
               ▼                             ▼
┌──────────────────────────────┐ ┌──────────────────────────┐
│ LiffService                  │ │ ApiClient                │
│ - init(liffId: 2011693149-   │ │ - loginWithLine(...)     │
│   NldwbAUx)                  │ │ - getCurrentUser()       │
│ - login() / logout()         │ │                          │
│ - get profile                │ │                          │
└──────────────┬───────────────┘ └───────────┬──────────────┘
               │                             │
               └──────────────┬──────────────┘
                              ▼
┌───────────────────────────────────────────────────────────┐
│                      DashboardScreen                      │
│            (with Logout / Switch Account option)          │
└───────────────────────────────────────────────────────────┘
```

---

## 3. Detailed Component Specifications

### 3.1 `LiffService` Updates (`lib/services/liff_service.dart`)
- Update default LIFF ID to `2011693149-NldwbAUx` (matching `backend/.env`).
- Add `logout()` method to safely call `FlutterLineLiff.instance.logout()` when running on Web.
- Ensure all calls verify `kIsWeb` and `isLiffSupported` to prevent platform channel exceptions on Windows, Android, or Linux.

### 3.2 `LoginScreen` (`lib/screens/login_screen.dart`)
- **State Management:**
  - `_isLoading`: boolean flag to toggle spinner during initialization or auth requests.
  - `_loadingMessage`: descriptive string (e.g. "กำลังตรวจสอบสถานะ...", "กำลังเข้าสู่ระบบด้วย LINE...").
  - `_backendOffline`: boolean flag displayed if `checkHealth()` fails, offering a "ลองใหม่อีกครั้ง" retry button.
- **Initial Verification Flow (`initState`):**
  1. Ping `apiClient.checkHealth()`. If down, show connection error view.
  2. On Web (`kIsWeb`): initialize `LiffService.instance.init()`.
  3. If LIFF indicates already logged in (`liff.isLoggedIn == true`):
     - Fetch `LiffUserProfile`.
     - Call `apiClient.loginWithLine(...)`.
     - Forward to `DashboardScreen`.
- **Button Actions:**
  - **LINE Login**:
    - If on Web and LIFF is supported: call `LiffService.instance.login()`.
    - If on non-Web or LIFF unavailable: notify user and suggest Developer Mode or Guest Mode for local testing.
  - **Guest Mode**:
    - Call `apiClient.getCurrentUser()`.
    - Navigate to `DashboardScreen`.
  - **Dev Test Mode**:
    - Provide preset test user buttons (`test_line_user_01`, `test_line_user_02`) or text field.
    - Call `apiClient.loginWithLine(testId, displayName: 'Test User')`.
    - Navigate to `DashboardScreen`.
- **Deep Link Handling:**
  - Detect `taskId` query parameter from `Uri.base.queryParameters['taskId']`.
  - When login completes, execute `DeepLinkService.navigateFromDeepLink(context, apiClient, 'nudge://focus?taskId=$taskId')`.

### 3.3 Root Gateway Integration (`lib/main.dart`)
- Replace direct launching of `WalkingSkeletonScreen` in `NudgeApp.home` with `LoginScreen`.
- Retain the theme (Indigo seed color `#6366F1`, Material 3).

### 3.4 Dashboard Logout Action (`lib/screens/dashboard_screen.dart`)
- Add an action item in the `DashboardScreen` AppBar (or user profile header) for "ออกจากระบบ" (Logout).
- Action clears user session, invokes `LiffService.instance.logout()` if on Web, and returns to `LoginScreen`.

---

## 4. Error Handling & Edge Cases

| Scenario | Behavior |
|---|---|
| **Backend Unreachable** | Shows friendly retry screen without crashing. Disables login buttons until server is healthy. |
| **Running on Windows/Android/Emulator** | LIFF SDK gracefully deactivates. Guest Mode and Dev Mode remain 100% operational. |
| **Running on Web outside LINE (Localhost Chrome)** | LIFF init fails gracefully without throwing unhandled exceptions. Dev Mode allows immediate bypass. |
| **LINE Login Cancelled by User** | Redirects back to `LoginScreen` in clean state. |
| **Invalid or Expired LINE Token** | Backend responds with error code; UI displays clear snackbar notification and resets loading state. |

---

## 5. Testing & Verification

1. **Automated Widget Tests (`frontend/test/login_screen_test.dart`):**
   - Verify presence of Nudge branding, LINE Login button, Guest button, and Dev Mode accordion.
   - Verify Guest Mode button invokes auth and triggers navigation callback.
   - Verify Dev Mode login submits test LINE ID to API client.
2. **Automated Test Suite:** Run `flutter test` in `frontend/`.
3. **Manual Flow Verification:**
   - Run Flutter app in browser / local target.
   - Test login via Guest Mode, Dev Mode, and error retry state.
