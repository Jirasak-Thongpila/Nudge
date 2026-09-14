import 'task.dart';
import 'recommendation.dart';

class DashboardData {
  final Recommendation? recommended;
  final List<Task> next;
  final List<Task> later;
  final int totalActive;
  final int completedCount;
  final int potentiallyAvoidedCount;

  DashboardData({
    this.recommended,
    required this.next,
    required this.later,
    required this.totalActive,
    required this.completedCount,
    required this.potentiallyAvoidedCount,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    final recommendedJson = json['recommended'] as Map<String, dynamic>?;
    final nextList = json['next'] as List<dynamic>? ?? [];
    final laterList = json['later'] as List<dynamic>? ?? [];
    final summary = json['summary'] as Map<String, dynamic>? ?? {};

    return DashboardData(
      recommended:
          recommendedJson != null ? Recommendation.fromJson(recommendedJson) : null,
      next: nextList.map((item) => Task.fromJson(item as Map<String, dynamic>)).toList(),
      later: laterList.map((item) => Task.fromJson(item as Map<String, dynamic>)).toList(),
      totalActive: summary['totalActive'] as int? ?? 0,
      completedCount: summary['completedCount'] as int? ?? 0,
      potentiallyAvoidedCount: summary['potentiallyAvoidedCount'] as int? ?? 0,
    );
  }
}
