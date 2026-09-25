// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

/// Platform notification service using Web Notification API
class PlatformNotification {
  static Future<bool> requestPermission() async {
    try {
      if (html.Notification.permission == 'granted') return true;
      final perm = await html.Notification.requestPermission();
      return perm == 'granted';
    } catch (_) {
      return false;
    }
  }

  static bool hasPermission() {
    try {
      return html.Notification.permission == 'granted';
    } catch (_) {
      return false;
    }
  }

  static void showNotification(
    String title, {
    String? body,
    String? tag,
  }) {
    try {
      if (html.Notification.permission == 'granted') {
        html.Notification(
          title,
          body: body,
          tag: tag,
          icon: '/favicon.png',
        );
      }
    } catch (_) {}
  }
}
