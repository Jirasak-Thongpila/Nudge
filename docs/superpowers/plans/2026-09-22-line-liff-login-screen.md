# LINE LIFF Login Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and integrate a dedicated LINE LIFF Login Screen in Flutter for Nudge with automatic LIFF authentication, Guest mode fallback, developer testing panel, and session management.

**Architecture:** The app root (`main.dart`) directs to `LoginScreen`, which checks backend health and LIFF SDK on Web. If authenticated via LIFF, it auto-syncs with Elysia backend (`POST /line/auth`) and navigates to `DashboardScreen`; otherwise, it presents a branded login UI with LINE Login, Guest Mode (ADR-0001), and a collapsible Dev simulator panel. `DashboardScreen` provides logout back to `LoginScreen`.

**Tech Stack:** Flutter 3, Dart, `flutter_line_liff: ^1.0.0`, `shared_preferences: ^2.3.3`, `http: ^1.2.2`, Elysia backend with Neon PostgreSQL.

## Global Constraints

- Respect ADR-0001: Support anonymous UUID device-based identity alongside LINE account linking.
- Nudge vocabulary: Use "Action Nudge", "Focus Session", "อาจกำลังหลีกเลี่ยง" (potentially avoided).
- Safe platform execution: LIFF SDK calls must be guarded with `kIsWeb` to prevent runtime crashes on Windows/Android.
- LIFF ID must match backend `.env`: `2011693149-NldwbAUx`.
- UI Colors: Primary Indigo `#6366F1`, LINE Official Green `#06C755`.

---

### Task 1: Update `LiffService` with Real LIFF ID & Logout

**Files:**
- Modify: `frontend/lib/services/liff_service.dart:30-106`

**Interfaces:**
- Consumes: `flutter_line_liff` SDK
- Produces: `LiffService.instance.init({String? liffId})`, `LiffService.instance.logout()`, `LiffService.instance.login()`

- [ ] **Step 1: Update default LIFF ID and add logout method in `LiffService`**

Update `frontend/lib/services/liff_service.dart`:
Change default `targetLiffId` to `2011693149-NldwbAUx`. Add `void logout()`:
```dart
  /// Logs out of LINE LIFF session if on Web platform
  void logout() {
    if (kIsWeb && _isLiffSupported) {
      try {
        final liff = FlutterLineLiff.instance;
        if (liff.isLoggedIn) {
          liff.logout();
        }
      } catch (e) {
        debugPrint('Error logging out of LIFF: $e');
      }
    }
    _profile = null;
  }
```

- [ ] **Step 2: Run Flutter tests to verify existing suite remains intact**

Run: `flutter test`
Expected: All tests pass

- [ ] **Step 3: Commit**

```bash
git add frontend/lib/services/liff_service.dart
git commit -m "feat(frontend): update LiffService with production LIFF ID and logout"
```

---

### Task 2: Create `LoginScreen` Component

**Files:**
- Create: `frontend/lib/screens/login_screen.dart`

**Interfaces:**
- Consumes: `ApiClient`, `LiffService`, `DeepLinkService`, `User`
- Produces: `LoginScreen(apiClient: ApiClient)` navigating to `DashboardScreen`

- [ ] **Step 1: Implement `LoginScreen` stateful widget**

Create `frontend/lib/screens/login_screen.dart` containing:
- Hero branding: Nudge icon (`Icons.alarm_on_rounded` or `Icons.psychology_alt_rounded`), title "Nudge", tagline "ก้าวข้ามการผัดวันประกันพรุ่งด้วยก้าวเล็กๆ"
- Health check & auto-login check on `initState`
- State variables: `_isLoading`, `_loadingMessage`, `_backendOffline`, `_devLineIdController`
- Primary button: "เข้าสู่ระบบด้วย LINE" (Green `#06C755`, chat icon)
- Secondary button: "ใช้งานแบบไม่ผูกบัญชี (Guest Mode)" (ADR-0001 `getCurrentUser`)
- Dev/Test Mode ExpansionTile: Quick login buttons for `test_line_user_01`, `test_line_user_02`, and custom LINE User ID textfield with "จำลองเข้าสู่ระบบ"
- Query parameter checking for `taskId` forwarding via `DeepLinkService`

- [ ] **Step 2: Run Flutter analyze to ensure clean code**

