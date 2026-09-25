import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge_app/screens/add_task_screen.dart';
import 'package:nudge_app/services/api_client.dart';

class MockQuickAddApiClient extends ApiClient {
  String? quickAddTextCalled;
  bool? quickAddConfirmedCalled;

  @override
  Future<Map<String, dynamic>> quickAddTask({
    required String text,
    bool confirmed = false,
  }) async {
    quickAddTextCalled = text;
    quickAddConfirmedCalled = confirmed;

    return {
      'success': true,
      'duplicate': false,
      'data': {
        'id': 100,
        'title': text,
        'importance': 4,
        'estimatedMinutes': 45,
        'status': 'NOT_STARTED',
        'deadline': DateTime.now().add(const Duration(days: 1)).toIso8601String(),
      },
      'parsed': {
        'title': text,
        'deadline': DateTime.now().add(const Duration(days: 1)).toIso8601String(),
        'importance': 4,
        'estimatedMinutes': 45,
      },
    };
  }
}

void main() {
  testWidgets('AddTaskScreen renders smart AI box, mic button, prompt chips, and expandable manual form',
      (WidgetTester tester) async {
    final mockApi = MockQuickAddApiClient();

    await tester.pumpWidget(
      MaterialApp(
        home: AddTaskScreen(apiClient: mockApi),
      ),
    );

    expect(find.text('บันทึกด่วนด้วย AI (แบบ LINE)'), findsOneWidget);
    expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);

    // Verify sample prompt chips exist
    expect(find.text('พรุ่งนี้ 9 โมงส่งรายงาน 4 ดาว'), findsOneWidget);

    // Verify accordion exists
    expect(find.text('หรือกรอกแบบฟอร์มละเอียด (Manual Input)'), findsOneWidget);

    // Tap a sample chip
    await tester.tap(find.text('พรุ่งนี้ 9 โมงส่งรายงาน 4 ดาว'));
    await tester.pumpAndSettle();

    // Verify quickAddTask was called
    expect(mockApi.quickAddTextCalled, 'พรุ่งนี้ 9 โมงส่งรายงาน 4 ดาว');
    expect(mockApi.quickAddConfirmedCalled, isFalse);
  });
}
