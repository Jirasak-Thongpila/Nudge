import 'package:flutter_test/flutter_test.dart';
import 'package:nudge_app/models/focus_session.dart';

void main() {
  group('FocusSession Model Serialization', () {
    test('FocusSession.fromJson correctly parses data', () {
      final json = {
        'id': 101,
        'taskId': 5,
        'startedAt': '2026-09-14T14:00:00.000Z',
        'durationMinutes': 10,
        'completed': true,
      };

      final session = FocusSession.fromJson(json);

      expect(session.id, 101);
      expect(session.taskId, 5);
      expect(session.startedAt, DateTime.parse('2026-09-14T14:00:00.000Z'));
      expect(session.durationMinutes, 10);
      expect(session.completed, true);
    });

    test('FocusSession.toJson preserves all fields', () {
      final session = FocusSession(
        id: 102,
        taskId: 5,
        startedAt: DateTime.parse('2026-09-14T14:15:00.000Z'),
        durationMinutes: 4,
        completed: false,
      );

      final json = session.toJson();

      expect(json['id'], 102);
      expect(json['taskId'], 5);
      expect(json['startedAt'], '2026-09-14T14:15:00.000Z');
      expect(json['durationMinutes'], 4);
      expect(json['completed'], false);
    });
  });
}
