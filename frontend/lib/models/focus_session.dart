class FocusSession {
  final int id;
  final int taskId;
  final DateTime startedAt;
  final int durationMinutes;
  final bool completed;

  FocusSession({
    required this.id,
    required this.taskId,
    required this.startedAt,
    required this.durationMinutes,
    required this.completed,
  });

  factory FocusSession.fromJson(Map<String, dynamic> json) {
    return FocusSession(
      id: json['id'] as int,
      taskId: json['taskId'] as int,
      startedAt: DateTime.parse(json['startedAt'] as String),
      durationMinutes: json['durationMinutes'] as int? ?? 10,
      completed: json['completed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'taskId': taskId,
      'startedAt': startedAt.toIso8601String(),
      'durationMinutes': durationMinutes,
      'completed': completed,
    };
  }
}
