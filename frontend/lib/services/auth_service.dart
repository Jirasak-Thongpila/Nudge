import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class AuthService {
  static const String _deviceUuidKey = 'nudge_device_uuid';
  final Uuid _uuid = const Uuid();

  /// Retrieves the persistent device UUID or generates and persists a new one (ADR-0001)
  Future<String> getOrCreateDeviceUuid() async {
    final prefs = await SharedPreferences.getInstance();
    String? storedUuid = prefs.getString(_deviceUuidKey);

    if (storedUuid == null || storedUuid.trim().isEmpty) {
      storedUuid = _uuid.v4();
      await prefs.setString(_deviceUuidKey, storedUuid);
    }

    return storedUuid;
  }

  /// Clears stored device UUID (used for testing or resetting identity)
  Future<void> clearDeviceUuid() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_deviceUuidKey);
  }
}
