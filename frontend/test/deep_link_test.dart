import 'package:flutter_test/flutter_test.dart';
import 'package:nudge_app/services/deep_link_service.dart';

void main() {
  group('DeepLinkService (Ticket 09)', () {
    test('parseFocusTaskId extracts task ID from standard deep link', () {
      final uri = 'nudge://focus?taskId=42';
      final taskId = DeepLinkService.parseFocusTaskId(uri);
      expect(taskId, 42);
    });

    test('parseFocusTaskId handles path segment format nudge://app/focus?taskId=99', () {
      final uri = 'nudge://app/focus?taskId=99';
      final taskId = DeepLinkService.parseFocusTaskId(uri);
      expect(taskId, 99);
    });

    test('parseFocusTaskId returns null for non-nudge schemes', () {
      expect(DeepLinkService.parseFocusTaskId('https://focus?taskId=42'), isNull);
      expect(DeepLinkService.parseFocusTaskId('custom://focus?taskId=42'), isNull);
    });

    test('parseFocusTaskId returns null for non-focus hosts', () {
      expect(DeepLinkService.parseFocusTaskId('nudge://settings?taskId=42'), isNull);
      expect(DeepLinkService.parseFocusTaskId('nudge://dashboard'), isNull);
    });

    test('parseFocusTaskId returns null for missing or non-integer taskId', () {
      expect(DeepLinkService.parseFocusTaskId('nudge://focus'), isNull);
      expect(DeepLinkService.parseFocusTaskId('nudge://focus?taskId='), isNull);
      expect(DeepLinkService.parseFocusTaskId('nudge://focus?taskId=abc'), isNull);
    });

    test('buildFocusDeepLink generates correct URI', () {
      final link = DeepLinkService.buildFocusDeepLink(123);
      expect(link, 'nudge://focus?taskId=123');
    });
  });
}
