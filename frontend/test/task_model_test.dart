import 'package:flutter_test/flutter_test.dart';
import 'package:nudge_app/models/task.dart';

void main() {
  group('Task Model Serialization & Avoidance Fields (Ticket 04)', () {
    test('Task.fromJson correctly parses task JSON including avoidance fields', () {
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
        'isPotentiallyAvoided': true,
      };

      final task = Task.fromJson(json);

      expect(task.id, 101);
      expect(task.userId, 5);
      expect(task.title, 'Mini Project Report');
      expect(task.importance, 5);
      expect(task.estimatedMinutes, 120);
      expect(task.status, 'NOT_STARTED');
      expect(task.postponeCount, 2);
      expect(task.daysRemaining, 1);
      expect(task.avoidanceScore, 4);
      expect(task.isPotentiallyAvoided, isTrue);
    });

    test('Task.toJson preserves avoidance fields faithfully', () {
      final task = Task(
        id: 1,
        userId: 2,
        title: 'Complete Homework',
        deadline: DateTime.parse('2026-09-18T18:00:00.000Z'),
        importance: 4,
        estimatedMinutes: 45,
        status: 'IN_PROGRESS',
        postponeCount: 3,
        createdAt: DateTime.parse('2026-09-14T08:00:00.000Z'),
        daysRemaining: 4,
        avoidanceScore: 6,
        isPotentiallyAvoided: true,
      );

      final json = task.toJson();

      expect(json['avoidanceScore'], 6);
      expect(json['isPotentiallyAvoided'], true);
      expect(json['postponeCount'], 3);
    });
  });
}
