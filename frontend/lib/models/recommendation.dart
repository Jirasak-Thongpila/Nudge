import 'task.dart';

class Recommendation {
  final Task task;
  final String suggestedAction;
  final String recommendationReason;

  Recommendation({
    required this.task,
    required this.suggestedAction,
    required this.recommendationReason,
  });

  factory Recommendation.fromJson(Map<String, dynamic> json) {
    return Recommendation(
      task: Task.fromJson(json['task'] as Map<String, dynamic>),
      suggestedAction: json['suggestedAction'] as String? ?? 'START_10_MINUTES',
      recommendationReason: json['recommendationReason'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'task': task.toJson(),
      'suggestedAction': suggestedAction,
      'recommendationReason': recommendationReason,
    };
  }
}
