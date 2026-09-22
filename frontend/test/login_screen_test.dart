import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge_app/models/dashboard_data.dart';
import 'package:nudge_app/models/user.dart';
import 'package:nudge_app/screens/dashboard_screen.dart';
import 'package:nudge_app/screens/login_screen.dart';
import 'package:nudge_app/services/api_client.dart';

class FakeApiClient extends ApiClient {
  final bool healthy;
  bool getCurrentUserCalled = false;
  String? loggedInLineUserId;

  FakeApiClient({this.healthy = true});

  @override
  Future<bool> checkHealth() async {
    return healthy;
  }

  @override
  Future<User> getCurrentUser() async {
    getCurrentUserCalled = true;
    return User(
      id: 99,
      deviceUuid: 'guest-uuid-1234',
      lineUserId: null,
      createdAt: DateTime.parse('2026-09-22T00:00:00Z'),
    );
  }

  @override
  Future<User> loginWithLine(
    String lineUserId, {
    String? displayName,
    String? pictureUrl,
  }) async {
    loggedInLineUserId = lineUserId;
    return User(
      id: 101,
      deviceUuid: 'dev-device-uuid',
      lineUserId: lineUserId,
      createdAt: DateTime.parse('2026-09-22T00:00:00Z'),
    );
  }

  @override
  Future<DashboardData> getDashboard() async {
    return DashboardData(
      totalActive: 0,
      potentiallyAvoidedCount: 0,
      completedCount: 0,
      next: [],
      later: [],
      recommended: null,
    );
  }
}

void main() {
  group('LoginScreen Widget Tests', () {
    testWidgets('renders Nudge branding, LINE login, Guest mode, and Dev panel',
        (WidgetTester tester) async {
      final fakeApi = FakeApiClient(healthy: true);

      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(apiClient: fakeApi),
        ),
      );

      // Settle initial async initialization
      await tester.pumpAndSettle();

      // Verify Hero Branding
      expect(find.text('Nudge'), findsOneWidget);
      expect(
        find.text('ก้าวข้ามการผัดวันประกันพรุ่งด้วยก้าวเล็กๆ'),
        findsOneWidget,
      );
      expect(find.text('Action Nudge • Deadline Awareness'), findsOneWidget);

      // Verify Primary Action: LINE Login
      expect(find.text('เข้าสู่ระบบด้วย LINE'), findsOneWidget);
      expect(find.byIcon(Icons.chat_bubble_rounded), findsOneWidget);

      // Verify Secondary Action: Guest Mode
      expect(find.text('ใช้งานแบบไม่ผูกบัญชี (Guest Mode)'), findsOneWidget);

      // Verify Dev / Test Mode
      expect(find.text('โหมดนักพัฒนา (Dev / Test Mode)'), findsOneWidget);
    });

    testWidgets('tapping Guest Mode logs in and navigates to DashboardScreen',
        (WidgetTester tester) async {
      final fakeApi = FakeApiClient(healthy: true);

      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(apiClient: fakeApi),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Guest Login
      final guestButton = find.text('ใช้งานแบบไม่ผูกบัญชี (Guest Mode)');
      expect(guestButton, findsOneWidget);
      await tester.tap(guestButton);

      // Settle navigation transition
      await tester.pumpAndSettle();

      expect(fakeApi.getCurrentUserCalled, isTrue);
      expect(find.byType(DashboardScreen), findsOneWidget);
    });

    testWidgets('tapping Dev Mode User 01 logs in with LINE ID and navigates',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final fakeApi = FakeApiClient(healthy: true);

      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(apiClient: fakeApi),
        ),
      );

      await tester.pumpAndSettle();

      // Expand Dev Mode panel
      final devPanel = find.text('โหมดนักพัฒนา (Dev / Test Mode)');
      await tester.ensureVisible(devPanel);
      await tester.tap(devPanel);
      await tester.pumpAndSettle();

      // Tap User 01 quick simulator button
      final user01Button = find.text('User 01');
      await tester.ensureVisible(user01Button);
      expect(user01Button, findsOneWidget);
      await tester.tap(user01Button);

      await tester.pumpAndSettle();

      expect(fakeApi.loggedInLineUserId, 'test_line_user_01');
      expect(find.byType(DashboardScreen), findsOneWidget);
    });

    testWidgets('displays offline error state when backend health check fails',
        (WidgetTester tester) async {
      final fakeApi = FakeApiClient(healthy: false);

      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(apiClient: fakeApi),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('ไม่สามารถเชื่อมต่อ Backend ได้'), findsOneWidget);
      expect(find.text('ลองใหม่อีกครั้ง'), findsOneWidget);
    });
  });
}