Run: `flutter analyze lib/screens/login_screen.dart` in `frontend/`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add frontend/lib/screens/login_screen.dart
git commit -m "feat(frontend): add LoginScreen with LINE LIFF, Guest, and Dev modes"
```

---

### Task 3: Add Widget Test for `LoginScreen`

**Files:**
- Create: `frontend/test/login_screen_test.dart`

**Interfaces:**
- Consumes: `LoginScreen`, `ApiClient`
- Produces: Verified UI rendering and interaction test suite

- [ ] **Step 1: Write widget test for `LoginScreen`**

Create `frontend/test/login_screen_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge_app/screens/login_screen.dart';
import 'package:nudge_app/services/api_client.dart';

void main() {
  testWidgets('LoginScreen renders branding and action buttons', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LoginScreen(),
      ),
    );

    // Verify Title & Tagline
    expect(find.text('Nudge'), findsOneWidget);
    expect(find.text('ก้าวข้ามการผัดวันประกันพรุ่งด้วยก้าวเล็กๆ'), findsOneWidget);

    // Verify Action buttons
    expect(find.text('เข้าสู่ระบบด้วย LINE'), findsOneWidget);
    expect(find.text('ใช้งานแบบไม่ผูกบัญชี (Guest Mode)'), findsOneWidget);

    // Verify Dev Mode panel
    expect(find.text('โหมดนักพัฒนา (Dev / Test Mode)'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it passes**

Run: `flutter test test/login_screen_test.dart`
Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add frontend/test/login_screen_test.dart
git commit -m "test(frontend): add widget tests for LoginScreen"
```

---

### Task 4: Connect `LoginScreen` in `main.dart` & Add Logout to `DashboardScreen`

**Files:**
- Modify: `frontend/lib/main.dart`
- Modify: `frontend/lib/screens/dashboard_screen.dart:460-490`

**Interfaces:**
- Consumes: `LoginScreen`, `LiffService.instance.logout()`
- Produces: Root application entry pointing to `LoginScreen`, and seamless logout flow from `DashboardScreen`

- [ ] **Step 1: Modify `main.dart` to use `LoginScreen` as home**

Update `frontend/lib/main.dart`:
- Import `screens/login_screen.dart`
- In `NudgeApp`, replace `home: const WalkingSkeletonScreen()` with `home: const LoginScreen()`

- [ ] **Step 2: Add Logout action to `DashboardScreen`**

In `frontend/lib/screens/dashboard_screen.dart`:
- Add a popup menu or logout icon button in `appBar.actions`:
  ```dart
  PopupMenuButton<String>(
    icon: const Icon(Icons.account_circle_outlined),
    tooltip: 'บัญชีผู้ใช้',
    onSelected: (value) {
      if (value == 'logout') {
        _confirmLogout();
      }
    },
    itemBuilder: (ctx) => [
      PopupMenuItem(
        enabled: false,
        child: Text(
          widget.user.lineUserId != null
              ? 'LINE: ${widget.user.lineUserId}'
              : 'Guest User #${widget.user.id}',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ),
      const PopupMenuDivider(),
      const PopupMenuItem(
        value: 'logout',
        child: Row(
          children: [
            Icon(Icons.logout, size: 18, color: Colors.red),
            SizedBox(width: 8),
            Text('ออกจากระบบ', style: TextStyle(color: Colors.red)),
          ],
        ),
      ),
    ],
  )
  ```
- Implement `_confirmLogout()`:
  - Dialog confirming sign out
  - Calls `LiffService.instance.logout()`
  - Uses `Navigator.of(context).pushAndRemoveUntil` to return to `LoginScreen(apiClient: widget.apiClient)`.

- [ ] **Step 3: Run full test suite**

Run: `flutter test`
Expected: All tests pass

- [ ] **Step 4: Commit**

```bash
git add frontend/lib/main.dart frontend/lib/screens/dashboard_screen.dart
git commit -m "feat(frontend): set LoginScreen as app root and add logout to Dashboard"
```

---

### Task 5: Final Validation & Health Check

- [ ] **Step 1: Run Flutter analyze across the entire frontend**

Run: `flutter analyze`
Expected: No errors

- [ ] **Step 2: Run all Flutter unit & widget tests**

Run: `flutter test`
Expected: All tests pass (0 failures)

- [ ] **Step 3: Commit final plan documentation**

```bash
git add docs/superpowers/plans/2026-09-22-line-liff-login-screen.md
git commit -m "docs: finalize LINE LIFF login screen implementation plan"
```
