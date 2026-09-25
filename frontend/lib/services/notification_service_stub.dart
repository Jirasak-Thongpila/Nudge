/// Platform notification stub for non-web platforms
class PlatformNotification {
  static Future<bool> requestPermission() async => false;

  static bool hasPermission() => false;

  static void showNotification(
    String title, {
    String? body,
    String? tag,
  }) {}
}
