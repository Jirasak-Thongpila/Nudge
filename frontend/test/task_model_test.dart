import 'package:flutter_test/flutter_test.dart';
import 'package:nudge_app/models/task.dart';
import 'package:nudge_app/models/recommendation.dart';

void main() {
  group('Task Model Serialization & Priority Fields (Ticket 05)', () {
    test('Task.fromJson correctly parses task JSON including priority fields', () {
      final json = {
        'id': 101,
        'userId': 5,
        'title': 'Mini Project Report',
        'deadline': '2026-09-25T23:59:00.000Z',
        'importance': 5,
        'estimatedMinutes': 120,
        'status': 'NOT_STARTED',
        'postponeCount': 2,
        'createdAt': '2026-09-14T10:00:00.000Z',
        'deletedAt': null,
        'daysRemaining': 1,
        'avoidanceScore': 4,
        'urgencyScore': 8,
        'priorityScore': 17,
        'isPotentiallyAvoided': true,
      };

      final task = Task.fromJson(json);

      expect(task.id, 101);
      expect(task.title, 'Mini Project Report');
      expect(task.daysRemaining, 1);
      expect(task.avoidanceScore, 4);
      expect(task.urgencyScore, 8);
      expect(task.priorityScore, 17);
      expect(task.isPotentiallyAvoided, isTrue);
    });

    test('Recommendation.fromJson parses recommendation structure', () {
      final recJson = {
        'task': {
          'id': 102,
          'userId': 5,
          'title': 'Mini Project',
          'deadline': '2026-09-15T23:59:00.000Z',
          'importance': 5,
          'estimatedMinutes': 120,
          'status': 'NOT_STARTED',
          'postponeCount': 3,
          'createdAt': '2026-09-10T10:00:00.000Z',
          'deletedAt': null,
          'daysRemaining': 1,
          'avoidanceScore': 6,
          'urgencyScore': 8,
          'priorityScore': 19,
          'isPotentiallyAvoided': true,
        },
        'suggestedAction': 'START_10_MINUTES',
        'recommendationReason': 'งานสำคัญที่ใกล้กำหนดส่ง ลองเริ่มก้าวแรก 10 นาที',
      };

      final rec = Recommendation.fromJson(recJson);

      expect(rec.task.id, 102);
      expect(rec.suggestedAction, 'START_10_MINUTES');
      expect(rec.task.priorityScore, 19);
      expect(rec.recommendationReason).toContain('10 นาที');
    });
  });
}
