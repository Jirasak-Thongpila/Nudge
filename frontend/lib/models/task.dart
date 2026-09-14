class Task {
  final int id;
  final int userId;
  final String title;
  final DateTime deadline;
  final int importance;
  final int estimatedMinutes;
  final String status;
  final int postponeCount;
  final DateTime createdAt;
  final DateTime? deletedAt;
  final int daysRemaining;

  Task({
    required this.id,
    required this.userId,
    required this.title,
    required this.deadline,
    required this.importance,
    required this.estimatedMinutes,
    required this.status,
    required this.postponeCount,
    required this.createdAt,
    this.deletedAt,
    required this.daysRemaining,
  });

  bool get isOverdue => daysRemaining < 0;
  bool get isDueToday => daysRemaining == 0;
  bool get isCompleted => status == 'COMPLETED';
  bool get isInProgress => status == 'IN_PROGRESS';
  bool get isNotStarted => status == 'NOT_STARTED';

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as int,
      userId: json['userId'] as int,
      title: json['title'] as String,
      deadline: DateTime.parse(json['deadline'] as String),
      importance: json['importance'] as int,
      estimatedMinutes: json['estimatedMinutes'] as int,
      status: json['status'] as String,
      postponeCount: json['postponeCount'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      deletedAt: json['deletedAt'] != null
          ? DateTime.parse(json['deletedAt'] as String)
          : null,
      daysRemaining: json['daysRemaining'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'deadline': deadline.toIso8601String(),
      'importance': importance,
      'estimatedMinutes': estimatedMinutes,
      'status': status,
      'postponeCount': postponeCount,
      'createdAt': createdAt.toIso8601String(),
      'deletedAt': deletedAt?.toIso8601String(),
      'daysRemaining': daysRemaining,
    };
  }
}
