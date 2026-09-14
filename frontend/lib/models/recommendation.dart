import 'task.dart';

class Recommendation {
  final Task task;
  final String suggestedAction;
  final String recommendationReason;
  final String adaptiveNudgeMessage;

  Recommendation({
    required this.task,
    required this.suggestedAction,
    required this.recommendationReason,
    this.adaptiveNudgeMessage = 'ลองเริ่ม 10 นาทีไหม?',
  });

  factory Recommendation.fromJson(Map<String, dynamic> json) {
    return Recommendation(
      task: Task.fromJson(json['task'] as Map<String, dynamic>),
      suggestedAction: json['suggestedAction'] as String? ?? 'START_10_MINUTES',
      recommendationReason: json['recommendationReason'] as String? ?? '',
      adaptiveNudgeMessage: json['adaptiveNudgeMessage'] as String? ?? 'ลองเริ่ม 10 นาทีไหม?',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'task': task.toJson(),
      'suggestedAction': suggestedAction,
      'recommendationReason': recommendationReason,
      'adaptiveNudgeMessage': adaptiveNudgeMessage,
    };
  }
}
