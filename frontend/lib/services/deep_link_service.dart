import 'package:flutter/material.dart';
import '../models/task.dart';
import '../screens/focus_timer_screen.dart';
import 'api_client.dart';

/// Service responsible for parsing and routing mobile deep links (Ticket 09)
/// e.g. nudge://focus?taskId=123
class DeepLinkService {
  /// Parses a deep link URI string and extracts the taskId for focus sessions.
  /// Returns null if the URI format or taskId is invalid.
  static int? parseFocusTaskId(String uriString) {
    try {
      final uri = Uri.parse(uriString.trim());

      // Accept nudge://focus?taskId=... or nudge://app/focus?taskId=...
      final isNudgeScheme = uri.scheme.toLowerCase() == 'nudge';
      if (!isNudgeScheme) return null;

      final isFocusTarget = uri.host.toLowerCase() == 'focus' ||
          uri.pathSegments.any((seg) => seg.toLowerCase() == 'focus');

      if (!isFocusTarget) return null;

      final taskIdParam = uri.queryParameters['taskId'];
      if (taskIdParam == null) return null;

      final taskId = int.tryParse(taskIdParam);
      return taskId;
    } catch (_) {
      return null;
    }
  }

  /// Builds a standard deep link string for launching a Focus Session on a task.
  static String buildFocusDeepLink(int taskId) {
    return 'nudge://focus?taskId=$taskId';
  }

  /// Resolves the deep link, fetches the corresponding task, and navigates directly to FocusTimerScreen.
  static Future<bool> navigateFromDeepLink({
    required BuildContext context,
    required ApiClient apiClient,
    required String uriString,
  }) async {
    final taskId = parseFocusTaskId(uriString);
    if (taskId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('รูปแบบ Deep Link ไม่ถูกต้อง (ตัวอย่าง: nudge://focus?taskId=1)'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }

    try {
      final task = await apiClient.getTask(taskId);
      if (!context.mounted) return false;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => FocusTimerScreen(
            task: task,
            apiClient: apiClient,
          ),
        ),
      );
      return true;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ไม่สามารถเปิด Focus Session สำหรับ Task #$taskId ได้: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }
}
