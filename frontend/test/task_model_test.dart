import 'package:flutter_test/flutter_test.dart';
import 'package:nudge_app/models/task.dart';

void main() {
  group('Task Model Serialization', () {
    test('Task.fromJson correctly parses task JSON', () {
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
      };

      final task = Task.fromJson(json);

      expect(task.id, 101);
      expect(task.userId, 5);
      expect(task.title, 'Mini Project Report');
      expect(task.importance, 5);
      expect(task.estimatedMinutes, 120);
      expect(task.status, 'NOT_STARTED');
      expect(task.postponeCount, 2);
      expect(task.deadline, DateTime.parse('2026-09-25T23:59:00.000Z'));
      expect(task.deletedAt, isNull);
    });

    test('Task.toJson serializes all fields faithfully', () {
      final task = Task(
        id: 1,
        userId: 2,
        title: 'Complete Homework',
        deadline: DateTime.parse('2026-09-18T18:00:00.000Z'),
        importance: 3,
        estimatedMinutes: 45,
        status: 'IN_PROGRESS',
        postponeCount: 1,
        createdAt: DateTime.parse('2026-09-14T08:00:00.000Z'),
      );

      final json = task.toJson();

      expect(json['id'], 1);
      expect(json['userId'], 2);
      expect(json['title'], 'Complete Homework');
      expect(json['importance'], 3);
      expect(json['estimatedMinutes'], 45);
      expect(json['status'], 'IN_PROGRESS');
      expect(json['postponeCount'], 1);
      expect(json['deadline'], '2026-09-18T18:00:00.000Z');
    });
  });
}
