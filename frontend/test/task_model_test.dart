import 'package:flutter_test/flutter_test.dart';
import 'package:nudge_app/models/task.dart';

void main() {
  group('Task Model Serialization & Derived Fields (Ticket 03)', () {
    test('Task.fromJson correctly parses task JSON including daysRemaining', () {
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
        'daysRemaining': 3,
      };

      final task = Task.fromJson(json);

      expect(task.id, 101);
      expect(task.userId, 5);
      expect(task.title, 'Mini Project Report');
      expect(task.importance, 5);
      expect(task.estimatedMinutes, 120);
      expect(task.status, 'NOT_STARTED');
      expect(task.postponeCount, 2);
      expect(task.daysRemaining, 3);
      expect(task.isOverdue, isFalse);
      expect(task.isDueToday, isFalse);
      expect(task.isCompleted, isFalse);
      expect(task.isNotStarted, isTrue);
    });

    test('Status and urgency helper getters work accurately', () {
      final overdueTask = Task(
        id: 1,
        userId: 2,
        title: 'Past Task',
        deadline: DateTime.now().subtract(const Duration(days: 2)),
        importance: 4,
        estimatedMinutes: 30,
        status: 'COMPLETED',
        postponeCount: 1,
        createdAt: DateTime.now(),
        daysRemaining: -2,
      );

      expect(overdueTask.isOverdue, isTrue);
      expect(overdueTask.isDueToday, isFalse);
      expect(overdueTask.isCompleted, isTrue);

      final todayTask = Task(
        id: 2,
        userId: 2,
        title: 'Today Task',
        deadline: DateTime.now(),
        importance: 3,
        estimatedMinutes: 15,
        status: 'IN_PROGRESS',
        postponeCount: 0,
        createdAt: DateTime.now(),
        daysRemaining: 0,
      );

      expect(todayTask.isOverdue, isFalse);
      expect(todayTask.isDueToday, isTrue);
      expect(todayTask.isInProgress, isTrue);
    });
  });
}
