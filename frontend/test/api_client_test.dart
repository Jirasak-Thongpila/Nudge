import 'package:flutter_test/flutter_test.dart';
import 'package:nudge_app/models/user.dart';

void main() {
  group('User Model Serialization', () {
    test('User.fromJson correctly parses user map', () {
      final json = {
        'id': 42,
        'deviceUuid': 'test-uuid-value',
        'lineUserId': null,
        'createdAt': '2026-09-14T13:00:00.000Z',
      };

      final user = User.fromJson(json);

      expect(user.id, 42);
      expect(user.deviceUuid, 'test-uuid-value');
      expect(user.lineUserId, isNull);
      expect(user.createdAt, DateTime.parse('2026-09-14T13:00:00.000Z'));
    });

    test('User.toJson preserves all fields', () {
      final user = User(
        id: 1,
        deviceUuid: 'device-abc',
        lineUserId: 'line-xyz',
        createdAt: DateTime.parse('2026-09-14T12:00:00.000Z'),
      );

      final json = user.toJson();

      expect(json['id'], 1);
      expect(json['deviceUuid'], 'device-abc');
      expect(json['lineUserId'], 'line-xyz');
      expect(json['createdAt'], '2026-09-14T12:00:00.000Z');
    });
  });
}
