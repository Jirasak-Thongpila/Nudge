class User {
  final int id;
  final String deviceUuid;
  final String? lineUserId;
  final DateTime createdAt;

  User({
    required this.id,
    required this.deviceUuid,
    this.lineUserId,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      deviceUuid: json['deviceUuid'] as String,
      lineUserId: json['lineUserId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deviceUuid': deviceUuid,
      'lineUserId': lineUserId,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
